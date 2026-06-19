*This project has been created as part of the 42 curriculum by lalfidi*

# Inception

## Description

A small web infrastructure running inside Docker containers, orchestrated with Docker Compose. This project demonstrates containerization, orchestration, and networking principles by deploying a production-like HTTPS-enabled WordPress stack with MariaDB and NGINX services.

---

## Architecture

```
Browser (HTTPS :443)
        │
        ▼
   ┌─────────┐
   │  NGINX  │  ← sole public entry point, TLSv1.2/1.3 only
   └────┬────┘
        │ FastCGI (port 9000)
        ▼
   ┌───────────┐
   │ WordPress │  ← php-fpm, no web server
   │  php-fpm  │
   └─────┬─────┘
         │ TCP (port 3306)
         ▼
   ┌──────────┐
   │ MariaDB  │  ← database only, not exposed publicly
   └──────────┘
```

All three services live on the same internal Docker bridge network (`inception`).
Only NGINX is exposed to the host, on port 443.

---

## Services

| Service   | Base image            | Role                                      | Exposed port |
|-----------|-----------------------|-------------------------------------------|--------------|
| mariadb   | debian:bookworm-slim  | WordPress database                        | internal 3306 |
| wordpress | debian:bookworm-slim  | WordPress + php-fpm                       | internal 9000 |
| nginx     | debian:bookworm-slim  | Reverse proxy / TLS termination           | **443**       |

### Startup order

1. **MariaDB** starts first. On every boot it runs a `--skip-grant-tables` pass to ensure the correct database and user credentials are in place, then starts the main server.
2. **WordPress** waits for MariaDB TCP to be reachable, then waits for authentication to succeed. On first boot it copies the WordPress core files into the volume and runs WP-CLI to install the site and create users. Then it starts `php-fpm`.
3. **NGINX** starts last. It proxies PHP requests to `wordpress:9000` via FastCGI and serves static files directly from the shared volume.

---

## Persistent storage

Two named Docker volumes store data on the host under `/home/lalfidi/data`:

| Volume          | Host path                        | Used by               |
|-----------------|----------------------------------|-----------------------|
| `mariadb_data`  | `/home/lalfidi/data/mariadb`      | MariaDB data directory |
| `wordpress_data`| `/home/lalfidi/data/wordpress`    | WordPress web root    |

Both NGINX and WordPress mount `wordpress_data` so NGINX can serve static assets without going through php-fpm.

---

## Credentials & secrets

Non-sensitive configuration lives in `srcs/.env`.  
All passwords are stored as plain-text files in `secrets/` and mounted read-only inside containers at `/run/secrets/<name>`.

| Secret file                    | Used by              |
|--------------------------------|----------------------|
| `secrets/mysql_password.txt`   | MariaDB + WordPress  |
| `secrets/mysql_root_password.txt` | MariaDB           |
| `secrets/wp_admin_password.txt`| WordPress            |
| `secrets/wp_user_password.txt` | WordPress            |

> **Important:** Both `srcs/.env` and `secrets/` are listed in `.gitignore` and must never be committed.

---

## Instructions

### Domain name setup

Add one line to `/etc/hosts` on the machine you browse from:

```bash
sudo sh -c 'echo "127.0.0.1   lalfidi.1337.ma" >> /etc/hosts'
```

Replace `127.0.0.1` with your VM's IP if you are accessing from a different machine.

### How to start the stack

```bash
# Build images and start all containers in the background
make up

# Or equivalently
make
```

The `up` target automatically creates `/home/lalfidi/data/mariadb` and `/home/lalfidi/data/wordpress` before starting containers.

---

## Makefile reference

| Command       | Effect                                                        |
|---------------|---------------------------------------------------------------|
| `make up`     | Build images (if needed) and start all containers            |
| `make down`   | Stop and remove containers (volumes are preserved)           |
| `make stop`   | Pause running containers                                     |
| `make start`  | Resume paused containers                                     |
| `make re`     | Full rebuild: `fclean` then `up`                             |
| `make clean`  | `down` + prune all unused Docker objects                     |
| `make fclean` | `clean` + wipe host data directories                         |
| `make wipe`   | Delete host data directories only (no Docker cleanup)        |
| `make logs`   | Stream logs from all containers                              |
| `make status` | Show running container status                                |

---

## Verifying the stack

### 1 — Container status
```bash
make status
# or
docker compose -f srcs/docker-compose.yml ps
```
All three containers should show `Up`.

### 2 — Live logs
```bash
make logs
# or per service:
docker logs mariadb
docker logs wordpress
docker logs nginx
```

### 3 — HTTPS endpoint
```bash
curl -k https://lalfidi.1337.ma
# Should return the WordPress HTML
```

### 4 — MariaDB access
```bash
docker exec -it mariadb mariadb \
    -u wp_user \
    -p"$(cat secrets/mysql_password.txt)" \
    wordpress \
    -e "SHOW TABLES;"
```

### 5 — php-fpm process
```bash
docker exec wordpress ps aux | grep php-fpm
```

### 6 — WordPress users
```bash
docker exec wordpress wp user list --allow-root --path=/var/www/html
```

---

## Project layout

```
inception/
├── Makefile
├── .gitignore
├── secrets/                        ← passwords (git-ignored)
│   ├── mysql_password.txt
│   ├── mysql_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env                        ← non-sensitive config (git-ignored)
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/my.cnf
        │   └── tools/entrypoint.sh
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/nginx.conf
        └── wordpress/
            ├── Dockerfile
            ├── conf/www.conf
            └── tools/entrypoint.sh
```
---

## Resources

### AI Usage

This project was developed with the assistance of AI tools, which were used for the following purposes:

- **Code scaffolding and structure**: AI assistance was used to design and implement the Dockerfile configurations, docker-compose.yml orchestration, and service entrypoints.
- **Documentation**: AI tools helped create comprehensive documentation including architecture diagrams, setup instructions, and verification procedures.
- **Troubleshooting**: AI provided guidance on Docker networking, container lifecycle management, and service dependency resolution.
- **Configuration optimization**: AI assisted in optimizing NGINX, MariaDB, and PHP-FPM configurations for security and performance.

The core architecture and deployment strategy were guided by 42 curriculum requirements, while AI tools accelerated implementation and documentation tasks.

### Additional references

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- [NGINX FastCGI](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
- [MariaDB Documentation](https://mariadb.com/docs/)
- [WordPress CLI](https://wp-cli.org/)