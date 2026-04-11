#!/usr/bin/env bash
# =============================================================================
# load-test.sh  —  Basic load test for ShopCloud using curl
# Usage: ./load-test.sh [--requests N] [--concurrent N] [--url BASE_URL]
# =============================================================================
set -euo pipefail

# ── Colour codes ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Defaults ──────────────────────────────────────────────────────────────────
TOTAL_REQUESTS=100
CONCURRENT=10
BASE_URL="http://localhost"

# ── Parse arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --requests|-n)  TOTAL_REQUESTS="$2"; shift 2 ;;
    --concurrent|-c) CONCURRENT="$2";   shift 2 ;;
    --url|-u)       BASE_URL="$2";       shift 2 ;;
    --help|-h)
      echo "Usage: $0 [--requests N] [--concurrent C] [--url BASE_URL]"
      echo ""
      echo "  --requests N    Total number of requests per endpoint (default: 100)"
      echo "  --concurrent C  Max concurrent requests (default: 10)"
      echo "  --url URL       Base URL (default: http://localhost)"
      echo ""
      echo "  Example: $0 --requests 200 --concurrent 20 --url http://localhost:8080"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# ── Temp directory for timing results ────────────────────────────────────────
TMPDIR_LT=$(mktemp -d /tmp/shopcloud-loadtest.XXXXXX)
trap 'rm -rf "$TMPDIR_LT"' EXIT

# ── Helpers ───────────────────────────────────────────────────────────────────
log_info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_step()  { echo -e "\n${BOLD}${CYAN}==> $*${NC}"; }

calc_stats() {
  local results_file="$1"
  if [[ ! -f "$results_file" ]]; then
    echo "0 0 0 0"
    return
  fi
  python3 - <<EOF
import sys
times = []
errors = 0
with open("$results_file") as f:
    for line in f:
        line = line.strip()
        if line.startswith("ERR"):
            errors += 1
        else:
            try:
                times.append(float(line))
            except:
                errors += 1

if times:
    avg = sum(times) / len(times)
    mn  = min(times)
    mx  = max(times)
    p99 = sorted(times)[int(len(times)*0.99)-1] if len(times) > 1 else mx
    total = len(times) + errors
    err_rate = errors / total * 100 if total else 0
    print(f"{avg:.0f} {mn:.0f} {mx:.0f} {p99:.0f} {len(times)} {errors} {err_rate:.1f}")
else:
    print("0 0 0 0 0 $errors 100")
EOF
}

# ── Core load test function ───────────────────────────────────────────────────
run_load_test() {
  local test_name="$1"
  local method="$2"
  local url="$3"
  local body="${4:-}"
  local results_file="${TMPDIR_LT}/${test_name// /_}.txt"

  echo -e "  ${YELLOW}Testing:${NC} ${BOLD}${test_name}${NC}"
  echo -e "  ${YELLOW}URL:${NC}     ${method} ${url}"
  echo -e "  ${YELLOW}Load:${NC}    ${TOTAL_REQUESTS} requests, ${CONCURRENT} concurrent"
  echo ""

  rm -f "$results_file"
  touch "$results_file"

  REQUESTS_DONE=0
  ACTIVE_JOBS=0
  START_EPOCH=$(date +%s%3N)

  for ((i=1; i<=TOTAL_REQUESTS; i++)); do
    (
      if [[ "$method" == "POST" && -n "$body" ]]; then
        RESULT=$(curl -s -o /dev/null \
          -w "%{time_total_ms}" \
          --max-time 15 \
          --connect-timeout 5 \
          -X POST \
          -H "Content-Type: application/json" \
          -d "$body" \
          "$url" 2>/dev/null || echo "ERR")
      else
        RESULT=$(curl -s -o /dev/null \
          -w "%{time_total_ms}" \
          --max-time 15 \
          --connect-timeout 5 \
          "$url" 2>/dev/null || echo "ERR")
      fi
      echo "$RESULT" >> "$results_file"
    ) &

    ACTIVE_JOBS=$((ACTIVE_JOBS + 1))
    if [[ $ACTIVE_JOBS -ge $CONCURRENT ]]; then
      wait
      ACTIVE_JOBS=0
    fi

    REQUESTS_DONE=$((REQUESTS_DONE + 1))
    if (( REQUESTS_DONE % 20 == 0 )); then
      echo -ne "  Progress: ${REQUESTS_DONE}/${TOTAL_REQUESTS}\r"
    fi
  done
  wait

  END_EPOCH=$(date +%s%3N)
  TOTAL_MS=$((END_EPOCH - START_EPOCH))
  TOTAL_S=$(echo "scale=2; $TOTAL_MS / 1000" | bc)
  RPS=$(echo "scale=1; $TOTAL_REQUESTS / $TOTAL_S" | bc 2>/dev/null || echo "N/A")

  read -r AVG_MS MIN_MS MAX_MS P99_MS SUCCESS_COUNT ERROR_COUNT ERR_RATE < <(calc_stats "$results_file")

  echo -ne "                                    \r"

  printf "  %-18s %s\n" "Requests/sec:" "${RPS} req/s"
  printf "  %-18s %s\n" "Avg response:" "${AVG_MS}ms"
  printf "  %-18s %s\n" "Min response:" "${MIN_MS}ms"
  printf "  %-18s %s\n" "Max response:" "${MAX_MS}ms"
  printf "  %-18s %s\n" "P99 response:" "${P99_MS}ms"
  printf "  %-18s %s\n" "Successful:" "${SUCCESS_COUNT}/${TOTAL_REQUESTS}"

  if [[ "$ERROR_COUNT" -gt 0 ]]; then
    printf "  ${RED}%-18s %s${NC}\n" "Errors:" "${ERROR_COUNT} (${ERR_RATE}%)"
  else
    printf "  ${GREEN}%-18s %s${NC}\n" "Errors:" "0"
  fi

  # Store summary for final table
  echo "${test_name}|${RPS}|${AVG_MS}|${P99_MS}|${SUCCESS_COUNT}/${TOTAL_REQUESTS}|${ERR_RATE}%" >> "${TMPDIR_LT}/summary.txt"
}

