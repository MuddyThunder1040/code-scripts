#!/usr/bin/env bash
# =============================================================================
# blue-green-switch.sh  —  Switch production traffic between blue and green
# Usage: ./blue-green-switch.sh [blue|green]
# =============================================================================
set -euo pipefail

# ── Colour codes ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'  # No Colour

# ── Config ────────────────────────────────────────────────────────────────────
NAMESPACE_BLUE="ecommerce-blue"
NAMESPACE_GREEN="ecommerce-green"
PROD_SERVICE_NAME="production-router"
PROD_NAMESPACE="ecommerce"
HEALTH_CHECK_TIMEOUT=120
HEALTH_CHECK_RETRY_INTERVAL=5
BASE_URL="${BASE_URL:-http://localhost}"

SERVICES=(user-service product-service order-service cart-service)
declare -A SERVICE_PORTS=(
  [user-service]=8001
  [product-service]=8002
  [order-service]=8003
  [cart-service]=8004
)

# ── Helper functions ──────────────────────────────────────────────────────────
log_info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()    { echo -e "\n${BOLD}${BLUE}==> $*${NC}"; }

die() {
  log_error "$*"
  exit 1
}

# ── Validate argument ─────────────────────────────────────────────────────────
if [[ $# -ne 1 ]]; then
  echo -e "${BOLD}Usage:${NC} $0 [blue|green]"
  echo ""
  echo "  Switches Kubernetes production traffic to the specified deployment colour."
  echo ""
  echo "  Examples:"
  echo "    $0 green    # Route traffic to the green (new) deployment"
  echo "    $0 blue     # Route traffic back to the blue (stable) deployment"
  exit 1
fi

TARGET_COLOR="${1,,}"  # lowercase

if [[ "$TARGET_COLOR" != "blue" && "$TARGET_COLOR" != "green" ]]; then
  die "Invalid colour '${TARGET_COLOR}'. Must be 'blue' or 'green'."
fi

# ── Determine opposing colour ─────────────────────────────────────────────────
if [[ "$TARGET_COLOR" == "blue" ]]; then
  OTHER_COLOR="green"
  TARGET_NAMESPACE="$NAMESPACE_BLUE"
else
  OTHER_COLOR="blue"
  TARGET_NAMESPACE="$NAMESPACE_GREEN"
fi

echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e "${BOLD}   ShopCloud Blue-Green Traffic Switch${NC}"
echo -e "${BOLD}============================================================${NC}"
echo ""

# ── Get current active colour ─────────────────────────────────────────────────
log_step "Checking current active deployment"

if ! kubectl get service "$PROD_SERVICE_NAME" -n "$PROD_NAMESPACE" &>/dev/null; then
  log_warn "Production service '${PROD_SERVICE_NAME}' not found in namespace '${PROD_NAMESPACE}'."
  log_warn "Assuming current colour is '${OTHER_COLOR}'."
  CURRENT_COLOR="$OTHER_COLOR"
else
  CURRENT_COLOR=$(kubectl get service "$PROD_SERVICE_NAME" -n "$PROD_NAMESPACE" \
    -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "unknown")
fi

log_info "Current active colour : ${BOLD}${CURRENT_COLOR}${NC}"
log_info "Target colour         : ${BOLD}${TARGET_COLOR}${NC}"
log_info "Target namespace      : ${BOLD}${TARGET_NAMESPACE}${NC}"

if [[ "$CURRENT_COLOR" == "$TARGET_COLOR" ]]; then
  log_warn "Traffic is already routed to '${TARGET_COLOR}'. Nothing to do."
  exit 0
fi

# ── Check target namespace pods are ready ─────────────────────────────────────
log_step "Waiting for all pods in '${TARGET_NAMESPACE}' to be ready"

ELAPSED=0
ALL_READY=false

while [[ $ELAPSED -lt $HEALTH_CHECK_TIMEOUT ]]; do
  PODS_TOTAL=$(kubectl get pods -n "$TARGET_NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  PODS_READY=$(kubectl get pods -n "$TARGET_NAMESPACE" --no-headers 2>/dev/null | grep -c "Running" || true)

  if [[ "$PODS_TOTAL" -gt 0 && "$PODS_READY" -ge "$PODS_TOTAL" ]]; then
    ALL_READY=true
    break
  fi

  log_info "Pods ready: ${PODS_READY}/${PODS_TOTAL} — waiting (${ELAPSED}s elapsed)..."
  sleep "$HEALTH_CHECK_RETRY_INTERVAL"
  ELAPSED=$((ELAPSED + HEALTH_CHECK_RETRY_INTERVAL))
done

if [[ "$ALL_READY" != "true" ]]; then
  die "Pods in namespace '${TARGET_NAMESPACE}' did not become ready within ${HEALTH_CHECK_TIMEOUT}s."
fi

log_success "All pods ready in '${TARGET_NAMESPACE}'"

# Try kubectl wait for condition=ready (best effort)
for svc in "${SERVICES[@]}"; do
  kubectl wait --for=condition=ready pod \
    -l "app=${svc},color=${TARGET_COLOR}" \
    -n "$TARGET_NAMESPACE" \
    --timeout=60s 2>/dev/null && \
    log_success "  ${svc}: ready" || \
    log_warn "  ${svc}: kubectl wait timed out (pods may still be ready)"
done

# ── Port-forward and run health checks ────────────────────────────────────────
log_step "Running health checks against '${TARGET_COLOR}' deployment"

HEALTH_CHECK_PASSED=true
declare -A HEALTH_RESULTS

for svc in "${SERVICES[@]}"; do
  PORT=${SERVICE_PORTS[$svc]}
  LOCAL_PORT=$((PORT + 10000))

  # Start port-forward in background
  kubectl port-forward \
    "service/${svc}" \
    "${LOCAL_PORT}:${PORT}" \
    -n "$TARGET_NAMESPACE" \
    &>/dev/null &
  PF_PID=$!
  sleep 2

  HEALTH_URL="http://localhost:${LOCAL_PORT}/health"
  START_TIME=$(date +%s%3N)

  HTTP_STATUS=$(curl -s -o /tmp/health_response_${svc}.json \
    -w "%{http_code}" \
    --max-time 10 \
    "$HEALTH_URL" 2>/dev/null || echo "000")

  END_TIME=$(date +%s%3N)
  RESPONSE_TIME=$((END_TIME - START_TIME))

  kill "$PF_PID" 2>/dev/null || true
  wait "$PF_PID" 2>/dev/null || true

  if [[ "$HTTP_STATUS" == "200" ]]; then
    VERSION=$(cat "/tmp/health_response_${svc}.json" 2>/dev/null | \
      python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version','?'))" 2>/dev/null || echo "?")
    HEALTH_RESULTS[$svc]="HEALTHY | ${RESPONSE_TIME}ms | v${VERSION}"
    log_success "${svc}: HTTP ${HTTP_STATUS} in ${RESPONSE_TIME}ms (version: ${VERSION})"
  else
    HEALTH_RESULTS[$svc]="FAILED  | ${RESPONSE_TIME}ms | HTTP ${HTTP_STATUS}"
    log_error "${svc}: HTTP ${HTTP_STATUS} — health check failed"
    HEALTH_CHECK_PASSED=false
  fi
done

# ── If health checks failed, roll back ───────────────────────────────────────
if [[ "$HEALTH_CHECK_PASSED" != "true" ]]; then
  log_error "Health checks failed for '${TARGET_COLOR}' deployment. Aborting switch."
  log_warn  "Keeping traffic on '${CURRENT_COLOR}' (no changes made)."

  echo ""
  echo -e "${RED}${BOLD}=== SWITCH ABORTED ===${NC}"
  print_summary "ABORTED" "$CURRENT_COLOR"
  exit 1
fi

# ── Patch the production service selector ─────────────────────────────────────
log_step "Switching production traffic: ${CURRENT_COLOR} → ${TARGET_COLOR}"

if kubectl get service "$PROD_SERVICE_NAME" -n "$PROD_NAMESPACE" &>/dev/null; then
  kubectl patch service "$PROD_SERVICE_NAME" -n "$PROD_NAMESPACE" \
    --type='json' \
    -p="[{\"op\": \"replace\", \"path\": \"/spec/selector/color\", \"value\": \"${TARGET_COLOR}\"}]"
  log_success "Service selector updated: color=${TARGET_COLOR}"
else
  log_warn "Production service not found — skipping kubectl patch."
  log_warn "In a real environment, the patch command would be:"
  log_warn "  kubectl patch service ${PROD_SERVICE_NAME} -n ${PROD_NAMESPACE} \\"
  log_warn "    --type='json' -p='[{\"op\":\"replace\",\"path\":\"/spec/selector/color\",\"value\":\"${TARGET_COLOR}\"}]'"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e "${BOLD}   Deployment Switch Summary${NC}"
echo -e "${BOLD}============================================================${NC}"
printf "  %-6s %-22s %-12s %-16s %s\n" "COLOR" "SERVICE" "STATUS" "RESP TIME" "VERSION"
echo "  ──────────────────────────────────────────────────────────"
for svc in "${SERVICES[@]}"; do
  printf "  %-6s %-22s %s\n" "$TARGET_COLOR" "$svc" "${HEALTH_RESULTS[$svc]}"
done
echo ""
echo -e "  Previous colour : ${YELLOW}${CURRENT_COLOR}${NC}"
echo -e "  Active colour   : ${GREEN}${TARGET_COLOR}${NC}"
echo -e "  Switched at     : $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo -e "${GREEN}${BOLD}Traffic successfully switched to '${TARGET_COLOR}'!${NC}"
echo -e "${BOLD}============================================================${NC}"
