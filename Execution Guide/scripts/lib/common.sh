#!/usr/bin/env bash

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ROOT_SCRIPTS_DIR="$WORKSPACE_DIR/root/scripts"
BACKEND_DIR="$WORKSPACE_DIR/rwa-tokenized-compliance-system-backend"
BLOCKCHAIN_DIR="$WORKSPACE_DIR/rwa-tokenized-compliance-system-blockchain"
FRONTEND_DIR="$WORKSPACE_DIR/rwa-tokenized-compliance-system-frontend"
RUNTIME_DIR="$WORKSPACE_DIR/.local-runtime"

STACK_CONFIG_FILE="$ROOT_SCRIPTS_DIR/stack-config.sh"
STACK_ENV_FILE="$RUNTIME_DIR/stack.env"
FRONTEND_CONTRACTS_FILE="$FRONTEND_DIR/src/shared/config/contracts.generated.ts"

BACKEND_LOG_FILE="$RUNTIME_DIR/backend.log"
FRONTEND_LOG_FILE="$RUNTIME_DIR/frontend.log"
BACKEND_PID_FILE="$RUNTIME_DIR/backend.pid"
FRONTEND_PID_FILE="$RUNTIME_DIR/frontend.pid"

DEFAULT_LOCAL_RPC_URL="http://127.0.0.1:8545"
DEFAULT_LOCAL_CHAIN_ID="11155111"
DEFAULT_LOCAL_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
DEFAULT_LOCAL_BACKEND_PORT="8080"
DEFAULT_LOCAL_FRONTEND_PORT="3000"
ZERO_ADDRESS="0x0000000000000000000000000000000000000000"

log() {
    # Prefer stderr so Windows PowerShell reliably surfaces Git Bash output.
    printf '[stack] %s\n' "$*" >&2
}

warn() {
    printf '[stack] WARN: %s\n' "$*" >&2
}

fail() {
    printf '[stack] ERROR: %s\n' "$*" >&2
    exit 1
}

# Git Bash /d/foo paths break Win32 Node (becomes D:\d\foo). Convert before node argv.
to_node_fs_path() {
    local path="$1"
    case "$(uname -s 2>/dev/null || true)" in
        MINGW*|MSYS*|CYGWIN*)
            if command -v cygpath >/dev/null 2>&1; then
                cygpath -m "$path"
                return 0
            fi
            if [[ "$path" =~ ^/([a-zA-Z])/(.*)$ ]]; then
                local drive="${BASH_REMATCH[1]}"
                local rest="${BASH_REMATCH[2]}"
                printf '%s:/%s\n' "$(printf '%s' "$drive" | tr '[:lower:]' '[:upper:]')" "$rest"
                return 0
            fi
            ;;
    esac
    printf '%s\n' "$path"
}

ensure_foundry_path() {
    # Git Bash / WSL / native: Foundry may live under different HOME roots on Windows.
    local candidate
    for candidate in \
        "$HOME/.foundry/bin" \
        "${USERPROFILE:-}/.foundry/bin" \
        "/c/Users/${USERNAME:-${USER:-}}/.foundry/bin" \
        "/mnt/c/Users/${USERNAME:-${USER:-}}/.foundry/bin"
    do
        if [ -n "$candidate" ] && [ -d "$candidate" ]; then
            case ":$PATH:" in
                *":$candidate:"*) ;;
                *) export PATH="$candidate:$PATH" ;;
            esac
        fi
    done
}

# Prefer a real JDK over broken Windows "javapath" stubs (exit 127).
ensure_java_path() {
    if [ -n "${JAVA_HOME:-}" ] && { [ -x "$JAVA_HOME/bin/java" ] || [ -x "$JAVA_HOME/bin/java.exe" ]; }; then
        export PATH="$JAVA_HOME/bin:$PATH"
        normalize_java_home
        return 0
    fi

    local candidate
    for candidate in \
        "$HOME/.jdks/corretto-25.0.3/bin" \
        "/c/Users/${USERNAME:-${USER:-}}/.jdks/corretto-25.0.3/bin" \
        "${USERPROFILE:-}/.jdks/corretto-25.0.3/bin"
    do
        if [ -n "$candidate" ] && { [ -x "$candidate/java" ] || [ -x "$candidate/java.exe" ]; }; then
            export PATH="$candidate:$PATH"
            export JAVA_HOME="$(cd "$candidate/.." && pwd)"
            normalize_java_home
            return 0
        fi
    done

    # Newest JDK under ~/.jdks
    local jdk_bin
    jdk_bin="$(ls -1d "$HOME"/.jdks/*/bin 2>/dev/null | sort -V | tail -n 1 || true)"
    if [ -z "$jdk_bin" ] && [ -n "${USERPROFILE:-}" ]; then
        jdk_bin="$(ls -1d "${USERPROFILE}/.jdks"/*/bin 2>/dev/null | sort -V | tail -n 1 || true)"
    fi
    if [ -n "$jdk_bin" ] && { [ -x "$jdk_bin/java" ] || [ -x "$jdk_bin/java.exe" ]; }; then
        export PATH="$jdk_bin:$PATH"
        export JAVA_HOME="$(cd "$jdk_bin/.." && pwd)"
        normalize_java_home
    fi
}

