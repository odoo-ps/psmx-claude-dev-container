include .env
export

.PHONY: start stop restart logs shell ps restore upgrade build help

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
