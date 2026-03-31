include .env
export

.PHONY: start stop restart restart-all logs shell ps restore upgrade test test-tags test-file build destroy fetch-all check-worktrees help

check-worktrees: ## Validate that target and source worktrees exist before starting
	@if [ ! -d "$(ODOO_WORKTREE_PATH)/$(ODOO_TARGET_VERSION)" ]; then \
		echo ""; \
		echo "  \033[31mError: worktree not found for ODOO_TARGET_VERSION=$(ODOO_TARGET_VERSION)\033[0m"; \
		echo "  Run: bash worktree.sh add $(ODOO_TARGET_VERSION)"; \
		echo ""; \
		exit 1; \
	fi
	@if [ ! -d "$(ODOO_WORKTREE_PATH)/$(ODOO_SOURCE_VERSION)" ]; then \
		echo ""; \
		echo "  \033[31mError: worktree not found for ODOO_SOURCE_VERSION=$(ODOO_SOURCE_VERSION)\033[0m"; \
		echo "  Run: bash worktree.sh add $(ODOO_SOURCE_VERSION)"; \
		echo ""; \
		exit 1; \
	fi

start: check-worktrees ## Start the environment
	docker compose up -d

stop: ## Stop the environment
	docker compose down

restart: ## Restart the Odoo server (keeps the database running)
	docker compose restart web

restart-all: stop start ## Restart the entire stack (Odoo + database)

logs: ## Stream Odoo server logs
	docker compose logs -f web

shell: ## Open a shell inside the Odoo container
	docker compose exec web bash

ps: ## Show container status
	docker compose ps

pgadmin: ## Start pgAdmin4 at http://localhost:5050
	docker compose --profile pgadmin up -d

restore: ## Restore a database. Usage: make restore dump=file.dump
	./restore.sh dumps/$(dump)

upgrade: ## Upgrade Odoo modules. Usage: make upgrade modules=mod1,mod2
	docker compose exec web python /opt/odoo-src/odoo/odoo-bin \
		-c /etc/odoo/odoo.conf \
		-d $(ODOO_DB_NAME) \
		-u $(modules) \
		--stop-after-init

test: ## Run tests for modules. Usage: make test modules=sale,account
	docker compose exec web python /opt/odoo-src/odoo/odoo-bin \
		-c /etc/odoo/odoo.conf \
		-d $(ODOO_DB_NAME) \
		-u $(modules) \
		--test-enable \
		--stop-after-init

test-tags: ## Run tests by tag. Usage: make test-tags tags=/module:Class.method
	docker compose exec web python /opt/odoo-src/odoo/odoo-bin \
		-c /etc/odoo/odoo.conf \
		-d $(ODOO_DB_NAME) \
		--test-tags $(tags) \
		--stop-after-init

test-file: ## Run tests from a file. Usage: make test-file file=/mnt/extra-addons/module/tests/test_x.py
	docker compose exec web python /opt/odoo-src/odoo/odoo-bin \
		-c /etc/odoo/odoo.conf \
		-d $(ODOO_DB_NAME) \
		--test-file $(file) \
		--stop-after-init

destroy: ## Remove all containers, networks and volumes (deletes the database)
	@echo ""
	@echo "  \033[33mWARNING\033[0m: This will remove all containers, networks and volumes."
	@echo "  The database '$(ODOO_DB_NAME)' will be permanently deleted."
	@echo ""
	@read -p "  Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] \
		&& docker compose down -v \
		|| echo "Aborted."
	@echo ""

fetch-all: ## Fetch latest refs for all vault repos (odoo, enterprise, design-themes)
	@echo ""
	@for repo in odoo enterprise design-themes; do \
		echo "  Fetching $$repo..."; \
		git -C $(ODOO_VAULT_PATH)/$$repo.git fetch --prune origin; \
	done
	@echo ""

build: ## Build the Docker image for the target version. Usage: make build
	docker build \
		-t odoo-dev:$(ODOO_TARGET_VERSION) \
		$(ODOO_WORKTREE_PATH)/$(ODOO_TARGET_VERSION)

help: ## Show this help message
	@echo ""
	@echo "Usage: make <command> [options]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make restore dump=client_prod.dump"
	@echo "  make upgrade modules=sale,account"
	@echo "  make build"
	@echo ""
