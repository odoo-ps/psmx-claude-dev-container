include .env
export

.PHONY: start stop restart restart-all logs shell ps restore upgrade build destroy help

start: ## Start the environment
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

destroy: ## Remove all containers, networks and volumes (deletes the database)
	@echo ""
	@echo "  \033[33mWARNING\033[0m: This will remove all containers, networks and volumes."
	@echo "  The database '$(ODOO_DB_NAME)' will be permanently deleted."
	@echo ""
	@read -p "  Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] \
		&& docker compose down -v \
		|| echo "Aborted."
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