normalize_java_home() {
    [ -n "${JAVA_HOME:-}" ] || return 0
    # Convert Windows path (C:\...) to Git Bash form (/c/...) so Maven scripts work.
    case "$JAVA_HOME" in
        [A-Za-z]:\\*|[A-Za-z]:/*)
            local drive rest
            drive="$(printf '%s' "$JAVA_HOME" | cut -c1 | tr '[:upper:]' '[:lower:]')"
            rest="$(printf '%s' "$JAVA_HOME" | cut -c3- | tr '\\' '/')"
            export JAVA_HOME="/$drive$rest"
            ;;
    esac
}

# On Git Bash/MSYS, the Unix mvn wrapper often breaks; prefer mvn.cmd.
resolve_mvn_cmd() {
    if [ -n "${MVN_CMD:-}" ]; then
        printf '%s\n' "$MVN_CMD"
        return 0
    fi
    case "$(uname -s 2>/dev/null || true)" in
        MINGW*|MSYS*|CYGWIN*)
            if command -v mvn.cmd >/dev/null 2>&1; then
                export MVN_CMD="mvn.cmd"
            elif [ -f "/c/Program Files/Maven/apache-maven-3.9.9/bin/mvn.cmd" ]; then
                export MVN_CMD="/c/Program Files/Maven/apache-maven-3.9.9/bin/mvn.cmd"
            else
                export MVN_CMD="mvn"
            fi
            ;;
        *)
            export MVN_CMD="mvn"
            ;;
    esac
    printf '%s\n' "$MVN_CMD"
}

run_mvn() {
    local cmd
    cmd="$(resolve_mvn_cmd)"
    "$cmd" "$@"
}

resolve_workspace_paths() {
    [ -d "$BACKEND_DIR" ] || fail "backend workspace not found: $BACKEND_DIR"
    [ -d "$BLOCKCHAIN_DIR" ] || fail "blockchain workspace not found: $BLOCKCHAIN_DIR"
    [ -d "$FRONTEND_DIR" ] || fail "frontend workspace not found: $FRONTEND_DIR"
}

ensure_runtime_dir() {
    mkdir -p "$RUNTIME_DIR"
}

load_stack_config() {
    [ -f "$STACK_CONFIG_FILE" ] || fail "missing stack config: $STACK_CONFIG_FILE"
    # shellcheck disable=SC1090
    . "$STACK_CONFIG_FILE"
}

sanitize_env_file() {
    local source_file="$1"
    local sanitized_file
    sanitized_file="$(mktemp)"
    sed 's/\r$//' "$source_file" > "$sanitized_file"
    printf '%s\n' "$sanitized_file"
}

load_env_file() {
    local source_file="$1"
    [ -f "$source_file" ] || return 0

    local sanitized_file
    sanitized_file="$(sanitize_env_file "$source_file")"
    set -a
    # shellcheck disable=SC1090
    . "$sanitized_file"
    set +a
    rm -f "$sanitized_file"
}

resolve_local_config() {
    export STACK_CHAIN_TARGET="${STACK_CHAIN_TARGET:-anvil}"
    export LOCAL_RPC_URL="${LOCAL_RPC_URL:-$DEFAULT_LOCAL_RPC_URL}"
    export LOCAL_CHAIN_ID="${LOCAL_CHAIN_ID:-$DEFAULT_LOCAL_CHAIN_ID}"
    export LOCAL_PRIVATE_KEY="${LOCAL_PRIVATE_KEY:-$DEFAULT_LOCAL_PRIVATE_KEY}"
    export LOCAL_BACKEND_PORT="${LOCAL_BACKEND_PORT:-$DEFAULT_LOCAL_BACKEND_PORT}"
    export LOCAL_FRONTEND_PORT="${LOCAL_FRONTEND_PORT:-$DEFAULT_LOCAL_FRONTEND_PORT}"
    export SERVER_PORT="${SERVER_PORT:-$LOCAL_BACKEND_PORT}"
    export SPRING_PROFILES_ACTIVE="${SPRING_PROFILES_ACTIVE:-local}"
    export BLOCKCHAIN_ENABLED="${BLOCKCHAIN_ENABLED:-true}"
    export BLOCKCHAIN_MODE="${BLOCKCHAIN_MODE:-mvp}"
    export MODULAR_COMPLIANCE_ADDRESS="${MODULAR_COMPLIANCE_ADDRESS:-}"
    export ADMIN_API_TOKEN="${ADMIN_API_TOKEN:-local-admin-token}"
    export BACKEND_API_BASE_URL="${BACKEND_API_BASE_URL:-http://127.0.0.1:$LOCAL_BACKEND_PORT}"
    export CORS_ALLOWED_ORIGINS="${CORS_ALLOWED_ORIGINS:-http://localhost:$LOCAL_FRONTEND_PORT,http://127.0.0.1:$LOCAL_FRONTEND_PORT}"
    export NEXT_PUBLIC_API_BASE_URL="${NEXT_PUBLIC_API_BASE_URL:-/api/backend}"
    export NEXT_PUBLIC_CHAIN_ID="${NEXT_PUBLIC_CHAIN_ID:-$LOCAL_CHAIN_ID}"
    export NEXT_PUBLIC_RPC_URL="${NEXT_PUBLIC_RPC_URL:-$LOCAL_RPC_URL}"
    export NEXT_PUBLIC_BLOCK_EXPLORER_URL="${NEXT_PUBLIC_BLOCK_EXPLORER_URL:-}"
    export NEXT_PUBLIC_GA_MEASUREMENT_ID="${NEXT_PUBLIC_GA_MEASUREMENT_ID:-}"
    export GAS_PRICE_WEI="${GAS_PRICE_WEI:-2000000000}"
    export GAS_LIMIT="${GAS_LIMIT:-300000}"
    export LOCAL_FRONTEND_URL="http://127.0.0.1:$LOCAL_FRONTEND_PORT"
    export SEPOLIA_ADDRESSES_FILE="${SEPOLIA_ADDRESSES_FILE:-$BLOCKCHAIN_DIR/config/sepolia-addresses.json}"
    export SEPOLIA_CONFIG_FILE="${SEPOLIA_CONFIG_FILE:-$BLOCKCHAIN_DIR/config/sepolia.json}"
}

is_sepolia_target() {
    [ "${STACK_CHAIN_TARGET:-anvil}" = "sepolia" ]
}

apply_stack_chain_arg() {
    case "${1:-}" in
        sepolia|SEPOLIA)
            export STACK_CHAIN_TARGET="sepolia"
            ;;
        anvil|local|ANVIL|LOCAL)
            export STACK_CHAIN_TARGET="anvil"
            ;;
        *)
            fail "unknown --chain value: $1 (expected sepolia|anvil)"
            ;;
    esac
}

stack_bootstrap() {
    ensure_foundry_path
    ensure_java_path
    resolve_mvn_cmd >/dev/null
    resolve_workspace_paths
    ensure_runtime_dir
    load_stack_config
    resolve_local_config
}

is_real_address() {
    local value="${1:-}"
    [[ "$value" =~ ^0x[a-fA-F0-9]{40}$ ]] && [ "${value,,}" != "${ZERO_ADDRESS,,}" ]
}

load_deployment_addresses() {
    local deployment_file="${1:-$BLOCKCHAIN_DIR/deployments/$LOCAL_CHAIN_ID.json}"
    [ -f "$deployment_file" ] || fail "deployment file not found: $deployment_file"

    local node_deployment_file
    node_deployment_file="$(to_node_fs_path "$deployment_file")"

    eval "$(
        MSYS2_ARG_CONV_EXCL='*' node - "$node_deployment_file" <<'NODE'
const fs = require("fs");
const filePath = process.argv[2];
const data = JSON.parse(fs.readFileSync(filePath, "utf8"));

function unwrap(value) {
  if (!value) return "";
  if (typeof value === "string") return value;
  if (typeof value === "object") return value.address || value.value || "";
  return "";
}

const registry =
  unwrap(data.identityRegistry) ||
  unwrap(data.identityRegistryAddress) ||
  unwrap(data.contracts?.identityRegistry);
const token =
  unwrap(data.permissionedToken) ||
  unwrap(data.permissionedTokenAddress) ||
  unwrap(data.tokenAddress) ||
  unwrap(data.token) ||
  unwrap(data.contracts?.permissionedToken) ||
  unwrap(data.contracts?.token);
const owner = unwrap(data.owner) || unwrap(data.deployer);
const modular =
  unwrap(data.modularCompliance) ||
  unwrap(data.modularComplianceAddress) ||
  unwrap(data.contracts?.modularCompliance);
const profile = data.profile || data.blockchainMode || "mvp";
const blockchainMode = data.blockchainMode || profile;

if (!registry || !token) {
  process.stderr.write("Could not resolve deployment addresses from " + filePath + "\n");
  process.exit(1);
}

process.stdout.write(`IDENTITY_REGISTRY_ADDRESS=${registry}\n`);
process.stdout.write(`NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS=${registry}\n`);
process.stdout.write(`TOKEN_ADDRESS=${token}\n`);
process.stdout.write(`NEXT_PUBLIC_TOKEN_ADDRESS=${token}\n`);
process.stdout.write(`BLOCKCHAIN_MODE=${blockchainMode}\n`);
if (modular) {
  process.stdout.write(`MODULAR_COMPLIANCE_ADDRESS=${modular}\n`);
}
if (owner) {
  process.stdout.write(`LOCAL_DEPLOYER_ADDRESS=${owner}\n`);
}
NODE
    )"

    export IDENTITY_REGISTRY_ADDRESS
    export NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS
    export TOKEN_ADDRESS
    export NEXT_PUBLIC_TOKEN_ADDRESS
    export BLOCKCHAIN_MODE="${BLOCKCHAIN_MODE:-mvp}"
    export MODULAR_COMPLIANCE_ADDRESS="${MODULAR_COMPLIANCE_ADDRESS:-}"
    export LOCAL_DEPLOYER_ADDRESS="${LOCAL_DEPLOYER_ADDRESS:-}"
}

load_backend_env_file() {
    local backend_env_file="$BLOCKCHAIN_DIR/deployments/$LOCAL_CHAIN_ID.backend.env"
    [ -f "$backend_env_file" ] || return 0
    load_env_file "$backend_env_file"
    log "merged backend env from $backend_env_file"
}

# Wire FE+BE to committed Sepolia addresses + local sepolia.json RPC/key (no Anvil).
load_sepolia_stack_config() {
    local addresses_file="${SEPOLIA_ADDRESSES_FILE:-$BLOCKCHAIN_DIR/config/sepolia-addresses.json}"
    local config_file="${SEPOLIA_CONFIG_FILE:-$BLOCKCHAIN_DIR/config/sepolia.json}"

    [ -f "$addresses_file" ] || fail "missing Sepolia addresses file: $addresses_file"
    load_deployment_addresses "$addresses_file"

    local rpc_from_config=""
    local key_from_config=""
    local rpc_hint=""
    if [ -f "$config_file" ]; then
        eval "$(
            MSYS2_ARG_CONV_EXCL='*' node - "$(to_node_fs_path "$config_file")" <<'NODE'
const fs = require("fs");
const data = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const rpc = data.sepoliaRpcUrl || data.rpcUrl || "";
const key = data.privateKey || data.adminPrivateKey || "";
if (rpc) process.stdout.write(`rpc_from_config=${JSON.stringify(rpc)}\n`);
if (key) process.stdout.write(`key_from_config=${JSON.stringify(key)}\n`);
NODE
        )"
    fi
    eval "$(
        MSYS2_ARG_CONV_EXCL='*' node - "$(to_node_fs_path "$addresses_file")" <<'NODE'
const fs = require("fs");
const data = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const hint = data.rpcHint || data.blockExplorer || "";
// Prefer rpcHint only when it looks like an RPC URL (not explorer).
if (typeof hint === "string" && /^https?:\/\//.test(hint) && !/etherscan/i.test(hint)) {
  process.stdout.write(`rpc_hint=${JSON.stringify(hint)}\n`);
}
NODE
    )"

    export LOCAL_CHAIN_ID="11155111"
    export CHAIN_ID="11155111"
    export NEXT_PUBLIC_CHAIN_ID="11155111"
    export BLOCKCHAIN_MODE="trex"
    export SPRING_PROFILES_ACTIVE="local,sepolia"
    export NEXT_PUBLIC_BLOCK_EXPLORER_URL="${NEXT_PUBLIC_BLOCK_EXPLORER_URL:-https://sepolia.etherscan.io}"

    local rpc="${SEPOLIA_RPC_URL:-${RPC_URL:-${rpc_from_config:-$rpc_hint}}}"
    [ -n "$rpc" ] || fail "Sepolia RPC missing. Set SEPOLIA_RPC_URL or add rpcUrl to $config_file"
    case "$rpc" in
        http://127.0.0.1*|http://localhost*|https://127.0.0.1*|https://localhost*)
            fail "Sepolia mode refuses localhost RPC: $rpc"
            ;;
    esac

    export LOCAL_RPC_URL="$rpc"
    export RPC_URL="$rpc"
    export NEXT_PUBLIC_RPC_URL="$rpc"
    export SEPOLIA_RPC_URL="$rpc"

    # Prefer explicit env / sepolia.json — never keep the Anvil default key in Sepolia mode.
    local admin_key="${APP_BLOCKCHAIN_ADMIN_PRIVATE_KEY:-${ADMIN_PRIVATE_KEY:-}}"
    if [ -z "$admin_key" ] || [ "$admin_key" = "$DEFAULT_LOCAL_PRIVATE_KEY" ]; then
        admin_key="${key_from_config:-}"
    fi
    if [ -n "$admin_key" ] && [ "$admin_key" != "$DEFAULT_LOCAL_PRIVATE_KEY" ]; then
        export LOCAL_PRIVATE_KEY="$admin_key"
        export ADMIN_PRIVATE_KEY="$admin_key"
        export APP_BLOCKCHAIN_ADMIN_PRIVATE_KEY="$admin_key"
    else
        warn "Sepolia admin private key not set — chain writes will fail until APP_BLOCKCHAIN_ADMIN_PRIVATE_KEY / sepolia.json is configured"
    fi

    export APP_BLOCKCHAIN_REQUIRE_KMS_SIGNER="${APP_BLOCKCHAIN_REQUIRE_KMS_SIGNER:-false}"
    log "sepolia mode: RPC=$RPC_URL IR=$IDENTITY_REGISTRY_ADDRESS token=$TOKEN_ADDRESS mc=$MODULAR_COMPLIANCE_ADDRESS"
}

use_existing_contract_addresses() {
    export IDENTITY_REGISTRY_ADDRESS="${IDENTITY_REGISTRY_ADDRESS:-${NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS:-}}"
    export TOKEN_ADDRESS="${TOKEN_ADDRESS:-${NEXT_PUBLIC_TOKEN_ADDRESS:-}}"
    export NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS="${NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS:-$IDENTITY_REGISTRY_ADDRESS}"
    export NEXT_PUBLIC_TOKEN_ADDRESS="${NEXT_PUBLIC_TOKEN_ADDRESS:-$TOKEN_ADDRESS}"

    is_real_address "$NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS" || fail "NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS is not set to a real address"
    is_real_address "$NEXT_PUBLIC_TOKEN_ADDRESS" || fail "NEXT_PUBLIC_TOKEN_ADDRESS is not set to a real address"
}

remove_managed_block() {
    local target_file="$1"
    local block_name="$2"
    local begin_marker="# BEGIN $block_name"
    local end_marker="# END $block_name"
    local tmp_file

    [ -f "$target_file" ] || return 0

    tmp_file="$(mktemp)"
    awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin { skip = 1; next }
        $0 == end { skip = 0; next }
        skip == 0 { print }
    ' "$target_file" > "$tmp_file"
    mv "$tmp_file" "$target_file"
}

write_managed_block() {
    local target_file="$1"
    local block_name="$2"
    local block_body="$3"

    remove_managed_block "$target_file" "$block_name"

    if [ -f "$target_file" ] && [ -s "$target_file" ]; then
        printf '\n' >> "$target_file"
    fi

    {
        printf '# BEGIN %s\n' "$block_name"
        printf '%s\n' "$block_body"
        printf '# END %s\n' "$block_name"
    } >> "$target_file"
}

write_frontend_contracts_file() {
    local registry="${NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS:-${IDENTITY_REGISTRY_ADDRESS:-0x0000000000000000000000000000000000000000}}"
    local token="${NEXT_PUBLIC_TOKEN_ADDRESS:-${TOKEN_ADDRESS:-0x0000000000000000000000000000000000000000}}"
    mkdir -p "$(dirname "$FRONTEND_CONTRACTS_FILE")"
    cat > "$FRONTEND_CONTRACTS_FILE" <<EOF
/** Written/updated by root stack sync after local deploy. */
export const generatedContracts = {
  identityRegistryAddress: "$registry",
  tokenAddress: "$token"
} as const;
EOF
    log "frontend contracts config updated at $FRONTEND_CONTRACTS_FILE"
}

