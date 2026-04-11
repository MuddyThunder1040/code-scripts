#!/usr/bin/env bash
# =============================================================================
# health-check.sh  —  Health check for all ShopCloud services
# Usage: ./health-check.sh [--environment local|blue|green|prod]
# =============================================================================
set -euo pipefail

# ── Colour codes ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Parse arguments ───────────────────────────────────────────────────────────
ENVIRONMENT="local"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment|-e)
      ENVIRONMENT="${2:-local}"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [--environment local|blue|green|prod]"
      echo ""
      echo "  Environments:"
      echo "    local  — Checks http://localhost (default)"
      echo "    blue   — Checks blue deployment (port 8080)"
      echo "    green  — Checks green deployment (port 8081)"
      echo "    prod   — Checks via kubectl port-forward"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# ── Set base URL based on environment ────────────────────────────────────────
case "$ENVIRONMENT" in
  local)
    BASE_URL="http://localhost"
    ;;
  blue)
    BASE_URL="http://localhost:8080"
    ;;
  green)
    BASE_URL="http://localhost:8081"
    ;;
  prod)
    BASE_URL="http://localhost"
    USE_PORT_FORWARD=true
    ;;
  *)
    echo -e "${RED}Unknown environment: ${ENVIRONMENT}${NC}"
    exit 1
    ;;
esac

USE_PORT_FORWARD="${USE_PORT_FORWARD:-false}"

# ── Service definitions ───────────────────────────────────────────────────────
declare -a SERVICE_NAMES=(
  "api-gateway"
  "user-service"
  "product-service"
  "order-service"
  "cart-service"
)

declare -A SERVICE_PATHS=(
  [api-gateway]="/api/health"
  [user-service]="/api/users/health"
  [product-service]="/api/products/health"
  [order-service]="/api/orders/health"
  [cart-service]="/api/cart/health"
)

declare -A SERVICE_K8S_PORTS=(
  [user-service]=8001
  [product-service]=8002
  [order-service]=8003
  [cart-service]=8004
)

declare -A SERVICE_LOCAL_PORTS=(
  [user-service]=18001
  [product-service]=18002
  [order-service]=18003
  [cart-service]=18004
)

K8S_NAMESPACE="ecommerce-blue"

# ── Result accumulators ───────────────────────────────────────────────────────
declare -A RESULT_STATUS
declare -A RESULT_TIME
declare -A RESULT_VERSION
declare -A RESULT_HTTP_CODE
OVERALL_EXIT=0

# ── Helper functions ──────────────────────────────────────────────────────────
log_info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

check_service() {
  local name="$1"
  local url="$2"

  local START_MS END_MS ELAPSED_MS HTTP_CODE RESPONSE

  START_MS=$(date +%s%3N)
  RESPONSE=$(curl -s -o /tmp/hc_response.json \
    -w "%{http_code}" \
    --max-time 10 \
    --connect-timeout 5 \
    "$url" 2>/dev/null || echo "000")
  HTTP_CODE="$RESPONSE"
  END_MS=$(date +%s%3N)
  ELAPSED_MS=$((END_MS - START_MS))

  RESULT_HTTP_CODE[$name]="$HTTP_CODE"
  RESULT_TIME[$name]="${ELAPSED_MS}ms"

  if [[ "$HTTP_CODE" == "200" ]]; then
    VERSION=$(python3 -c "
import sys, json
try:
    d = json.load(open('/tmp/hc_response.json'))
    print(d.get('version', d.get('status', '?')))
except:
    print('?')
" 2>/dev/null || echo "?")
    RESULT_STATUS[$name]="HEALTHY"
    RESULT_VERSION[$name]="$VERSION"
  else
    RESULT_STATUS[$name]="UNHEALTHY"
    RESULT_VERSION[$name]="-"
    OVERALL_EXIT=1
  fi
}

setup_port_forwards() {
  log_info "Setting up kubectl port-forwards for prod environment..."
  PF_PIDS=()
  for svc in user-service product-service order-service cart-service; do
    LOCAL_PORT="${SERVICE_LOCAL_PORTS[$svc]}"
    K8S_PORT="${SERVICE_K8S_PORTS[$svc]}"
    kubectl port-forward "service/${svc}" "${LOCAL_PORT}:${K8S_PORT}" \
      -n "$K8S_NAMESPACE" &>/dev/null &
    PF_PIDS+=($!)
    log_info "  ${svc}: localhost:${LOCAL_PORT} -> ${K8S_PORT}"
  done
  sleep 3
}

cleanup_port_forwards() {
  for pid in "${PF_PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
}

# ── Print header ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}================================================================${NC}"
echo -e "${BOLD}   ShopCloud Health Check — Environment: ${ENVIRONMENT}${NC}"
echo -e "${BOLD}   Base URL: ${BASE_URL}${NC}"
echo -e "${BOLD}   Timestamp: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BOLD}================================================================${NC}"
echo ""

# ── Port-forward setup (prod) ─────────────────────────────────────────────────
if [[ "$USE_PORT_FORWARD" == "true" ]]; then
  setup_port_forwards
  trap cleanup_port_forwards EXIT
fi

# ── Check each service ────────────────────────────────────────────────────────
log_info "Checking services..."
echo ""

for svc in "${SERVICE_NAMES[@]}"; do
  PATH_SUFFIX="${SERVICE_PATHS[$svc]}"

  if [[ "$USE_PORT_FORWARD" == "true" && "$svc" != "api-gateway" ]]; then
    LOCAL_PORT="${SERVICE_LOCAL_PORTS[$svc]}"
    URL="http://localhost:${LOCAL_PORT}/health"
  else
    URL="${BASE_URL}${PATH_SUFFIX}"
  fi

  check_service "$svc" "$URL"

  STATUS="${RESULT_STATUS[$svc]}"
  if [[ "$STATUS" == "HEALTHY" ]]; then
    echo -e "  ${GREEN}✓${NC} ${BOLD}${svc}${NC}"
  else
    echo -e "  ${RED}✗${NC} ${BOLD}${svc}${NC} (HTTP ${RESULT_HTTP_CODE[$svc]})"
  fi
done

# ── Check database connectivity ───────────────────────────────────────────────
echo ""
log_info "Checking infrastructure..."

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-ecommerce}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"

