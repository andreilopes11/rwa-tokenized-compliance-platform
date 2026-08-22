# Shared stack defaults (replaced root .env). Sourced by common.sh.
# Neon credentials live in backend application.yml — not duplicated here.
#
# Chain target:
#   STACK_CHAIN_TARGET=anvil   → local Anvil + deploy (default)
#   STACK_CHAIN_TARGET=sepolia → FE+BE against live Sepolia (skip Anvil; production-like chain)

export STACK_CHAIN_TARGET="${STACK_CHAIN_TARGET:-anvil}"

export LOCAL_RPC_URL="${LOCAL_RPC_URL:-http://127.0.0.1:8545}"
export LOCAL_CHAIN_ID="${LOCAL_CHAIN_ID:-11155111}"
export LOCAL_PRIVATE_KEY="${LOCAL_PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
export LOCAL_BACKEND_PORT="${LOCAL_BACKEND_PORT:-8080}"
export LOCAL_FRONTEND_PORT="${LOCAL_FRONTEND_PORT:-3000}"
export SERVER_PORT="${SERVER_PORT:-$LOCAL_BACKEND_PORT}"
export SPRING_PROFILES_ACTIVE="${SPRING_PROFILES_ACTIVE:-local}"
export BLOCKCHAIN_ENABLED="${BLOCKCHAIN_ENABLED:-true}"
export BLOCKCHAIN_MODE="${BLOCKCHAIN_MODE:-mvp}"
export ADMIN_API_TOKEN="${ADMIN_API_TOKEN:-local-admin-token}"
export BACKEND_API_BASE_URL="${BACKEND_API_BASE_URL:-http://127.0.0.1:$LOCAL_BACKEND_PORT}"
export CORS_ALLOWED_ORIGINS="${CORS_ALLOWED_ORIGINS:-http://localhost:$LOCAL_FRONTEND_PORT,http://127.0.0.1:$LOCAL_FRONTEND_PORT}"
export NEXT_PUBLIC_API_BASE_URL="${NEXT_PUBLIC_API_BASE_URL:-/api/backend}"
export NEXT_PUBLIC_CHAIN_ID="${NEXT_PUBLIC_CHAIN_ID:-$LOCAL_CHAIN_ID}"
export NEXT_PUBLIC_RPC_URL="${NEXT_PUBLIC_RPC_URL:-$LOCAL_RPC_URL}"
export NEXT_PUBLIC_BLOCK_EXPLORER_URL="${NEXT_PUBLIC_BLOCK_EXPLORER_URL:-}"
export GAS_PRICE_WEI="${GAS_PRICE_WEI:-2000000000}"
export GAS_LIMIT="${GAS_LIMIT:-300000}"
export LOCAL_FRONTEND_URL="http://127.0.0.1:$LOCAL_FRONTEND_PORT"

# Neon (also hardcoded in application.yml — exported for scripts that still check DATABASE_*)
export DATABASE_URL="${DATABASE_URL:-jdbc:postgresql://ep-nameless-smoke-av0zy2vh.c-11.us-east-1.aws.neon.tech/neondb?sslmode=require}"
export DATABASE_USERNAME="${DATABASE_USERNAME:-neondb_owner}"
export DATABASE_PASSWORD="${DATABASE_PASSWORD:-npg_0nsm4xeHSYKy}"
export DATABASE_DRIVER="${DATABASE_DRIVER:-org.postgresql.Driver}"
export DATABASE_POOL_SIZE="${DATABASE_POOL_SIZE:-5}"

# Sepolia helpers (used when STACK_CHAIN_TARGET=sepolia)
export SEPOLIA_ADDRESSES_FILE="${SEPOLIA_ADDRESSES_FILE:-}"
export SEPOLIA_CONFIG_FILE="${SEPOLIA_CONFIG_FILE:-}"
export SEPOLIA_RPC_URL="${SEPOLIA_RPC_URL:-}"
