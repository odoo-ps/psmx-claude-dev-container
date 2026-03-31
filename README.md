# Odoo Dev Environment Template

Dockerized development environment for Odoo. Designed for custom module development, upgrades between versions, and client maintenance.

---

## Prerequisites

- Docker Desktop
- Git
- SSH access to GitHub configured
- Directory structure created by `setup.sh` (see below)

---

## First-time machine setup

Run `setup.sh` once on a new machine. It creates the `~/Odoo/` directory structure,
clones Odoo source repos as bare repositories, creates worktrees for the versions
you choose, and installs upgrade tools.

```bash
git clone git@github.com:eagf-odoo/odoo-dev-template.git ~/Odoo/Customers/template
cd ~/Odoo/Customers/template
bash setup.sh
```

The script is interactive and safe to re-run — it skips anything that already exists.

---

## Setup

**1. Clone this template for your client**

```bash
git clone git@github.com:eagf-odoo/odoo-dev-template.git ~/Odoo/Customers/acme
cd ~/Odoo/Customers/acme
```

**2. Configure the environment**

```bash
cp .env.example .env
```

Edit `.env` with the values for your client (versions, database name, paths).

> **`ODOO_VAULT_PATH` must be an absolute path.** Use `$HOME/Odoo/.vault` or the
> equivalent — do not use `~`. Docker Compose expands tilde in the source (host)
> path but not in the target (container) path, so `source` and `target` would
> diverge and git worktree pointers would not resolve.

**3. Get the Docker image**

Build locally:
```bash
make build
```

Or pull from DockerHub:
```bash
docker pull your-org/odoo-dev:18.0
docker tag your-org/odoo-dev:18.0 odoo-dev:18.0
```

**4. Start the environment**

```bash
make start
```

Odoo will be available at http://localhost:8069

---

## Further reading

- [REFERENCE.md](REFERENCE.md) — all commands, debugging, testing, worktree management, pgAdmin4
- [WORKFLOWS.md](WORKFLOWS.md) — practical step-by-step scenarios
