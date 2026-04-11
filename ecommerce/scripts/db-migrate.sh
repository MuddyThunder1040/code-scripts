#!/usr/bin/env bash
# =============================================================================
# db-migrate.sh  —  Database migration manager for ShopCloud
# Usage: ./db-migrate.sh [up|down|status] [migration_name]
# =============================================================================
set -euo pipefail

# ── Colour codes ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Database config (override via env) ───────────────────────────────────────
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-ecommerce}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"

# ── Helper functions ──────────────────────────────────────────────────────────
log_info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }

die() {
  log_error "$*"
  exit 1
}

run_sql() {
  PGPASSWORD="$DB_PASSWORD" psql \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -c "$1" \
    --quiet 2>&1
}

run_sql_output() {
  PGPASSWORD="$DB_PASSWORD" psql \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -c "$1" 2>&1
}

# ── Ensure migrations table exists ────────────────────────────────────────────
ensure_migrations_table() {
  run_sql "
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id           SERIAL PRIMARY KEY,
      name         VARCHAR(255) UNIQUE NOT NULL,
      applied_at   TIMESTAMP DEFAULT NOW(),
      checksum     VARCHAR(64),
      direction    VARCHAR(10) DEFAULT 'up'
    );
  " || die "Failed to create migrations table."
  log_info "Migrations table ready."
}

# ── Check if migration already applied ───────────────────────────────────────
is_applied() {
  local name="$1"
  COUNT=$(PGPASSWORD="$DB_PASSWORD" psql \
    -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -t -c "SELECT COUNT(*) FROM schema_migrations WHERE name='${name}' AND direction='up';" \
    2>/dev/null | tr -d ' ')
  [[ "$COUNT" -gt 0 ]]
}