write_frontend_dotenv_local() {
    local dotenv_file="$FRONTEND_DIR/.env.local"
    local body
    body="$(cat <<EOF
BACKEND_API_BASE_URL=$BACKEND_API_BASE_URL
NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
NEXT_PUBLIC_CHAIN_ID=$NEXT_PUBLIC_CHAIN_ID
NEXT_PUBLIC_RPC_URL=$NEXT_PUBLIC_RPC_URL
NEXT_PUBLIC_BLOCK_EXPLORER_URL=$NEXT_PUBLIC_BLOCK_EXPLORER_URL
NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS=$NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS
NEXT_PUBLIC_TOKEN_ADDRESS=$NEXT_PUBLIC_TOKEN_ADDRESS
EOF
)"
    write_managed_block "$dotenv_file" "vaultguard-stack" "$body"
    log "frontend .env.local updated ($dotenv_file)"
}

write_frontend_env_file() {
    # Legacy name kept for callers — writes TypeScript contracts config (+ .env.local).
    write_frontend_contracts_file
    write_frontend_dotenv_local
}

write_stack_env_file() {
    cat > "$STACK_ENV_FILE" <<EOF
STACK_CHAIN_TARGET=${STACK_CHAIN_TARGET:-anvil}
LOCAL_RPC_URL=$LOCAL_RPC_URL
LOCAL_CHAIN_ID=$LOCAL_CHAIN_ID
LOCAL_PRIVATE_KEY=$LOCAL_PRIVATE_KEY
LOCAL_BACKEND_PORT=$LOCAL_BACKEND_PORT
LOCAL_FRONTEND_PORT=$LOCAL_FRONTEND_PORT
SERVER_PORT=$SERVER_PORT
SPRING_PROFILES_ACTIVE=$SPRING_PROFILES_ACTIVE
BLOCKCHAIN_ENABLED=$BLOCKCHAIN_ENABLED
BLOCKCHAIN_MODE=$BLOCKCHAIN_MODE
MODULAR_COMPLIANCE_ADDRESS=$MODULAR_COMPLIANCE_ADDRESS
BACKEND_API_BASE_URL=$BACKEND_API_BASE_URL
ADMIN_API_TOKEN=$ADMIN_API_TOKEN
CORS_ALLOWED_ORIGINS=$CORS_ALLOWED_ORIGINS
RPC_URL=${RPC_URL:-$LOCAL_RPC_URL}
CHAIN_ID=${CHAIN_ID:-$LOCAL_CHAIN_ID}
IDENTITY_REGISTRY_ADDRESS=$IDENTITY_REGISTRY_ADDRESS
TOKEN_ADDRESS=$TOKEN_ADDRESS
ADMIN_PRIVATE_KEY=${ADMIN_PRIVATE_KEY:-$LOCAL_PRIVATE_KEY}
APP_BLOCKCHAIN_ADMIN_PRIVATE_KEY=${APP_BLOCKCHAIN_ADMIN_PRIVATE_KEY:-${ADMIN_PRIVATE_KEY:-$LOCAL_PRIVATE_KEY}}
APP_BLOCKCHAIN_REQUIRE_KMS_SIGNER=${APP_BLOCKCHAIN_REQUIRE_KMS_SIGNER:-false}
GAS_PRICE_WEI=$GAS_PRICE_WEI
GAS_LIMIT=$GAS_LIMIT
NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
NEXT_PUBLIC_CHAIN_ID=$NEXT_PUBLIC_CHAIN_ID
NEXT_PUBLIC_RPC_URL=$NEXT_PUBLIC_RPC_URL
NEXT_PUBLIC_BLOCK_EXPLORER_URL=$NEXT_PUBLIC_BLOCK_EXPLORER_URL
NEXT_PUBLIC_GA_MEASUREMENT_ID=$NEXT_PUBLIC_GA_MEASUREMENT_ID
NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS=$NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS
NEXT_PUBLIC_TOKEN_ADDRESS=$NEXT_PUBLIC_TOKEN_ADDRESS
GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID:-}
GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET:-}
DATABASE_URL=${DATABASE_URL:-}
DATABASE_USERNAME=${DATABASE_USERNAME:-}
DATABASE_PASSWORD=${DATABASE_PASSWORD:-}
DATABASE_DRIVER=${DATABASE_DRIVER:-}
SEPOLIA_RPC_URL=${SEPOLIA_RPC_URL:-}
ETHERSCAN_API_KEY=${ETHERSCAN_API_KEY:-}
EOF
}