DB_START=$(date +%s%3N)
if PGPASSWORD="$DB_PASSWORD" pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -q 2>/dev/null; then
  DB_END=$(date +%s%3N)
  DB_TIME=$((DB_END - DB_START))
  RESULT_STATUS["postgres"]="HEALTHY"
  RESULT_TIME["postgres"]="${DB_TIME}ms"
  RESULT_VERSION["postgres"]="15"
  echo -e "  ${GREEN}✓${NC} ${BOLD}postgres${NC}"
else
  RESULT_STATUS["postgres"]="UNHEALTHY"
  RESULT_TIME["postgres"]="N/A"
  RESULT_VERSION["postgres"]="-"
  echo -e "  ${RED}✗${NC} ${BOLD}postgres${NC} (connection refused)"
  OVERALL_EXIT=1
fi

REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"

REDIS_START=$(date +%s%3N)
if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping 2>/dev/null | grep -q PONG; then
  REDIS_END=$(date +%s%3N)
  REDIS_TIME=$((REDIS_END - REDIS_START))
  RESULT_STATUS["redis"]="HEALTHY"
  RESULT_TIME["redis"]="${REDIS_TIME}ms"
  RESULT_VERSION["redis"]="7"
  echo -e "  ${GREEN}✓${NC} ${BOLD}redis${NC}"
else
  RESULT_STATUS["redis"]="UNHEALTHY"
  RESULT_TIME["redis"]="N/A"
  RESULT_VERSION["redis"]="-"
  echo -e "  ${RED}✗${NC} ${BOLD}redis${NC} (connection refused)"
  OVERALL_EXIT=1
fi

# ── Summary table ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}================================================================${NC}"
echo -e "${BOLD}   Health Check Summary${NC}"
echo -e "${BOLD}================================================================${NC}"
printf "  ${BOLD}%-22s %-12s %-14s %-10s${NC}\n" "SERVICE" "STATUS" "RESPONSE TIME" "VERSION"
echo "  ─────────────────────────────────────────────────────────"

ALL_SERVICES=("${SERVICE_NAMES[@]}" "postgres" "redis")
for svc in "${ALL_SERVICES[@]}"; do
  STATUS="${RESULT_STATUS[$svc]:-UNKNOWN}"
  TIME_VAL="${RESULT_TIME[$svc]:-N/A}"
  VERSION="${RESULT_VERSION[$svc]:--}"

  if [[ "$STATUS" == "HEALTHY" ]]; then
    STATUS_COL="${GREEN}HEALTHY${NC}"
  else
    STATUS_COL="${RED}UNHEALTHY${NC}"
  fi

  printf "  %-22s " "$svc"
  printf "${STATUS_COL}"
  printf "     %-14s %-10s\n" "$TIME_VAL" "$VERSION"
done

echo ""
if [[ $OVERALL_EXIT -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}All services are healthy!${NC}"
else
  echo -e "${RED}${BOLD}One or more services are unhealthy!${NC}"
fi
echo -e "${BOLD}================================================================${NC}"
echo ""

exit $OVERALL_EXIT