# ── Record migration ──────────────────────────────────────────────────────────
record_migration() {
  local name="$1"
  local direction="$2"
  if [[ "$direction" == "up" ]]; then
    run_sql "INSERT INTO schema_migrations (name, direction) VALUES ('${name}', 'up') ON CONFLICT (name) DO UPDATE SET applied_at=NOW(), direction='up';" || true
  else
    run_sql "DELETE FROM schema_migrations WHERE name='${name}';" || true
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# MIGRATION DEFINITIONS
# Add new migrations here as functions named: migrate_<name>_up / migrate_<name>_down
# =============================================================================

# ── Migration: add_product_rating ─────────────────────────────────────────────
migrate_add_product_rating_up() {
  log_info "Applying migration: add_product_rating (UP)"
  run_sql "
    ALTER TABLE products
      ADD COLUMN IF NOT EXISTS rating       DECIMAL(3,2) DEFAULT 0.0,
      ADD COLUMN IF NOT EXISTS review_count INTEGER      DEFAULT 0;
  "
  run_sql "
    UPDATE products SET rating = ROUND((3.5 + random() * 1.5)::numeric, 2),
                        review_count = FLOOR(100 + random() * 5000)::integer;
  "
  run_sql "CREATE INDEX IF NOT EXISTS idx_products_rating ON products(rating DESC);"
  log_success "Migration 'add_product_rating' applied."
}

migrate_add_product_rating_down() {
  log_info "Rolling back migration: add_product_rating (DOWN)"
  run_sql "DROP INDEX IF EXISTS idx_products_rating;"
  run_sql "
    ALTER TABLE products
      DROP COLUMN IF EXISTS rating,
      DROP COLUMN IF EXISTS review_count;
  "
  log_success "Migration 'add_product_rating' rolled back."
}

# ── Migration: add_user_address ───────────────────────────────────────────────
migrate_add_user_address_up() {
  log_info "Applying migration: add_user_address (UP)"
  run_sql "
    ALTER TABLE users
      ADD COLUMN IF NOT EXISTS address_line1 VARCHAR(255),
      ADD COLUMN IF NOT EXISTS address_line2 VARCHAR(255),
      ADD COLUMN IF NOT EXISTS city          VARCHAR(100),
      ADD COLUMN IF NOT EXISTS country       VARCHAR(100) DEFAULT 'US',
      ADD COLUMN IF NOT EXISTS postal_code   VARCHAR(20);
  "
  log_success "Migration 'add_user_address' applied."
}

migrate_add_user_address_down() {
  log_info "Rolling back migration: add_user_address (DOWN)"
  run_sql "
    ALTER TABLE users
      DROP COLUMN IF EXISTS address_line1,
      DROP COLUMN IF EXISTS address_line2,
      DROP COLUMN IF EXISTS city,
      DROP COLUMN IF EXISTS country,
      DROP COLUMN IF EXISTS postal_code;
  "
  log_success "Migration 'add_user_address' rolled back."
}

# ── Migration: add_order_shipping ─────────────────────────────────────────────
migrate_add_order_shipping_up() {
  log_info "Applying migration: add_order_shipping (UP)"
  run_sql "
    ALTER TABLE orders
      ADD COLUMN IF NOT EXISTS shipping_address VARCHAR(500),
      ADD COLUMN IF NOT EXISTS tracking_number  VARCHAR(100),
      ADD COLUMN IF NOT EXISTS shipped_at       TIMESTAMP,
      ADD COLUMN IF NOT EXISTS delivered_at     TIMESTAMP;
  "
  log_success "Migration 'add_order_shipping' applied."
}

migrate_add_order_shipping_down() {
  log_info "Rolling back migration: add_order_shipping (DOWN)"
  run_sql "
    ALTER TABLE orders
      DROP COLUMN IF EXISTS shipping_address,
      DROP COLUMN IF EXISTS tracking_number,
      DROP COLUMN IF EXISTS shipped_at,
      DROP COLUMN IF EXISTS delivered_at;
  "
  log_success "Migration 'add_order_shipping' rolled back."
}

# ── Registry of all migrations (in order) ────────────────────────────────────
ALL_MIGRATIONS=(
  "add_product_rating"
  "add_user_address"
  "add_order_shipping"
)

# =============================================================================
# COMMAND HANDLERS
# =============================================================================

cmd_status() {
  log_info "Database: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
  echo ""
  echo -e "${BOLD}Migration Status:${NC}"
  printf "  %-30s %-10s %s\n" "NAME" "STATUS" "APPLIED AT"
  echo "  ─────────────────────────────────────────────────────"

  for migration in "${ALL_MIGRATIONS[@]}"; do
    if is_applied "$migration"; then
      APPLIED_AT=$(PGPASSWORD="$DB_PASSWORD" psql \
        -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -t -c "SELECT to_char(applied_at, 'YYYY-MM-DD HH24:MI:SS') FROM schema_migrations WHERE name='${migration}';" \
        2>/dev/null | tr -d ' ')
      printf "  ${GREEN}%-30s %-10s %s${NC}\n" "$migration" "APPLIED" "$APPLIED_AT"
    else
      printf "  ${YELLOW}%-30s %-10s %s${NC}\n" "$migration" "PENDING" "-"
    fi
  done
  echo ""
}

cmd_up() {
  local target="${1:-}"
  local applied_count=0

  if [[ -n "$target" ]]; then
    # Apply single named migration
    if ! declare -f "migrate_${target}_up" > /dev/null; then
      die "Unknown migration: '${target}'. Available: ${ALL_MIGRATIONS[*]}"
    fi
    if is_applied "$target"; then
      log_warn "Migration '${target}' is already applied."
      return
    fi
    "migrate_${target}_up"
    record_migration "$target" "up"
    applied_count=$((applied_count + 1))
  else
    # Apply all pending migrations
    for migration in "${ALL_MIGRATIONS[@]}"; do
      if is_applied "$migration"; then
        log_info "Skipping '${migration}' (already applied)."
      else
        "migrate_${migration}_up"
        record_migration "$migration" "up"
        applied_count=$((applied_count + 1))
      fi
    done
  fi

  if [[ $applied_count -eq 0 ]]; then
    log_info "No pending migrations."
  else
    log_success "Applied ${applied_count} migration(s)."
  fi
}

cmd_down() {
  local target="${1:-}"

  if [[ -z "$target" ]]; then
    # Roll back the last applied migration
    LAST=$(PGPASSWORD="$DB_PASSWORD" psql \
      -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
      -t -c "SELECT name FROM schema_migrations WHERE direction='up' ORDER BY applied_at DESC LIMIT 1;" \
      2>/dev/null | tr -d ' ')
    if [[ -z "$LAST" ]]; then
      log_warn "No applied migrations to roll back."
      return
    fi
    target="$LAST"
  fi

  if ! declare -f "migrate_${target}_down" > /dev/null; then
    die "Unknown migration: '${target}'"
  fi

  if ! is_applied "$target"; then
    log_warn "Migration '${target}' is not currently applied."
    return
  fi

  "migrate_${target}_down"
  record_migration "$target" "down"
  log_success "Rolled back migration: '${target}'"
}

# =============================================================================
# MAIN
# =============================================================================

COMMAND="${1:-status}"
MIGRATION_NAME="${2:-}"

echo ""
echo -e "${BOLD}ShopCloud DB Migration Tool${NC}"
echo -e "  Host: ${BOLD}${DB_HOST}:${DB_PORT}${NC}  Database: ${BOLD}${DB_NAME}${NC}"
echo ""

# Verify database connectivity
log_info "Checking database connectivity..."
if ! PGPASSWORD="$DB_PASSWORD" pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -q 2>/dev/null; then
  die "Cannot connect to database at ${DB_HOST}:${DB_PORT}. Check DB_HOST, DB_PORT, DB_USER, DB_PASSWORD."
fi
log_success "Database connection OK"

ensure_migrations_table

case "$COMMAND" in
  up)
    cmd_up "$MIGRATION_NAME"
    ;;
  down)
    cmd_down "$MIGRATION_NAME"
    ;;
  status)
    cmd_status
    ;;
  *)
    die "Unknown command '${COMMAND}'. Use: up | down | status"
    ;;
esac
