include .env
export

ODOO_MODE ?= maintenance

# Compose files — base + mode-specific override
COMPOSE_FILES := -f docker-compose.yml -f docker-compose.$(ODOO_MODE).yml

# Mode-specific variables
ifeq ($(ODOO_MODE),upgrade)
ODOO_BIN      := /opt/odoo-src/odoo/odoo-bin
ODOO_CONF     := /etc/odoo/odoo.upgrade.conf
BUILD_VERSION := $(ODOO_TARGET_VERSION)
else
ODOO_BIN      := /mnt/reference/odoo/odoo-bin
ODOO_CONF     := /etc/odoo/odoo.conf
BUILD_VERSION := $(ODOO_VERSION)
endif

.PHONY: start stop restart restart-all logs shell ps init restore update test test-tags test-file build destroy fetch-all check-env check-image check-worktrees list-worktrees help

check-env: ## Validate required .env variables for the active ODOO_MODE
	@ok=1; \
	_fail() { printf "  \033[31mError: %s is not set in .env\033[0m\n" "$$1"; ok=0; }; \
	[ -n "$(ODOO_DB_NAME)" ]        || _fail ODOO_DB_NAME; \
	[ -n "$(CUSTOMER_REPO)" ]       || _fail CUSTOMER_REPO; \
	[ -n "$(ODOO_UPGRADE_PATH)" ]   || _fail ODOO_UPGRADE_PATH; \
	[ -n "$(ODOO_VAULT_PATH)" ]     || _fail ODOO_VAULT_PATH; \
	[ -n "$(ODOO_WORKTREE_PATH)" ]  || _fail ODOO_WORKTREE_PATH; \
	if [ "$(ODOO_MODE)" = "upgrade" ]; then \
		[ -n "$(ODOO_SOURCE_VERSION)" ] || _fail ODOO_SOURCE_VERSION; \
		[ -n "$(ODOO_TARGET_VERSION)" ] || _fail ODOO_TARGET_VERSION; \
	else \
		[ -n "$(ODOO_VERSION)" ] || _fail ODOO_VERSION; \
	fi; \
	[ "$$ok" = "1" ] || { echo ""; echo "  Fix the above before running make."; echo ""; exit 1; }

check-image: ## Verify the Docker image exists for the active version
	@if ! docker image inspect odoo-dev:$(BUILD_VERSION) > /dev/null 2>&1; then \
		echo ""; \
		echo "  \033[31mError: image odoo-dev:$(BUILD_VERSION) not found.\033[0m"; \
		echo "  Run: make build"; \
		echo ""; \
		exit 1; \
	fi

check-worktrees:
	@if [ "$(ODOO_MODE)" = "upgrade" ]; then \
		_target=$$(eval echo "$(ODOO_WORKTREE_PATH)/$(ODOO_TARGET_VERSION)"); \
		if [ ! -d "$$_target" ]; then \
			echo ""; \
			echo "  \033[31mError: worktree not found for ODOO_TARGET_VERSION=$(ODOO_TARGET_VERSION)\033[0m"; \
			echo "  Run: bash worktree.sh add $(ODOO_TARGET_VERSION)"; \
			echo ""; \
			exit 1; \
		fi; \
		_source=$$(eval echo "$(ODOO_WORKTREE_PATH)/$(ODOO_SOURCE_VERSION)"); \
		if [ ! -d "$$_source" ]; then \
			echo ""; \
			echo "  \033[31mError: worktree not found for ODOO_SOURCE_VERSION=$(ODOO_SOURCE_VERSION)\033[0m"; \
			echo "  Run: bash worktree.sh add $(ODOO_SOURCE_VERSION)"; \
			echo ""; \
			exit 1; \
		fi; \
	else \
		_version=$$(eval echo "$(ODOO_WORKTREE_PATH)/$(ODOO_VERSION)"); \
		if [ ! -d "$$_version" ]; then \
			echo ""; \
			echo "  \033[31mError: worktree not found for ODOO_VERSION=$(ODOO_VERSION)\033[0m"; \
			echo "  Run: bash worktree.sh add $(ODOO_VERSION)"; \
			echo ""; \
			exit 1; \
		fi; \
	fi

start: check-env check-worktrees check-image ## Start the environment
	docker compose $(COMPOSE_FILES) up -d
	@echo ""
	@echo "  \033[32m✓ Environment started → http://localhost:$${ODOO_PORT:-8069}\033[0m"
	@echo "  Run 'make logs' in a new terminal to follow the Odoo startup."
	@echo ""

stop: ## Stop the environment
	docker compose $(COMPOSE_FILES) --profile pgadmin down

restart: ## Restart the Odoo server (keeps the database running)
	docker compose $(COMPOSE_FILES) restart web

restart-all: stop start ## Restart the entire stack (Odoo + database)

logs: ## Stream Odoo server logs
	docker compose $(COMPOSE_FILES) logs -f web

shell: ## Open a shell inside the Odoo container
	docker compose $(COMPOSE_FILES) exec web bash

ps: ## Show container status
	docker compose $(COMPOSE_FILES) ps

pgadmin: ## Start pgAdmin4 at http://localhost:5050
	@echo ""
	@echo "  Waiting for pgAdmin to be ready..."
	@docker compose $(COMPOSE_FILES) --profile pgadmin up -d --wait \
		&& echo "  \033[32m✓ pgAdmin is ready → http://localhost:$${PGADMIN_PORT:-5050}\033[0m" \
		|| true
	@echo ""

