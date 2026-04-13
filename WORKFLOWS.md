# Workflow Examples

Practical reference for the most common scenarios when working with this template.

> Throughout this document, `acme` and `honex` are used as placeholder company names
> in examples. Replace them with the actual client name in every command.

---

## 1. Single client — full setup from scratch

```bash
# 1. Clone the template
git clone git@github.com:eagf-odoo/odoo-dev-template.git ~/Odoo/Customers/acme
cd ~/Odoo/Customers/acme

# 2. Clone the client's module repository
git clone git@github.com:acme/acme-addons.git ~/Odoo/Repos/acme-addons

# 3. Configure the environment
cp .env.example .env
# Edit .env — set ODOO_MODE=development, ODOO_VERSION, CUSTOMER_REPO, ODOO_DB_NAME, etc.

# 4. Build the Docker image
#    Skip this step if odoo-dev:<version> was already built on this machine
#    (e.g. another client uses the same Odoo version).
make build

# 5. Place the database dump
cp ~/Downloads/acme_prod.dump ~/Odoo/Dumps/

# 6. Restore the database
make restore dump=acme_prod.dump   # also accepts .sql files
# Or initialize a fresh database instead:
# make reset

# 7. Start the environment
make start
# → waits until Odoo is ready, then prints the URL

# 8. Open VS Code, reopen in container, then open the workspace
code .
# → Command Palette: "Dev Containers: Reopen in Container"
# → Open odoo-dev.code-workspace

# Odoo running at http://localhost:8069 — credentials: admin/admin
```

---

## 2. Two clients simultaneously

Each client needs its own clone of the template with different ports to avoid conflicts.

```bash
# --- Client A: Acme (ports 8069 / 5678) ---
git clone git@github.com:eagf-odoo/odoo-dev-template.git ~/Odoo/Customers/acme
cd ~/Odoo/Customers/acme
cp .env.example .env
# .env — set ODOO_PORT=8069, ODOO_DEBUG_PORT=5678
make start

# --- Client B: Honex (ports 8070 / 5679) ---
git clone git@github.com:eagf-odoo/odoo-dev-template.git ~/Odoo/Customers/honex
cd ~/Odoo/Customers/honex
cp .env.example .env
# .env — set ODOO_PORT=8070, ODOO_DEBUG_PORT=5679
make start
```

Open a separate VS Code window for each client:

```bash
code ~/Odoo/Customers/acme    # → Reopen in Container → workspace
code ~/Odoo/Customers/honex  # → Reopen in Container → workspace
```

Each window connects to its own container independently.

| Client | Odoo | Debugpy |
|--------|------|---------|
| Acme   | http://localhost:8069 | port 5678 |
| Honex | http://localhost:8070 | port 5679 |

**Hardware requirements for this workflow:**

Each client environment (Odoo + PostgreSQL + VS Code Server) consumes approximately 1.5–2 GB of RAM at rest.

| Use case | RAM |
|---|---|
| Single client | 16 GB |
| Two clients simultaneously | 32 GB (16 GB possible but slow) |

On 16 GB machines the recommended approach is to run one client at a time —
`make stop` preserves the database, and `make start` resumes in seconds.

---

## 3. Updating modules

Typical iteration loop when updating modules on an existing client
database — restore, update, inspect, repeat.

```bash
cd ~/Odoo/Customers/acme

# Restore a clean database before each attempt
make restore dump=acme_prod.dump

# Update one or more modules
make update modules=acme_sale

# Update multiple modules at once
make update modules=acme_sale,acme_account,acme_stock

# Watch the logs while the update runs
make logs

# Quick SQL queries against the database
make psql

# ORM interaction (Python REPL with env pre-loaded)
make shell

# Full GUI — schema inspection, query analysis
make pgadmin
# → http://localhost:5050
```

To enable hot reload while fixing Python code between updates:

```bash
# In .env
ODOO_EXTRA_ARGS=--dev=all

make restart
```

---

## 4. Version upgrade workflow

Use this when migrating a client from one Odoo version to another.
Switch `ODOO_MODE=upgrade` in `.env` — the Makefile and Compose files
handle the rest automatically.

```bash
cd ~/Odoo/Customers/acme

# 1. Set upgrade mode in .env
#    ODOO_MODE=upgrade
#    ODOO_SOURCE_VERSION=17.0   ← current client version
#    ODOO_TARGET_VERSION=18.0   ← target version

# 2. Ensure worktrees exist for both versions
make worktree-add VERSION=17.0
make worktree-add VERSION=18.0

# 3. Build the image for the target version (if not already built)
make build

# 4. Restore the pre-upgrade database
make restore dump=acme_pre_upgrade.dump

# 5. Start the environment
make start
# → Odoo runs from /opt/odoo-src (target version)
# → /mnt/reference contains the source version for comparison

# 6. Run the module migration
make update modules=acme_sale

# 7. Iterate: restore clean → migrate → inspect → repeat
make restore dump=acme_pre_upgrade.dump
make update modules=acme_sale
```

In upgrade mode, VS Code workspace exposes both `/opt/odoo-src`
(target) and `/mnt/reference` (source) so you can diff views and
models side by side.

To switch back to development mode, set `ODOO_MODE=development` in
`.env` and run `make restart-all`.

---

## 5. Building the Docker image

Required the first time you use a given Odoo version on this machine.
Subsequent clients on the same version can skip this step — the image
is global to the Docker daemon and shared across all projects.

```bash
cd ~/Odoo/Customers/acme

# Builds odoo-dev:<ODOO_VERSION> from the worktree Dockerfile
make build
```

The image is built from `~/Odoo/Worktrees/<ODOO_VERSION>/Dockerfile`
and tagged as `odoo-dev:<version>` (e.g. `odoo-dev:17.0`).

To build for a specific version without changing your .env:

```bash
ODOO_VERSION=17.0 make build
```

---

## 6. Using a pre-built image from DockerHub

If the images are already published, skip `make build` entirely.

```bash
# Pull the image for the version you need
docker pull your-dockerhub-user/odoo-dev:18.0

# Tag it with the name the template expects
docker tag your-dockerhub-user/odoo-dev:18.0 odoo-dev:18.0

# Start the environment normally
make start
```

> Run `docker pull` from the same terminal session where you will run
> `make start`. Both commands must use the same Docker context — pulling
> in one context and starting in another will cause `make start` to fail.


---

## Quick reference

| Scenario | Key `.env` values to set |
|---|---|
| Single client | Default ports (`8069`, `5678`) |
| Two clients | Different `ODOO_PORT` and `ODOO_DEBUG_PORT` per client |
| Development / bugfix | `ODOO_MODE=development`, `ODOO_VERSION` |
| Version upgrade | `ODOO_MODE=upgrade`, `ODOO_SOURCE_VERSION`, `ODOO_TARGET_VERSION` |
| Hot reload | `ODOO_EXTRA_ARGS=--dev=all` |
| No debugger overhead | `ODOO_DEBUG=false` |
| Fresh database | `make reset` then `make start` |
| Restore from dump | `make restore dump=file.dump` (or `.sql`) then `make start` |
