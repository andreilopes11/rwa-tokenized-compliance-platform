#!/usr/bin/env bash
# Smoke-check local FE+BE wired to live Sepolia (no Anvil).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"

START_STACK=false
SKIP_HTTP=false
while [ $# -gt 0 ]; do
    case "$1" in
        --start) START_STACK=true ;;
        --skip-http) SKIP_HTTP=true ;;
        -h|--help)
            cat <<'EOF'
Usage: root/scripts/smoke-sepolia-local.sh [--start] [--skip-http]
EOF
            exit 0
            ;;
        *) fail "unknown option: $1" ;;
    esac
    shift
done

apply_stack_chain_arg sepolia
stack_sync_env

assert_eq() {
    local got="$1" want="$2" msg="$3"
    if [ "$got" != "$want" ]; then
        fail "$msg (got='$got' want='$want')"
    fi
    log "OK: $msg"
}

[ -f "$STACK_ENV_FILE" ] || fail "missing $STACK_ENV_FILE"
[ -f "$FRONTEND_DIR/.env.local" ] || fail "missing frontend .env.local"
[ -f "$FRONTEND_CONTRACTS_FILE" ] || fail "missing contracts.generated.ts"

# shellcheck disable=SC1090
set -a; . "$STACK_ENV_FILE"; set +a

ADDR_FILE="${SEPOLIA_ADDRESSES_FILE:-$BLOCKCHAIN_DIR/config/sepolia-addresses.json}"
eval "$(
    MSYS2_ARG_CONV_EXCL='*' node - "$(to_node_fs_path "$ADDR_FILE")" <<'NODE'
const fs = require("fs");
const d = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
process.stdout.write(`WANT_IR=${JSON.stringify(d.identityRegistry)}\n`);
process.stdout.write(`WANT_TOKEN=${JSON.stringify(d.token)}\n`);
process.stdout.write(`WANT_MC=${JSON.stringify(d.modularCompliance)}\n`);
NODE
)"

assert_eq "${STACK_CHAIN_TARGET:-}" "sepolia" "STACK_CHAIN_TARGET=sepolia"
assert_eq "${LOCAL_CHAIN_ID:-}" "11155111" "chain id"
assert_eq "${BLOCKCHAIN_MODE:-}" "trex" "blockchain mode"
case "${SPRING_PROFILES_ACTIVE:-}" in
    *sepolia*) log "OK: Spring profile includes sepolia" ;;
    *) fail "SPRING_PROFILES_ACTIVE missing sepolia" ;;
esac
assert_eq "${IDENTITY_REGISTRY_ADDRESS:-}" "$WANT_IR" "IR address"
assert_eq "${TOKEN_ADDRESS:-}" "$WANT_TOKEN" "token address"
assert_eq "${MODULAR_COMPLIANCE_ADDRESS:-}" "$WANT_MC" "MC address"

case "${RPC_URL:-}" in
    *127.0.0.1*|*localhost*) fail "RPC must not be localhost" ;;
    *) log "OK: RPC is remote" ;;
esac

if [ "$START_STACK" = true ]; then
    stack_up --chain sepolia --skip-deps backend frontend
fi

if [ "$SKIP_HTTP" = false ]; then
    if curl -fsS --max-time 5 "${BACKEND_API_BASE_URL}/actuator/health" >/dev/null 2>&1; then
        log "OK: backend health"
    else
        log "SKIP: backend not reachable (use --start or stack up --chain sepolia)"
    fi
    if curl -fsS --max-time 5 "${LOCAL_FRONTEND_URL}" >/dev/null 2>&1; then
        log "OK: frontend reachable"
    else
        log "SKIP: frontend not reachable"
    fi
fi

log "Sepolia local wiring OK"
