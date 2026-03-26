#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN="${DRY_RUN:-0}"
SSH_COMMON_ARGS="${SSH_COMMON_ARGS:-}"

load_env_file() {
  local env_path="$1"
  local line key value

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"

    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    if [[ "$line" != *=* ]]; then
      continue
    fi

    key="${line%%=*}"
    value="${line#*=}"

    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"

    if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    fi

    printf -v "$key" '%s' "$value"
    export "$key"
  done < "$env_path"
}

require_var() {
  local var_name="$1"
  if [[ -z "${!var_name:-}" ]]; then
    echo "Required variable is missing: $var_name" >&2
    exit 1
  fi
}

run_cmd() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY RUN] $*"
    return 0
  fi
  "$@"
}

run_local_shell() {
  local command="$1"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY RUN][local] $command"
    return 0
  fi
  bash -lc "$command"
}

run_remote_shell() {
  local ssh_target="$1"
  local command="$2"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY RUN][remote:$ssh_target] $command"
    return 0
  fi
  ssh $SSH_COMMON_ARGS "$ssh_target" "bash -lc $(printf '%q' "$command")"
}

remote_path_expr() {
  local remote_path="$1"
  if [[ "$remote_path" == "~/"* ]]; then
    printf '\$HOME/%s' "${remote_path#"~/"}"
    return 0
  fi
  printf '%q' "$remote_path"
}

sync_repo_to_remote() {
  local ssh_target="$1"
  local remote_root="$2"
  local remote_root_expr
  remote_root_expr="$(remote_path_expr "$remote_root")"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY RUN][sync:$ssh_target] $ROOT_DIR -> $remote_root"
    return 0
  fi

  tar -C "$ROOT_DIR" --exclude=".git" -cf - . | ssh $SSH_COMMON_ARGS "$ssh_target" \
    "bash -lc $(printf '%q' "mkdir -p $remote_root_expr && tar -xf - -C $remote_root_expr")"
}

deploy_core_detached() {
  local env_file="$1"
  local command="
    cd $(printf '%q' "$ROOT_DIR") && \
    docker rm -f measurement_plane_gui experiment-orchestrator coincidences_analyzer_agent_container polarization_analyzer_container apc_service_container nats >/dev/null 2>&1 || true && \
    docker network prune -f >/dev/null 2>&1 || true && \
    docker compose --env-file $(printf '%q' "$env_file") pull && \
    docker compose --env-file $(printf '%q' "$env_file") up -d --force-recreate
  "
  run_local_shell "$command"
}

stop_core_detached() {
  local env_file="$1"
  local command="
    cd $(printf '%q' "$ROOT_DIR") && \
    docker compose --env-file $(printf '%q' "$env_file") down --remove-orphans && \
    docker rm -f measurement_plane_gui experiment-orchestrator coincidences_analyzer_agent_container polarization_analyzer_container apc_service_container nats >/dev/null 2>&1 || true
  "
  run_local_shell "$command"
}

deploy_remote_agent() {
  local ssh_target="$1"
  local remote_root="$2"
  local env_file="$3"
  local script_name="$4"
  local remote_root_expr
  remote_root_expr="$(remote_path_expr "$remote_root")"

  sync_repo_to_remote "$ssh_target" "$remote_root"
  run_remote_shell "$ssh_target" "cd $remote_root_expr && ENV_FILE=$(printf '%q' "$env_file") ./scripts/$script_name"
}

stop_remote_agent() {
  local ssh_target="$1"
  local remote_root="$2"
  local env_file="$3"
  local script_name="$4"
  local remote_root_expr
  remote_root_expr="$(remote_path_expr "$remote_root")"

  run_remote_shell "$ssh_target" "cd $remote_root_expr && ENV_FILE=$(printf '%q' "$env_file") ./scripts/$script_name"
}