stack_sync_env() {
    stack_bootstrap

    if is_sepolia_target; then
        load_sepolia_stack_config
    elif [ -f "$BLOCKCHAIN_DIR/deployments/$LOCAL_CHAIN_ID.json" ]; then
        load_deployment_addresses "$BLOCKCHAIN_DIR/deployments/$LOCAL_CHAIN_ID.json"
        load_backend_env_file
    else
        if [ -f "$STACK_ENV_FILE" ]; then
            load_env_file "$STACK_ENV_FILE"
        fi
        use_existing_contract_addresses
    fi

    write_frontend_env_file
    write_stack_env_file

    log "chain target: ${STACK_CHAIN_TARGET:-anvil}"
    log "frontend contracts config: $FRONTEND_CONTRACTS_FILE"
    log "stack env written to $STACK_ENV_FILE"
    log "identity registry: $NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS"
    log "permissioned token: $NEXT_PUBLIC_TOKEN_ADDRESS"
    log "rpc: ${RPC_URL:-$LOCAL_RPC_URL}"
    log "blockchain mode: $BLOCKCHAIN_MODE"
}

stop_pid_file() {
    local pid_file="$1"
    local label="$2"

    if [ ! -f "$pid_file" ]; then
        return 0
    fi

    local pid
    pid="$(cat "$pid_file")"
    if kill -0 "$pid" >/dev/null 2>&1; then
        kill "$pid" >/dev/null 2>&1 || true
        log "stopped $label (pid $pid)"
    else
        log "$label pid file existed but process $pid was not running"
    fi

    rm -f "$pid_file"
}

