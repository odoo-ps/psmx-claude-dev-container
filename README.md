# Odoo Dev Environment Template

Dockerized development environment for Odoo. Designed for custom module development, upgrades between versions, and client maintenance.

---

## Prerequisites

- Docker Desktop
- Git
- The following directory structure on your machine:

```
~/Odoo/
├── Worktrees/          ← Odoo source code (git worktrees)
│   ├── 16.0/
│   ├── 17.0/
│   ├── 18.0/
│   └── 19.0/
├── Repos/              ← Customer module repositories
├── Dumps/              ← Database dumps (.sql / .dump)
└── Upgrade/            ← odoo-upgrade-util
```

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

**3. Build the Docker image**

```bash
make build
```

**4. Start the environment**

```bash
make start
```

Odoo will be available at http://localhost:8069

---

## Available commands

```
make start                          Start the environment
make stop                           Stop the environment
make restart                        Restart the environment
make logs                           Stream Odoo server logs
make shell                          Open a shell inside the Odoo container
make ps                             Show container status
make build                          Build the Docker image for the target version
make restore dump=file.dump         Restore a database from ~/Odoo/Dumps/
make upgrade modules=mod1,mod2      Upgrade Odoo modules
make pgadmin                        Start pgAdmin4 at http://localhost:5050
```

---

## Debugging

The environment runs `debugpy` on port `5678`. To attach the debugger:

**1. Open the project folder in VS Code**

```bash
code ~/Odoo/Customers/acme
```

**2. Reopen in container**

When prompted by the Dev Containers extension, click **Reopen in Container**.
If the prompt does not appear, open the Command Palette (`Cmd+Shift+P`) and run:
`Dev Containers: Reopen in Container`

This connects VS Code to the running Odoo container. All workspace paths
(`/opt/odoo-src`, `/mnt/reference`, `/mnt/extra-addons`) resolve from inside
the container — the workspace file will not work without this step.

**3. Open the workspace file**

Once inside the container, open `odoo-dev.code-workspace` to load all folders.
Then use the **Docker: Odoo Debug** launch configuration to attach the debugger.

> **Running multiple clients simultaneously?**
> Change `ODOO_PORT` and `ODOO_DEBUG_PORT` in each client's `.env` to avoid
> port conflicts (e.g. `8069`/`5678` for one, `8070`/`5679` for another).
> Each VS Code window connects to its own container independently.

---

## Hot reload

To enable hot reload during development, add `--dev=all` to `ODOO_EXTRA_ARGS` in your `.env`:

```
ODOO_EXTRA_ARGS=--dev=all
```

---

## Upgrade workflow

The environment mounts two versions of Odoo simultaneously:

- **Target** (`/opt/odoo-src`) — the version you are upgrading to
- **Source** (`/mnt/reference`) — the version you are upgrading from, read-only

Both are visible in the VS Code workspace for side-by-side comparison without switching branches.
