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

## Project Description

### Why Docker?

Docker is used in this project to achieve several critical goals:

1. **Isolation**: Each service (NGINX, WordPress, MariaDB) runs in its own container with its own filesystem and processes, preventing conflicts and unexpected interactions.
2. **Reproducibility**: The same Dockerfile and docker-compose.yml configuration runs identically on any machine with Docker installed, eliminating "works on my machine" problems.
3. **Scalability**: Services can be easily scaled horizontally (more instances) or modified without affecting the host system.
4. **Security**: Containers provide process and network isolation by default, with explicit port exposure and read-only filesystem mounts.
5. **Development efficiency**: Developers can work with production-like environments locally, reducing integration surprises.

### Sources Included in the Project

The project structure includes three main service containers:

- **mariadb/**: Contains the MariaDB database service
  - `Dockerfile`: Based on `debian:bookworm-slim`, installs MariaDB server
  - `conf/my.cnf`: Custom MariaDB configuration for performance and security
  - `tools/entrypoint.sh`: Initialization script to set up database and credentials on first boot

- **nginx/**: Contains the NGINX reverse proxy and web server
  - `Dockerfile`: Based on `debian:bookworm-slim`, installs NGINX and OpenSSL for TLS
  - `conf/nginx.conf`: Production-ready NGINX configuration with TLSv1.2/1.3, FastCGI proxying, and static file serving
  - `tools/setup.sh`: Certificate generation and configuration setup script

- **wordpress/**: Contains WordPress with PHP-FPM
  - `Dockerfile`: Based on `debian:bookworm-slim`, installs PHP-FPM and WordPress CLI
  - `conf/www.conf`: PHP-FPM pool configuration
  - `tools/entrypoint.sh`: WP-CLI automation for WordPress installation and user creation

### Main Design Choices

1. **Multi-stage initialization**: Services start sequentially (MariaDB → WordPress → NGINX) with health checks to ensure readiness before dependents start.
2. **Minimal base images**: All containers use `debian:bookworm-slim` instead of bloated images, reducing attack surface and startup time.
3. **Custom entrypoints**: Each service uses shell scripts to automate configuration and credential injection, enabling fully automated deployment.
4. **Shared volumes**: WordPress code is mounted on both WordPress and NGINX containers, allowing NGINX to serve static files efficiently.
5. **TLS termination at NGINX**: NGINX is the sole entry point and handles all HTTPS encryption, simplifying WordPress configuration and reducing computational overhead on the application server.
6. **Secrets management**: Passwords are mounted as read-only files from `/run/secrets/`, following Docker best practices.

### Technical Comparisons

#### Virtual Machines vs Docker

| Aspect | Virtual Machines | Docker |
|--------|------------------|--------|
| **Overhead** | High (full OS per VM, 100s MB-GB) | Minimal (shared kernel, 10s-100s MB) |
| **Startup time** | Minutes | Seconds |
| **Portability** | Tied to hypervisor | Runs on any OS with Docker |
| **Resource efficiency** | Lower (multiple full OSes) | Higher (one shared OS kernel) |
| **Isolation** | Process & OS-level | Process-level (still strong) |
| **Use case** | Legacy apps, multi-OS | Microservices, cloud-native |

**Why Docker for this project**: Docker provides sufficient isolation for microservices while keeping resource overhead minimal. NGINX, WordPress, and MariaDB don't require full OS kernels—they just need their runtime dependencies.

#### Secrets vs Environment Variables

| Aspect | Environment Variables | Docker Secrets |
|--------|----------------------|-----------------|
| **Visibility** | Exposed in `docker inspect`, process listing | Hidden in container filesystem |
| **Logging** | Often logged accidentally | Never logged by Docker |
| **Revocation** | Requires container restart | Immediate (in swarm mode) |
| **Scalability** | Simple for small projects | Better for large deployments |
| **Security** | Lower (readable in many places) | Higher (mounted as files only) |
| **Current approach** | Not used here | **Used** (files in `/run/secrets/`) |

**Why files in `/run/secrets/`**: This approach is more secure than environment variables. Docker runs these containers with secret files mounted read-only at runtime, preventing accidental exposure in logs or `docker inspect` output. In production, Docker secrets (in swarm mode) would be preferred.

#### Docker Network vs Host Network

| Aspect | Bridge Network | Host Network |
|--------|---|---|
| **Isolation** | Full network isolation | No isolation (shares host network) |
| **Port mapping** | Required (port forwarding) | Direct access to host ports |
| **Inter-container communication** | Via container names (DNS) | Via localhost:port or IP |
| **Security** | Higher (internal services not exposed) | Lower (all ports visible to host) |
| **Performance** | Slight overhead (NAT/routing) | Negligible (direct access) |
| **Use case** | Default, recommended | Legacy apps, special requirements |

**Why bridge network here**: This project uses a custom bridge network (`inception`) for maximum isolation. Only NGINX exposes port 443 to the host; MariaDB and WordPress communicate internally via container DNS. This prevents accidental external access to database or app servers.

#### Docker Volumes vs Bind Mounts

| Aspect | Named Volumes | Bind Mounts |
|--------|---|---|
| **Location** | Docker-managed (`/var/lib/docker/volumes/`) | Host filesystem path |
| **Persistence** | Survives container deletion | Survives container deletion |
| **Portability** | Database-agnostic, driver-agnostic | Tied to host filesystem |
| **Performance** | Optimized for Docker | Slower on non-Linux (VM overhead) |
| **Permissions** | Docker-managed | Host filesystem permissions apply |
| **Backup/restore** | Via Docker API | Via standard filesystem tools |
| **Current approach** | **Used** (`mariadb_data`, `wordpress_data`) | Not used |

**Why named volumes here**: This project uses named volumes for data persistence. Volumes are managed by Docker, making backup and migration easier. They survive container recreation (via `make fclean` and `make up`), and on Linux they provide optimal I/O performance. Bind mounts could expose host filesystem and make deployment less portable.

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