stop_process_pattern() {
    local pattern="$1"
    if command -v pkill >/dev/null 2>&1; then
        pkill -f "$pattern" >/dev/null 2>&1 || true
        return 0
    fi

    if command -v pgrep >/dev/null 2>&1; then
        while IFS= read -r pid; do
            kill "$pid" >/dev/null 2>&1 || true
        done < <(pgrep -f "$pattern" || true)
    fi
}

kill_port_listeners() {
    local port="$1"

    if command -v lsof >/dev/null 2>&1; then
        while IFS= read -r pid; do
            kill -9 "$pid" >/dev/null 2>&1 || true
        done < <(lsof -ti tcp:"$port" -sTCP:LISTEN 2>/dev/null || true)
        return 0
    fi

    if command -v ss >/dev/null 2>&1; then
        while IFS= read -r pid; do
            [ -n "$pid" ] && kill -9 "$pid" >/dev/null 2>&1 || true
        done < <(ss -ltnp "sport = :$port" 2>/dev/null | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' || true)
        return 0
    fi

    if command -v netstat >/dev/null 2>&1; then
        while IFS= read -r pid; do
            [ -n "$pid" ] || continue
            if command -v taskkill >/dev/null 2>&1; then
                taskkill //PID "$pid" //F >/dev/null 2>&1 || true
            else
                kill -9 "$pid" >/dev/null 2>&1 || true
            fi
        done < <(netstat -ano 2>/dev/null | awk -v p=":$port" '$0 ~ p && $0 ~ /LISTEN/ {print $NF}' | sort -u || true)
    fi
}

start_managed_process() {
    local label="$1"
    local pid_file="$2"
    local log_file="$3"
    local workdir="$4"
    shift 4

    stop_pid_file "$pid_file" "$label"
    mkdir -p "$(dirname "$log_file")"

    (
        cd "$workdir"
        if command -v setsid >/dev/null 2>&1; then
            setsid "$@" > "$log_file" 2>&1 < /dev/null &
        else
            nohup "$@" > "$log_file" 2>&1 < /dev/null &
        fi
        echo $! > "$pid_file"
    )

    log "$label started (pid $(cat "$pid_file"))"
}

wait_for_http() {
    local url="$1"
    local attempts="${2:-30}"
    local attempt
    local code

    # Accept 2xx and 503: Spring Actuator returns 503 when overall health is DOWN
    # (e.g. RPC briefly unavailable) even though the API process is up.
    for attempt in $(seq 1 "$attempts"); do
        code="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' "$url" 2>/dev/null || true)"
        case "$code" in
            2*|503) return 0 ;;
        esac
        sleep 1
    done

    return 1
}

remove_path_if_exists() {
    local path="$1"
    local dry_run="${2:-false}"

    [ -e "$path" ] || return 0

    if [ "$dry_run" = true ]; then
        log "would remove $path"
        return 0
    fi

    rm -rf "$path"
    log "removed $path"
}

remove_paths_in_dir() {
    local base_dir="$1"
    local dry_run="$2"
    shift 2

    local artifact
    for artifact in "$@"; do
        remove_path_if_exists "$base_dir/$artifact" "$dry_run"
    done
}

clean_build_artifacts() {
    local include_deps="${1:-false}"
    local include_runtime="${2:-false}"
    local include_deployments="${3:-false}"
    local dry_run="${4:-false}"
    local clean_backend="${5:-true}"
    local clean_blockchain="${6:-true}"
    local clean_frontend="${7:-true}"

    if [ "$clean_backend" = true ]; then
        log "cleaning backend temporary files"
        remove_paths_in_dir "$BACKEND_DIR" "$dry_run" target
    fi

    if [ "$clean_blockchain" = true ]; then
        log "cleaning blockchain temporary files"
        remove_paths_in_dir "$BLOCKCHAIN_DIR" "$dry_run" \
            cache out broadcast .local artifacts typechain
        if [ "$include_deployments" = true ]; then
            remove_path_if_exists "$BLOCKCHAIN_DIR/deployments" "$dry_run"
        fi
        if [ "$include_deps" = true ]; then
            remove_path_if_exists "$BLOCKCHAIN_DIR/node_modules" "$dry_run"
        fi
    fi

    if [ "$clean_frontend" = true ]; then
        log "cleaning frontend temporary files"
        remove_paths_in_dir "$FRONTEND_DIR" "$dry_run" \
            .next out dist build coverage .cache .home .vitest-temp .turbo \
            .local-runtime tsconfig.tsbuildinfo .eslintcache
        if [ "$include_deps" = true ]; then
            remove_path_if_exists "$FRONTEND_DIR/node_modules" "$dry_run"
        fi
    fi

    if [ "$include_runtime" = true ]; then
        log "cleaning workspace runtime"
        remove_path_if_exists "$RUNTIME_DIR" "$dry_run"
    fi
}

port_in_use() {
    local port="$1"

    if command -v lsof >/dev/null 2>&1; then
        lsof -ti tcp:"$port" -sTCP:LISTEN >/dev/null 2>&1
        return $?
    fi

    if command -v ss >/dev/null 2>&1; then
        ss -ltn "sport = :$port" 2>/dev/null | grep -q ":$port"
        return $?
    fi

    if command -v netstat >/dev/null 2>&1; then
        netstat -ano 2>/dev/null | grep -q ":$port.*LISTEN"
        return $?
    fi

    return 1
}

