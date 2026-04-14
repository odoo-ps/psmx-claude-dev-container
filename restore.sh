#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/helpers.sh"

# --- Load .env ---------------------------------------------------------------
if [ ! -f .env ]; then
    print_error ".env not found — copy .env.example to .env and configure it"
    exit 1
fi
set -a; source .env; set +a

ODOO_MODE="${ODOO_MODE:-development}"
COMPOSE_FILES=(-f docker-compose.yml -f "docker-compose.${ODOO_MODE}.yml")

# --- Validate argument -------------------------------------------------------
FILE="${1:-}"

if [ -z "$FILE" ]; then
    print_error "Usage: make restore dump=<filename>.dump|.sql"
    exit 1
fi

if [[ "$FILE" != *.dump ]] && [[ "$FILE" != *.sql ]]; then
    print_error "Unsupported format '${FILE}'. Use a .dump or .sql file."
    exit 1
fi

# --- Restore -----------------------------------------------------------------
print_info "Stopping Odoo web service..."
docker compose "${COMPOSE_FILES[@]}" stop web >/dev/null 2>&1

print_info "Starting database service..."
docker compose "${COMPOSE_FILES[@]}" up -d --wait db >/dev/null 2>&1

print_info "Dropping existing database ($ODOO_DB_NAME)..."
docker compose "${COMPOSE_FILES[@]}" exec db dropdb -U odoo --if-exists "$ODOO_DB_NAME" >/dev/null 2>&1

print_info "Creating fresh database ($ODOO_DB_NAME)..."
docker compose "${COMPOSE_FILES[@]}" exec db createdb -U odoo "$ODOO_DB_NAME" >/dev/null 2>&1

if [[ "$FILE" == *.dump ]]; then
    run_with_spinner "Restoring ${FILE}..." \
        docker compose "${COMPOSE_FILES[@]}" exec -T db \
            pg_restore -U odoo -d "$ODOO_DB_NAME" -1 "/$FILE" \
        || { print_error "Restore failed — check the dump file."; exit 1; }
else
    run_with_spinner "Restoring ${FILE}..." \
        docker compose "${COMPOSE_FILES[@]}" exec -T db \
            psql -U odoo -d "$ODOO_DB_NAME" -f "/$FILE" -q \
        || { print_error "Restore failed — check the dump file."; exit 1; }
fi

print_info "Resetting admin credentials (login: admin / password: admin)..."
SQL="WITH admin_candidates AS (
    SELECT id, 1 AS priority
    FROM res_users
    WHERE id IN (
        SELECT res_id FROM ir_model_data
        WHERE model = 'res.users' AND (module, name) = ('base', 'user_admin')
    )
    AND active = TRUE

    UNION

    SELECT id, 2 AS priority
    FROM res_users
    WHERE login = 'admin' AND active = TRUE

    UNION

    SELECT id, 3 AS priority
    FROM res_users
    WHERE id IN (
        SELECT uid FROM res_groups_users_rel
        WHERE gid IN (
            SELECT res_id FROM ir_model_data
            WHERE model = 'res.groups' AND (module, name) = ('base', 'group_system')
        )
    )
    AND active = TRUE
)
UPDATE res_users
SET login = 'admin', password = 'admin'
WHERE id = (
    SELECT id FROM admin_candidates
    ORDER BY priority ASC, id ASC
    LIMIT 1
);"
docker compose "${COMPOSE_FILES[@]}" exec db psql -U odoo -d "$ODOO_DB_NAME" -c "$SQL" -q >/dev/null 2>&1

print_info "Starting Odoo..."
docker compose "${COMPOSE_FILES[@]}" start web >/dev/null 2>&1

echo ""
print_ok "Database restored — log in at http://localhost:${ODOO_PORT:-8069}"
echo ""