# =============================================================================
# MAIN
# =============================================================================

echo ""
echo -e "${BOLD}================================================================${NC}"
echo -e "${BOLD}   ShopCloud Load Test${NC}"
echo -e "${BOLD}   Base URL  : ${BASE_URL}${NC}"
echo -e "${BOLD}   Requests  : ${TOTAL_REQUESTS} per endpoint${NC}"
echo -e "${BOLD}   Concurrent: ${CONCURRENT}${NC}"
echo -e "${BOLD}   Started   : $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BOLD}================================================================${NC}"

# ── Test 1: GET /api/products ─────────────────────────────────────────────────
log_step "Test 1: GET Products (read-heavy endpoint)"
run_load_test "GET /api/products" "GET" "${BASE_URL}/api/products/"

# ── Test 2: GET /api/users/1 ──────────────────────────────────────────────────
log_step "Test 2: GET User by ID"
run_load_test "GET /api/users/1" "GET" "${BASE_URL}/api/users/1"

# ── Test 3: GET /api/health ───────────────────────────────────────────────────
log_step "Test 3: GET API Gateway Health"
run_load_test "GET /api/health" "GET" "${BASE_URL}/api/health"

# ── Test 4: POST /api/cart (write endpoint) ────────────────────────────────────
log_step "Test 4: POST Cart Add Item (write endpoint)"
CART_BODY='{"product_id": 1, "quantity": 1, "price": 9.99, "name": "Load Test Product"}'
run_load_test "POST /api/cart" "POST" "${BASE_URL}/api/cart/999/items" "$CART_BODY"

# ── Test 5: GET /api/products/1 ──────────────────────────────────────────────
log_step "Test 5: GET Single Product"
run_load_test "GET /api/products/1" "GET" "${BASE_URL}/api/products/1"

# ── Final Summary ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}================================================================${NC}"
echo -e "${BOLD}   Load Test Summary${NC}"
echo -e "${BOLD}================================================================${NC}"
printf "  ${BOLD}%-28s %-12s %-10s %-10s %-16s %-10s${NC}\n" \
  "ENDPOINT" "REQ/SEC" "AVG(ms)" "P99(ms)" "SUCCESS" "ERR RATE"
echo "  ─────────────────────────────────────────────────────────────────────"

if [[ -f "${TMPDIR_LT}/summary.txt" ]]; then
  while IFS='|' read -r name rps avg p99 success errrate; do
    # Colour error rate
    if [[ "$errrate" == "0%" ]]; then
      ERR_COL="${GREEN}${errrate}${NC}"
    else
      ERR_COL="${RED}${errrate}${NC}"
    fi
    printf "  %-28s %-12s %-10s %-10s %-16s " \
      "$name" "$rps" "$avg" "$p99" "$success"
    echo -e "${ERR_COL}"
  done < "${TMPDIR_LT}/summary.txt"
fi

echo ""
echo -e "  ${YELLOW}Note:${NC} High error rates may indicate services need to warm up."
echo -e "  ${YELLOW}Note:${NC} Run this test under load to trigger HPA scaling in Kubernetes."
echo -e "  ${YELLOW}Tip:${NC}  Watch HPA with: kubectl get hpa -n ecommerce-blue -w"
echo ""
echo -e "${BOLD}Load test completed at: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BOLD}================================================================${NC}"
echo ""
