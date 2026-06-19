# Developer Documentation

This repository contains a Docker Compose stack with three services:

- `mariadb` for the database
- `wordpress` for the application and PHP-FPM
- `nginx` as the HTTPS reverse proxy

The stack is defined in `srcs/docker-compose.yml` and managed from the repository root with the `Makefile`.

## Set Up the Environment From Scratch

Before building the project, make sure the following are available on your machine:

- Docker
- Docker Compose
- `make`
- A working `/etc/hosts` entry for the configured domain, if you want to access the site locally

The project also expects two kinds of configuration files:

- Non-sensitive configuration in `srcs/.env`
- Secret password files in `secrets/`

Required secret files:

- `secrets/mysql_password.txt`
- `secrets/mysql_root_password.txt`
- `secrets/wp_admin_password.txt`
- `secrets/wp_user_password.txt`

These are mounted into the containers as Docker secrets. Keep them out of version control.

If you are setting up a fresh machine, also make sure the persistent storage directory exists or can be created by the `Makefile`:

- `/home/loulou/data/mariadb`
- `/home/loulou/data/wordpress`

## Build and Launch the Project

The standard entry point is:

```bash
make up
```

This target:

- creates the host data directories
- builds the images
- starts the containers in detached mode

`make` is equivalent to `make up`.

You can also run the Compose file directly if needed:

```bash
docker compose -f srcs/docker-compose.yml up -d --build
```

## Container Management Commands

The `Makefile` provides the main lifecycle commands:

- `make down` stops and removes the containers
- `make stop` pauses running containers
- `make start` resumes paused containers
- `make re` performs a full rebuild after wiping data
- `make clean` removes containers and prunes unused Docker objects
- `make fclean` removes containers, prunes Docker objects, and deletes persistent host data
- `make wipe` deletes only the persistent host data directories
- `make logs` streams logs from all containers
- `make status` shows the current container state

Useful direct Docker commands:

```bash
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs -f
docker compose -f srcs/docker-compose.yml down
docker compose -f srcs/docker-compose.yml stop
docker compose -f srcs/docker-compose.yml start
```

## Data Storage and Persistence

Persistence is handled through local bind-mounted Docker volumes defined in `srcs/docker-compose.yml`.

Volume mapping:

- `mariadb_data` -> `/home/loulou/data/mariadb`
- `wordpress_data` -> `/home/loulou/data/wordpress`

These mounts mean the database contents and WordPress files survive container restarts and rebuilds, unless the data directories are removed with `make wipe` or `make fclean`.

The WordPress volume is shared between the `wordpress` and `nginx` containers so NGINX can serve static files directly from the same file tree.

## Where the Project Logic Lives

The main service configuration and startup logic are organized here:

- `srcs/requirements/mariadb/`
- `srcs/requirements/nginx/`
- `srcs/requirements/wordpress/`

Each service directory contains its own `Dockerfile`, configuration files, and startup scripts.
