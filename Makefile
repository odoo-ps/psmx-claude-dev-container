include .env
export

.PHONY: start stop restart logs shell ps restore upgrade build destroy help

start: ## Levanta el entorno
	docker compose up -d

stop: ## Baja el entorno
	docker compose down

restart: stop start ## Reinicia el entorno

logs: ## Muestra los logs del servidor Odoo
	docker compose logs -f web

shell: ## Abre una shell dentro del contenedor Odoo
	docker compose exec web bash

ps: ## Muestra el estado de los contenedores
	docker compose ps

pgadmin: ## Levanta pgAdmin4 (interfaz web para PostgreSQL)
	docker compose --profile pgadmin up -d

restore: ## Restaura una base de datos. Uso: make restore dump=archivo.dump
	./restore.sh dumps/$(dump)

upgrade: ## Upgradea módulos de Odoo. Uso: make upgrade modules=mod1,mod2
	docker compose exec web python /opt/odoo-src/odoo/odoo-bin \
		-c /etc/odoo/odoo.conf \
		-d $(ODOO_DB_NAME) \
		-u $(modules) \
		--stop-after-init

destroy: ## Elimina contenedores, redes Y volúmenes (borra la base de datos)
	@echo ""
	@echo "  \033[33mWARNING\033[0m: This will remove all containers, networks and volumes."
	@echo "  The database '$(ODOO_DB_NAME)' will be permanently deleted."
	@echo ""
	@read -p "  Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] \
		&& docker compose down -v \
		|| echo "Aborted."
	@echo ""

build: ## Construye la imagen Docker para la versión target. Uso: make build
	docker build \
		-t odoo-dev:$(ODOO_TARGET_VERSION) \
		$(ODOO_WORKTREE_PATH)/$(ODOO_TARGET_VERSION)

help: ## Muestra este mensaje de ayuda
	@echo ""
	@echo "Uso: make <comando> [opciones]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Ejemplos:"
	@echo "  make restore dump=cliente_prod.dump"
	@echo "  make upgrade modules=sale,account"
	@echo "  make build"
	@echo ""
