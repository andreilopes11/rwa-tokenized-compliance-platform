#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"

usage() {
    cat <<'EOF'
Usage: root/scripts/stack.sh <command> [options] [projects...]

Orchestrates blockchain + backend + frontend as one local stack.
Windows: prefer .\root\scripts\stack.ps1 (invokes Git Bash).

Commands:
  up      [projects...]   Recommended: cache/deps + start all three services
  start   [projects...]   Start services (default: all)
  stop    [projects...]   Stop services (default: all)
  deps                    Install/check dependencies (+ forge build)
  cache                   Update forge/npm/Maven caches (no service start)
  sync                    Sync local env files from deployment addresses
  clean                   Remove temporary build artifacts
  verify                  Run all project tests (alias: test)
  check                   Verify required tooling (node, java, forge, …)
  status                  Show running state of stack services
  -h, --help              Show this help message

Projects (for up/start/stop):
  all         All services (default)
  blockchain  Anvil + contract deploy
  backend     Spring Boot API
  frontend    Next.js app

Start / up / sync options:
  --chain sepolia|anvil  Chain target (default anvil). sepolia = live Sepolia, no Anvil
  --no-stop              Skip stop step before starting
  --skip-deps            Skip dependency install/compile (faster restart)
  --update               Force npm reinstall + Maven -U (up/deps/cache)

Deps options:
  --update / --force   Force refresh even if node_modules exists
  --skip-check         Skip tooling version check

Clean options:
  --deps --runtime --deployments --full --dry-run
  --backend --blockchain --frontend

Examples:
  bash root/scripts/stack.sh up
  bash root/scripts/stack.sh up --update
  bash root/scripts/stack.sh sync --chain sepolia
  bash root/scripts/stack.sh up --chain sepolia --skip-deps
  bash root/scripts/stack.sh deps --update
  bash root/scripts/stack.sh cache
  bash root/scripts/stack.sh start --skip-deps
  bash root/scripts/stack.sh stop
  bash root/scripts/stack.sh status
EOF
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

command="$1"
shift

case "$command" in
    up|run)
        stack_up "$@"
        ;;
    start)
        stack_start "$@"
        ;;
    stop|down)
        if [ $# -eq 0 ]; then
            stack_stop all
        elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
            cat <<'EOF'
Usage: root/scripts/stack.sh stop [projects...]

Stops blockchain, backend, and/or frontend.

Projects: all (default), blockchain, backend, frontend
EOF
        else
            stack_stop "$@"
        fi
        ;;
    deps)
        skip_check=false
        force=false
        while [ $# -gt 0 ]; do
            case "$1" in
                --skip-check)
                    skip_check=true
                    ;;
                --update|--force)
                    force=true
                    ;;
                -h|--help)
                    cat <<'EOF'
Usage: root/scripts/stack.sh deps [options]

Install/check project dependencies:
  - npm ci/install (blockchain + frontend)
  - forge build (warm Foundry cache)
  - mvn compile (resolve Maven deps)

Options:
  --update / --force  Reinstall npm deps + Maven -U
  --skip-check        Skip tooling version check
  -h, --help          Show this help message
EOF
                    exit 0
                    ;;
                *)
                    fail "unknown option: $1"
                    ;;
            esac
            shift
        done
        stack_install_deps "$skip_check" "$force"
        ;;
    cache|update-cache)
        force=false
        while [ $# -gt 0 ]; do
            case "$1" in
                --update|--force)
                    force=true
                    ;;
                -h|--help)
                    cat <<'EOF'
Usage: root/scripts/stack.sh cache [--update]

Warm/refresh local caches without starting services:
  forge build, npm packages, Maven dependency:resolve + compile
EOF
                    exit 0
                    ;;
                *)
                    fail "unknown option: $1"
                    ;;
            esac
            shift
        done
        stack_update_cache "$force"
        ;;
    sync)
        while [ $# -gt 0 ]; do
            case "$1" in
                --chain)
                    shift
                    [ $# -gt 0 ] || fail "--chain requires sepolia|anvil"
                    apply_stack_chain_arg "$1"
                    ;;
                --chain=*)
                    apply_stack_chain_arg "${1#--chain=}"
                    ;;
                -h|--help)
                    cat <<'EOF'
Usage: root/scripts/stack.sh sync [--chain sepolia|anvil]

Sync local env files (.local-runtime/stack.env, frontend contracts + .env.local)
from Anvil deployment or committed Sepolia addresses.
EOF
                    exit 0
                    ;;
                *)
                    fail "unknown option: $1"
                    ;;
            esac
            shift
        done
        stack_sync_env
        ;;
    clean)
        include_deps=false
        include_runtime=false
        include_deployments=false
        dry_run=false
        clean_backend=false
        clean_blockchain=false
        clean_frontend=false
        project_filter=false

        while [ $# -gt 0 ]; do
            case "$1" in
                --deps)
                    include_deps=true
                    ;;
                --runtime)
                    include_runtime=true
                    ;;
                --deployments)
                    include_deployments=true
                    ;;
                --full)
                    include_deps=true
                    include_runtime=true
                    include_deployments=true
                    ;;
                --dry-run)
                    dry_run=true
                    ;;
                --backend)
                    project_filter=true
                    clean_backend=true
                    ;;
                --blockchain)
                    project_filter=true
                    clean_blockchain=true
                    ;;
                --frontend)
                    project_filter=true
                    clean_frontend=true
                    ;;
                -h|--help)
                    usage
                    exit 0
                    ;;
                *)
                    fail "unknown option: $1"
                    ;;
            esac
            shift
        done

        if [ "$project_filter" = false ]; then
            clean_backend=true
            clean_blockchain=true
            clean_frontend=true
        fi

        resolve_workspace_paths
        clean_build_artifacts \
            "$include_deps" \
            "$include_runtime" \
            "$include_deployments" \
            "$dry_run" \
            "$clean_backend" \
            "$clean_blockchain" \
            "$clean_frontend"
        if [ "$dry_run" = true ]; then
            log "dry-run complete (no files removed)"
        else
            log "cleanup complete"
        fi
        ;;
    verify|test)
        stack_verify
        ;;
    check)
        while [ $# -gt 0 ]; do
            case "$1" in
                --chain)
                    shift
                    [ $# -gt 0 ] || fail "--chain requires sepolia|anvil"
                    apply_stack_chain_arg "$1"
                    ;;
                --chain=*)
                    apply_stack_chain_arg "${1#--chain=}"
                    ;;
                -h|--help)
                    cat <<'EOF'
Usage: root/scripts/stack.sh check [--chain sepolia|anvil]

Verify required tooling. With --chain sepolia, Foundry/Anvil is optional.
EOF
                    exit 0
                    ;;
                *)
                    fail "unknown option: $1"
                    ;;
            esac
            shift
        done
        stack_check_tooling
        ;;
    status)
        print_stack_status
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        fail "unknown command: $command"
        ;;
esac