init: check-worktrees ## Initialize a fresh database with the base module
	@echo ""
	@echo "  \033[33mWARNING\033[0m: This will drop and recreate the database '$(ODOO_DB_NAME)'."
	@echo ""
	@read -rp "  Are you sure? [y/N] " confirm; \
	[ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || { echo "  Aborted."; exit 1; }
	@echo ""
	@docker compose $(COMPOSE_FILES) stop web > /dev/null 2>&1; true
	@echo "  Starting database service..."
	@docker compose $(COMPOSE_FILES) up -d --wait db
	@echo "  Dropping existing database ($(ODOO_DB_NAME))..."
	@docker compose $(COMPOSE_FILES) exec db dropdb -U odoo --if-exists $(ODOO_DB_NAME) > /dev/null 2>&1
	@echo "  Creating fresh database ($(ODOO_DB_NAME))..."
	@docker compose $(COMPOSE_FILES) exec db createdb -U odoo $(ODOO_DB_NAME) > /dev/null 2>&1
	@echo "  Installing base module (this may take a while)..."
	@docker compose $(COMPOSE_FILES) run --rm --no-deps web \
		python3 $(ODOO_BIN) \
		--config $(ODOO_CONF) \
		-d $(ODOO_DB_NAME) \
		-i base \
		--stop-after-init
	@echo ""
	@echo "  \033[32m✓ Database initialized. Run 'make start' to launch Odoo.\033[0m"
	@echo ""

restore: ## Restore a database. Usage: make restore dump=file.dump
	./restore.sh dumps/$(dump)

update: check-worktrees ## Update Odoo modules. Usage: make update modules=mod1,mod2
	docker compose $(COMPOSE_FILES) exec web python $(ODOO_BIN) \
		-c $(ODOO_CONF) \
		-d $(ODOO_DB_NAME) \
		-u $(modules) \
		--stop-after-init

test: check-worktrees ## Run tests for modules. Usage: make test modules=sale,account
	docker compose $(COMPOSE_FILES) exec web python $(ODOO_BIN) \
		-c $(ODOO_CONF) \
		-d $(ODOO_DB_NAME) \
		-u $(modules) \
		--test-enable \
		--stop-after-init

test-tags: check-worktrees ## Run tests by tag. Usage: make test-tags tags=/module:Class.method
	docker compose $(COMPOSE_FILES) exec web python $(ODOO_BIN) \
		-c $(ODOO_CONF) \
		-d $(ODOO_DB_NAME) \
		--test-tags $(tags) \
		--stop-after-init

test-file: check-worktrees ## Run tests from a file. Usage: make test-file file=/mnt/extra-addons/module/tests/test_x.py
	docker compose $(COMPOSE_FILES) exec web python $(ODOO_BIN) \
		-c $(ODOO_CONF) \
		-d $(ODOO_DB_NAME) \
		--test-file $(file) \
		--stop-after-init

destroy: stop ## Remove all containers, networks and volumes (deletes the database)
	@echo ""
	@echo "  \033[33mWARNING\033[0m: This will remove all containers, networks and volumes."
	@echo "  The database '$(ODOO_DB_NAME)' will be permanently deleted."
	@echo ""
	@read -p "  Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] \
		&& docker compose $(COMPOSE_FILES) down -v \
		|| echo "Aborted."
	@echo ""

fetch-all: ## Fetch latest refs for all vault repos (odoo, enterprise, design-themes)
	@echo ""
	@for repo in odoo enterprise design-themes; do \
		echo "  Fetching $$repo..."; \
		git -C $(ODOO_VAULT_PATH)/$$repo.git fetch --prune origin; \
	done
	@echo ""

build: ## Build the Docker image for the active version
	docker build \
		-t odoo-dev:$(BUILD_VERSION) \
		$(ODOO_WORKTREE_PATH)/$(BUILD_VERSION)

list-worktrees: ## List all available worktrees
	@_path=$$(eval echo "$(ODOO_WORKTREE_PATH)"); \
	echo ""; \
	echo "  Available worktrees in $$_path:"; \
	echo ""; \
	if [ ! -d "$$_path" ]; then \
		echo "  \033[31mDirectory not found: $$_path\033[0m"; \
	else \
		for dir in "$$_path"/*/; do \
			version=$$(basename "$$dir"); \
			if [ "$(ODOO_MODE)" = "upgrade" ]; then \
				if [ "$$version" = "$(ODOO_TARGET_VERSION)" ]; then \
					echo "  \033[32m● $$version\033[0m  (target)"; \
				elif [ "$$version" = "$(ODOO_SOURCE_VERSION)" ]; then \
					echo "  \033[36m● $$version\033[0m  (source)"; \
				else \
					echo "  \033[90m○ $$version\033[0m"; \
				fi; \
			else \
				if [ "$$version" = "$(ODOO_VERSION)" ]; then \
					echo "  \033[32m● $$version\033[0m  (active)"; \
				else \
					echo "  \033[90m○ $$version\033[0m"; \
				fi; \
			fi; \
		done; \
	fi
	@echo ""

help: ## Show this help message
	@echo ""
	@echo "Usage: make <command> [options]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make restore dump=client_prod.dump"
	@echo "  make update modules=sale,account"
	@echo "  make build"
	@echo ""