print_stack_status() {
    stack_bootstrap

    log "stack status"
    if [ -f "$BACKEND_PID_FILE" ] && kill -0 "$(cat "$BACKEND_PID_FILE")" 2>/dev/null; then
        log "backend: running (pid $(cat "$BACKEND_PID_FILE"))"
    elif port_in_use "$LOCAL_BACKEND_PORT"; then
        log "backend: port $LOCAL_BACKEND_PORT in use"
    else
        log "backend: stopped"
    fi

    if [ -f "$FRONTEND_PID_FILE" ] && kill -0 "$(cat "$FRONTEND_PID_FILE")" 2>/dev/null; then
        log "frontend: running (pid $(cat "$FRONTEND_PID_FILE"))"
    elif port_in_use "$LOCAL_FRONTEND_PORT"; then
        log "frontend: port $LOCAL_FRONTEND_PORT in use"
    else
        log "frontend: stopped"
    fi

    if port_in_use 8545; then
        log "blockchain: anvil listening on 8545"
    else
        log "blockchain: stopped"
    fi
}

print_stack_urls() {
    log "stack ready"
    log "frontend:    $LOCAL_FRONTEND_URL"
    log "governance:  $LOCAL_FRONTEND_URL/governance"
    log "backend:     $BACKEND_API_BASE_URL"
    log "health:      $BACKEND_API_BASE_URL/actuator/health"
    log "swagger:     $BACKEND_API_BASE_URL/swagger-ui.html"
    log "logs:        $BACKEND_LOG_FILE"
    log "             $FRONTEND_LOG_FILE"
}

project_selected() {
    local name="$1"
    shift
    local project

    for project in "$@"; do
        if [ "$project" = "all" ] || [ "$project" = "$name" ]; then
            return 0
        fi
    done
    return 1
}

install_npm_workspace() {
    local workspace_dir="$1"
    local label="$2"
    local force="${3:-false}"

    if [ "$force" = false ] && [ -d "$workspace_dir/node_modules" ]; then
        log "$label: dependencies present (use deps --update to refresh)"
        return 0
    fi

    if [ "$force" = true ] && [ -d "$workspace_dir/node_modules" ]; then
        log "$label: refreshing dependencies"
    else
        log "$label: installing dependencies"
    fi

    if [ -f "$workspace_dir/package-lock.json" ]; then
        (cd "$workspace_dir" && npm ci)
    else
        (cd "$workspace_dir" && npm install)
    fi
}

# Warm / refresh tool caches (forge build cache, npm, Maven deps) without starting services.
stack_update_cache() {
    local force_npm="${1:-false}"
    stack_bootstrap
    stack_check_tooling

    log "updating blockchain forge cache (forge build)"
    (cd "$BLOCKCHAIN_DIR" && forge build)

    log "updating blockchain npm packages"
    install_npm_workspace "$BLOCKCHAIN_DIR" "blockchain" "$force_npm"

    log "updating frontend npm packages"
    install_npm_workspace "$FRONTEND_DIR" "frontend" "$force_npm"

    log "updating backend Maven dependencies (-U)"
    (cd "$BACKEND_DIR" && run_mvn -q -U -DskipTests dependency:resolve compile)

    log "caches and dependencies updated"
}

stack_install_deps() {
    local skip_check="${1:-false}"
    local force="${2:-false}"
    stack_bootstrap

    if [ "$skip_check" = false ]; then
        stack_check_tooling
    fi

    local blockchain_pid=""
    local frontend_pid=""

    if [ "$force" = true ] || [ ! -d "$BLOCKCHAIN_DIR/node_modules" ]; then
        log "blockchain: installing dependencies"
        if [ -f "$BLOCKCHAIN_DIR/package-lock.json" ]; then
            (cd "$BLOCKCHAIN_DIR" && npm ci) &
        else
            (cd "$BLOCKCHAIN_DIR" && npm install) &
        fi
        blockchain_pid=$!
    else
        log "blockchain: dependencies present"
    fi

    if [ "$force" = true ] || [ ! -d "$FRONTEND_DIR/node_modules" ]; then
        log "frontend: installing dependencies"
        if [ -f "$FRONTEND_DIR/package-lock.json" ]; then
            (cd "$FRONTEND_DIR" && npm ci) &
        else
            (cd "$FRONTEND_DIR" && npm install) &
        fi
        frontend_pid=$!
    else
        log "frontend: dependencies present"
    fi

    if [ -n "$blockchain_pid" ]; then
        wait "$blockchain_pid" || fail "blockchain npm install failed"
    fi
    if [ -n "$frontend_pid" ]; then
        wait "$frontend_pid" || fail "frontend npm install failed"
    fi

    log "blockchain: warming forge cache"
    (cd "$BLOCKCHAIN_DIR" && forge build)

    if [ "$force" = true ]; then
        log "backend: resolving dependencies (-U)"
        (cd "$BACKEND_DIR" && run_mvn -q -U -DskipTests compile)
    else
        log "backend: compiling (resolves Maven deps)"
        (cd "$BACKEND_DIR" && run_mvn -q -DskipTests compile)
    fi

    log "dependencies ready"
}

# Full local bring-up: tooling check → cache/deps → start all three services.
stack_up() {
    local skip_deps=false
    local force_deps=false
    local no_stop=false
    local projects=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --skip-deps)
                skip_deps=true
                ;;
            --update|--force)
                force_deps=true
                ;;
            --no-stop)
                no_stop=true
                ;;
            --chain)
                shift
                [ $# -gt 0 ] || fail "--chain requires sepolia|anvil"
                apply_stack_chain_arg "$1"
                ;;
            --chain=*)
                apply_stack_chain_arg "${1#--chain=}"
                ;;
            all|blockchain|backend|frontend)
                projects+=("$1")
                ;;
            -h|--help)
                cat <<'EOF'
Usage: root/scripts/stack.sh up [options] [projects...]

Bring up the local stack (default: all three projects):
  1) check tooling
  2) update caches + install dependencies
  3) stop previous processes
  4) start blockchain → backend → frontend

Options:
  --chain sepolia|anvil  Chain target (default anvil). sepolia skips Anvil.
  --update / --force     Force npm reinstall + Maven -U
  --skip-deps            Skip dependency/cache step
  --no-stop              Do not stop services before start
  -h, --help             Show this help

Projects: all (default), blockchain, backend, frontend

Examples:
  stack.sh up --chain sepolia --skip-deps backend frontend
  stack.sh up --chain anvil
