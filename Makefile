COMPOSE_FILE	= srcs/docker-compose.yml
DATA_DIR		= /home/loulou/data

all: up

up:
	@mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	@docker compose -f $(COMPOSE_FILE) up -d --build

down:
	@docker compose -f $(COMPOSE_FILE) down

stop:
	@docker compose -f $(COMPOSE_FILE) stop

start:
	@docker compose -f $(COMPOSE_FILE) start

re: fclean up

clean: down
	@docker system prune -af

fclean: clean wipe

wipe:
	@echo "Wiping persistent data at $(DATA_DIR)..."
	sudo rm -rf $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	@echo "Done."

logs:
	@docker compose -f $(COMPOSE_FILE) logs -f

status:
	@docker compose -f $(COMPOSE_FILE) ps

.PHONY: all up down stop start re clean fclean wipe logs status
