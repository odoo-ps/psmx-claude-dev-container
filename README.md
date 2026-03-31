# Odoo Dev Environment Template

Dockerized development environment for Odoo. Designed for custom module development, upgrades between versions, and client maintenance.

---

## Prerequisites

- Docker Desktop
- Git
- SSH access to GitHub configured
- The following directory structure on your machine (created automatically by `setup.sh`):

```
~/Odoo/
├── .vault/             ← Bare git repos (shared object store)
├── Worktrees/          ← Odoo source code (git worktrees)
│   ├── 16.0/
│   ├── 17.0/
│   ├── 18.0/
│   └── 19.0/
├── Repos/              ← Customer module repositories
├── Dumps/              ← Database dumps (.sql / .dump)
└── Upgrade/            ← upgrade and upgrade-util
```

> **Important:** The `.vault/` directory must always be located at `~/Odoo/.vault`.
> This path is mounted into the container at its exact host location so that git worktree
> pointers resolve correctly inside the container — required for GitLens to show
> blame and history on Odoo source files.

---

## First-time machine setup

If this is a new machine, run `setup.sh` before anything else. It creates
the directory structure, clones Odoo source repos as bare repositories,
creates worktrees for the versions you choose, and installs upgrade tools.

```bash
git clone git@github.com:eagf-odoo/odoo-dev-template.git ~/Odoo/Customers/template
cd ~/Odoo/Customers/template
bash setup.sh
```

The script is interactive and safe to re-run — it skips anything that already exists.

---

## Managing worktrees

Use `worktree.sh` to add or remove Odoo source worktrees after the initial setup.
This is the recommended way to add new versions — including `saas-*` branches —
without re-running the full `setup.sh`.

**Interactive mode**

```bash
bash worktree.sh
```

Presents a menu to add or remove a worktree.

**Non-interactive mode**

```bash
bash worktree.sh add 18.0
bash worktree.sh add saas-18.4
bash worktree.sh remove 17.0
```

The script fetches the latest refs from the vault before creating a worktree, copies
the appropriate Dockerfile (`legacy` for < 18.0, `modern` for ≥ 18.0 and all `saas-*`),
and registers the worktree removal cleanly with git when deleting.

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

**3. Build the Docker image** _(optional)_

Skip this step if the image is already built or pulled from DockerHub.

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
make restart                        Restart the Odoo server (keeps the database running)
make restart-all                    Restart the entire stack (Odoo + database)
make logs                           Stream Odoo server logs
make shell                          Open a shell inside the Odoo container
make ps                             Show container status
make build                          Build the Docker image for the target version
make restore dump=file.dump         Restore a database from ~/Odoo/Dumps/
make upgrade modules=mod1,mod2      Upgrade Odoo modules
make pgadmin                        Start pgAdmin4 at http://localhost:5050
make destroy                        Remove all containers, networks and volumes (deletes the database)
```

For common day-to-day scenarios, see [common worklflows](WORKFLOWS.md) examples.

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

> **Debugger not working? `Cannot activate 'Python Debugger'` error?**
> Open the Command Palette (`Cmd+Shift+P`) and run `Developer: Reload Window`.
> This reinitializes the extension host and resolves the activation order issue
> between the Python and Debugpy extensions.

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

## pgAdmin4

pgAdmin4 is included as an optional service for database inspection. It is not
started by default — only when explicitly requested.

```bash
make pgadmin
# → http://localhost:5050  (admin@admin.com / admin)
```

### When to use it during an upgrade

**Comparing schemas between versions**
- The most valuable use case. Before and after an upgrade, you can inspect
the real database schema — column types, constraints, indexes — and verify
that the migration scripts transformed the data correctly.

**Debugging SQL errors**
- When a migration fails with a PostgreSQL error, pgAdmin lets you run raw
SQL queries against the database to reproduce and diagnose the problem
without restarting the full upgrade process.

**Analyzing performance issues**
- If Odoo is slow after an upgrade, use the query analysis tools to identify
missing indexes or inefficient queries introduced by the new version.

**Inspecting data after a restore**
- After `make restore`, pgAdmin is useful to quickly verify that the dump was
restored correctly — row counts, field values, related records — before
starting the upgrade iteration.

---

## Upgrade workflow

The environment mounts two versions of Odoo simultaneously:

- **Target** (`/opt/odoo-src`) — the version you are upgrading to
- **Source** (`/mnt/reference`) — the version you are upgrading from, read-only

Both are visible in the VS Code workspace for side-by-side comparison without switching branches.