EOF
                exit 0
                ;;
            *)
                fail "unknown option or project: $1"
                ;;
        esac
        shift
    done

    if [ ${#projects[@]} -eq 0 ]; then
        if is_sepolia_target; then
            # Sepolia: FE+BE against live chain (no Anvil bring-up).
            projects=(backend frontend)
        else
            projects=(all)
        fi
    fi

    stack_bootstrap

    if [ "$skip_deps" = true ]; then
        log "skipping dependency/cache setup (--skip-deps)"
    else
        stack_install_deps false "$force_deps"
    fi

    local start_args=(--skip-deps)
    if [ "$no_stop" = true ]; then
        start_args+=(--no-stop)
    fi
    if is_sepolia_target; then
        start_args+=(--chain sepolia)
    fi
    start_args+=("${projects[@]}")

    stack_start "${start_args[@]}"
}

stack_check_tooling() {
    stack_bootstrap

    local missing_tools=()
    local tool
    # Anvil/forge/cast only required for local chain bring-up (not Sepolia FE+BE mode).
    local required_tools=(node npm java curl)
    if ! is_sepolia_target; then
        required_tools+=(forge cast anvil)
    fi

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if ! command -v mvn >/dev/null 2>&1 && ! command -v mvn.cmd >/dev/null 2>&1; then
        missing_tools+=("mvn")
    fi

    # Detect broken Windows java stubs that exist on PATH but exit 127.
    if command -v java >/dev/null 2>&1; then
        if ! java -version >/dev/null 2>&1; then
            missing_tools+=("java(working JDK — set JAVA_HOME)")
        fi
    fi

    if ! run_mvn -v >/dev/null 2>&1; then
        missing_tools+=("mvn(runnable)")
    fi

    local problems=()
    if [ "${#missing_tools[@]}" -gt 0 ]; then
        problems+=("missing commands: ${missing_tools[*]}")
    fi

    if command -v node >/dev/null 2>&1; then
        local node_major
        node_major="$(node -p 'Number(process.versions.node.split(".")[0])')"
        if [ "$node_major" -lt 20 ]; then
            problems+=("Node.js 20+ is required (found $(node -v))")
        fi
    fi

    if command -v npm >/dev/null 2>&1; then
        local npm_major
        npm_major="$(npm -v | cut -d. -f1)"
        if [ "$npm_major" -lt 10 ]; then
            problems+=("npm 10+ is required (found $(npm -v))")
        fi
    fi

    if command -v java >/dev/null 2>&1 && java -version >/dev/null 2>&1; then
        local java_major
        java_major="$(java -version 2>&1 | sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p' | head -n 1)"
        if [ -z "$java_major" ]; then
            problems+=("could not parse Java version (found $(java -version 2>&1 | head -n 1))")
        elif [ "$java_major" -lt 21 ]; then
            problems+=("Java 21+ is required (found $(java -version 2>&1 | head -n 1))")
        fi
    fi

    [ "${#problems[@]}" -eq 0 ] || fail "$(printf '%s; ' "${problems[@]}")"

    log "tooling ok (chain target: ${STACK_CHAIN_TARGET:-anvil})"
    log "node $(node -v)"
    log "npm $(npm -v)"
    log "java $(java -version 2>&1 | head -n 1)"
    log "maven $(run_mvn -v 2>/dev/null | head -n 1)"
    log "mvn cmd: $(resolve_mvn_cmd)"
    if ! is_sepolia_target; then
        log "forge $(forge --version | head -n 1)"
        log "cast $(cast --version | head -n 1)"
        log "anvil $(anvil --version | head -n 1)"
    else
        log "foundry tools skipped (sepolia mode)"
    fi
}

stack_stop() {
    local projects=("all")
    if [ $# -gt 0 ]; then
        projects=("$@")
    fi

    stack_bootstrap
    log "stopping stack"

    if project_selected frontend "${projects[@]}"; then
        stop_pid_file "$FRONTEND_PID_FILE" "frontend"
        (cd "$FRONTEND_DIR" && npm run local:stop >/dev/null 2>&1 || true)
        stop_process_pattern "next dev"
        kill_port_listeners "$LOCAL_FRONTEND_PORT"
    fi

    if project_selected backend "${projects[@]}"; then
        stop_pid_file "$BACKEND_PID_FILE" "backend"
        stop_process_pattern "spring-boot:run"
        kill_port_listeners "$LOCAL_BACKEND_PORT"
    fi

    if project_selected blockchain "${projects[@]}"; then
        (cd "$BLOCKCHAIN_DIR" && npm run local:down >/dev/null 2>&1 || true)
        stop_process_pattern "anvil"
        kill_port_listeners 8545
    fi

    log "stack stopped"
}

ensure_contract_addresses() {
    if is_sepolia_target; then
        load_sepolia_stack_config
        return 0
    fi

    if [ -f "$BLOCKCHAIN_DIR/deployments/$LOCAL_CHAIN_ID.json" ]; then
        load_deployment_addresses "$BLOCKCHAIN_DIR/deployments/$LOCAL_CHAIN_ID.json"
        load_backend_env_file
        return 0
    fi

    if [ -f "$STACK_ENV_FILE" ]; then
        load_env_file "$STACK_ENV_FILE"
        use_existing_contract_addresses
        return 0
    fi

    fail "no deployment found. Start blockchain first, or use: stack.sh sync --chain sepolia"
}

start_blockchain_service() {
    if is_sepolia_target; then
        log "sepolia mode: skipping Anvil — syncing production Sepolia addresses"
        stack_sync_env
        return 0
    fi

    log "starting blockchain (anvil + deploy; tests skipped)"
    # Always local:up — local:fresh deletes out/ and forces a full solc rebuild (~5m).
    # Blockchain repo stays independent: stack only invokes its npm scripts.
    (cd "$BLOCKCHAIN_DIR" && RUN_FORGE_TESTS=false npm run local:up)
    load_deployment_addresses "$BLOCKCHAIN_DIR/deployments/$LOCAL_CHAIN_ID.json"
    stack_sync_env
}

start_backend_service() {
    # Addresses from stack.env; DB credentials live in application.yml (Neon).
    load_stack_config
    if [ -f "$STACK_ENV_FILE" ]; then
        load_env_file "$STACK_ENV_FILE"
    fi

    export RPC_URL="${RPC_URL:-$LOCAL_RPC_URL}"
    export CHAIN_ID="${CHAIN_ID:-$LOCAL_CHAIN_ID}"
    export BLOCKCHAIN_MODE="${BLOCKCHAIN_MODE:-mvp}"
    export SPRING_PROFILES_ACTIVE="${SPRING_PROFILES_ACTIVE:-local}"
    export MODULAR_COMPLIANCE_ADDRESS="${MODULAR_COMPLIANCE_ADDRESS:-}"
    export ADMIN_PRIVATE_KEY="${ADMIN_PRIVATE_KEY:-$LOCAL_PRIVATE_KEY}"
    export APP_BLOCKCHAIN_ADMIN_PRIVATE_KEY="${APP_BLOCKCHAIN_ADMIN_PRIVATE_KEY:-$ADMIN_PRIVATE_KEY}"
    export APP_BLOCKCHAIN_REQUIRE_KMS_SIGNER="${APP_BLOCKCHAIN_REQUIRE_KMS_SIGNER:-false}"
    export IDENTITY_REGISTRY_ADDRESS="${IDENTITY_REGISTRY_ADDRESS:-}"
    export TOKEN_ADDRESS="${TOKEN_ADDRESS:-}"
    export SERVER_PORT="${SERVER_PORT:-$LOCAL_BACKEND_PORT}"
    export CORS_ALLOWED_ORIGINS="${CORS_ALLOWED_ORIGINS:-http://localhost:$LOCAL_FRONTEND_PORT,http://127.0.0.1:$LOCAL_FRONTEND_PORT}"
    # Optional override of application.yml Neon settings via stack-config exports
    export SPRING_DATASOURCE_URL="${DATABASE_URL:-}"
    export SPRING_DATASOURCE_USERNAME="${DATABASE_USERNAME:-}"
    export SPRING_DATASOURCE_PASSWORD="${DATABASE_PASSWORD:-}"
    if [ -n "${DATABASE_DRIVER:-}" ]; then
        export SPRING_DATASOURCE_DRIVER_CLASS_NAME="$DATABASE_DRIVER"
    fi

    log "starting backend (profiles=$SPRING_PROFILES_ACTIVE mode=$BLOCKCHAIN_MODE port=$SERVER_PORT)"
    # start_managed_process execs a real binary via nohup — cannot use bash function run_mvn.
    local mvn_bin
    mvn_bin="$(resolve_mvn_cmd)"
    start_managed_process \
        "backend" \
        "$BACKEND_PID_FILE" \
        "$BACKEND_LOG_FILE" \
        "$BACKEND_DIR" \
        "$mvn_bin" spring-boot:run

    wait_for_http "$BACKEND_API_BASE_URL/actuator/health" 120 \
        || fail "backend did not become healthy. Check $BACKEND_LOG_FILE"
}

start_frontend_service() {
    if [ -f "$STACK_ENV_FILE" ]; then
        load_env_file "$STACK_ENV_FILE"
    fi
    # Sync contract addresses into the frontend repo (no sibling coupling at runtime).
    write_frontend_env_file

    log "starting frontend"
    start_managed_process \
        "frontend" \
        "$FRONTEND_PID_FILE" \
        "$FRONTEND_LOG_FILE" \
        "$FRONTEND_DIR" \
        npm run dev -- --hostname 0.0.0.0 --port "$LOCAL_FRONTEND_PORT"

    wait_for_http "$LOCAL_FRONTEND_URL" 90 \
        || fail "frontend did not become ready. Check $FRONTEND_LOG_FILE"
}

stack_start() {
    local run_stop=true
    local skip_deps=false
    local projects=("all")

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                cat <<'EOF'
Usage: root/scripts/stack.sh start [options] [projects...]

Starts blockchain (Anvil + deploy), backend, and/or frontend.
With --chain sepolia, Anvil is skipped and FE+BE use live Sepolia.

Options:
  --chain sepolia|anvil  Chain target (default anvil)
  --no-stop              Skip stop step before starting.
  --skip-deps            Skip dependency install/compile (faster restart).
  -h, --help             Show this help message.

Projects: all (default), blockchain, backend, frontend
EOF
                exit 0
                ;;
            --no-stop)
                run_stop=false
                ;;
            --skip-deps)
                skip_deps=true
                ;;
            --chain)
                shift
                [ $# -gt 0 ] || fail "--chain requires sepolia|anvil"
                apply_stack_chain_arg "$1"
                ;;
            --chain=*)
                apply_stack_chain_arg "${1#--chain=}"
                ;;
            all|blockchain|backend|frontend)
                if [ "${projects[0]}" = "all" ]; then
                    projects=("$1")
                else
                    projects+=("$1")
                fi
                ;;
            *)
                fail "unknown option or project: $1"
                ;;
        esac
        shift
    done

    stack_bootstrap

    if [ "$skip_deps" = false ]; then
        stack_install_deps false false
    else
        log "skipping dependency setup (--skip-deps)"
    fi

    # In sepolia mode, "all" / "blockchain" must not require Anvil stop/start.
    if is_sepolia_target; then
        if [ "${projects[0]}" = "all" ]; then
            projects=(backend frontend)
        fi
        # Still sync before start; never launch Anvil.
        local filtered=()
        local p
        for p in "${projects[@]}"; do
            if [ "$p" != "blockchain" ]; then
                filtered+=("$p")
            fi
        done
        if [ ${#filtered[@]} -eq 0 ]; then
            filtered=(backend frontend)
        fi
        projects=("${filtered[@]}")
    fi

    if [ "$run_stop" = true ]; then
        stack_stop "${projects[@]}"
    else
        log "skipping stop step (--no-stop)"
    fi

    if is_sepolia_target; then
        stack_sync_env
    elif project_selected blockchain "${projects[@]}"; then
        start_blockchain_service
    elif project_selected backend "${projects[@]}" || project_selected frontend "${projects[@]}"; then
        ensure_contract_addresses
        stack_sync_env
    fi

    if project_selected backend "${projects[@]}"; then
        start_backend_service
    fi

    if project_selected frontend "${projects[@]}"; then
        start_frontend_service
    fi

    if project_selected all "${projects[@]}" || { is_sepolia_target && project_selected backend "${projects[@]}" && project_selected frontend "${projects[@]}"; }; then
        print_stack_urls
        if is_sepolia_target; then
            log "mode=sepolia (production chain) RPC=${RPC_URL:-$LOCAL_RPC_URL}"
        fi
    elif project_selected blockchain "${projects[@]}"; then
        log "blockchain ready on $LOCAL_RPC_URL (chain $LOCAL_CHAIN_ID)"
    elif project_selected backend "${projects[@]}"; then
        log "backend ready at $BACKEND_API_BASE_URL"
    elif project_selected frontend "${projects[@]}"; then
        log "frontend ready at $LOCAL_FRONTEND_URL"
    fi
}

stack_verify() {
    stack_bootstrap
    stack_check_tooling
    stack_install_deps false false

    log "running blockchain tests (forge)"
    (cd "$BLOCKCHAIN_DIR" && npm test)

    log "running blockchain security tests (forge)"
    (cd "$BLOCKCHAIN_DIR" && npm run test:security)

    log "running backend tests (mvn) — includes Phase5MarketplaceHappyPathTest"
    (cd "$BACKEND_DIR" && run_mvn test)

    log "running frontend typecheck"
    (cd "$FRONTEND_DIR" && npm run typecheck)

    log "running frontend tests (vitest)"
    (cd "$FRONTEND_DIR" && npm run test)

    log "Phase 5 E2E path documented in root/scripts/e2e-phase5.md"
    log "verification complete"
}
