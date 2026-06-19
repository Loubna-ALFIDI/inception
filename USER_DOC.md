# User Documentation

This project runs a small WordPress stack in Docker. It includes three services:

- `mariadb`: stores the WordPress database.
- `wordpress`: runs WordPress with PHP-FPM.
- `nginx`: serves the website over HTTPS and forwards PHP requests to WordPress.

Only NGINX is exposed to the host on port `443`. MariaDB and WordPress stay inside the Docker network.

## Start and Stop the Project

From the repository root, use the `Makefile`:

```bash
make up
```

This builds the images if needed, creates the persistent data folders, and starts all services in the background.

To stop the stack, use:

```bash
make down
```

Other useful commands:

- `make stop` pauses the containers.
- `make start` resumes paused containers.
- `make logs` shows live logs from all services.
- `make status` shows the current container state.

## Access the Website and Administration Panel

Open the configured domain in your browser over HTTPS. In this project, the expected domain is `lalfidi.1337.ma`.

If you are browsing from the same machine, make sure it resolves to `127.0.0.1` in `/etc/hosts`.

The WordPress site is available at:

```text
https://lalfidi.1337.ma
```

The WordPress administration panel is available under the standard admin path:

```text
https://lalfidi.1337.ma/wp-admin
```

Use the WordPress administrator credentials from the secret files described below.

## Locate and Manage Credentials

Passwords are not stored in the Compose file. They are kept as plain-text secret files in the repository root `secrets/` directory and mounted into the containers read-only.

Secret files used by the stack:

- `secrets/mysql_password.txt`
- `secrets/mysql_root_password.txt`
- `secrets/wp_admin_password.txt`
- `secrets/wp_user_password.txt`

These files should be treated as sensitive. Do not commit them to version control or share them publicly.

## Check That Services Are Running Correctly

You can verify the stack with a few quick checks:

1. Check container status:

```bash
make status
```

All three containers should show as running.

2. Check the logs if something looks wrong:

```bash
make logs
```

3. Test the website over HTTPS:

```bash
curl -k https://lalfidi.1337.ma
```

You should receive the WordPress HTML page.

4. Confirm the database is available:

```bash
docker exec -it mariadb mariadb -u wp_user -p"$(cat secrets/mysql_password.txt)" wordpress -e "SHOW TABLES;"
```

## Where Data Is Stored

The website and database data persist in Docker bind-mounted volumes on the host:

- MariaDB data: `/home/loulou/data/mariadb`
- WordPress files: `/home/loulou/data/wordpress`

This means your data remains available after restarting the containers.
