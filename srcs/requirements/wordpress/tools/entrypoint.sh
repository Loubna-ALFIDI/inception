#!/bin/bash
set -e

WP_PATH=/var/www/html

MYSQL_PASSWORD=$(tr -d '\n\r' < /run/secrets/mysql_password)
WP_ADMIN_PASSWORD=$(tr -d '\n\r' < /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(tr -d '\n\r' < /run/secrets/wp_user_password)

if [ ! -f "$WP_PATH/index.php" ]; then
    cp -a /usr/src/wordpress/. "$WP_PATH/"
    chown -R www-data:www-data "$WP_PATH"
fi

DB_HOST="${WP_DB_HOST%%:*}"
DB_PORT="${WP_DB_HOST##*:}"

while ! bash -c "</dev/tcp/$DB_HOST/$DB_PORT" 2>/dev/null; do sleep 2; done

while ! mariadb -h "$DB_HOST" -P "$DB_PORT" \
        -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -e "SELECT 1;" 2>/dev/null; do
    sleep 2
done

if [ ! -f "$WP_PATH/wp-config.php" ]; then
    wp config create \
        --allow-root \
        --path="$WP_PATH" \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$MYSQL_PASSWORD" \
        --dbhost="$WP_DB_HOST" \
        --skip-check

    wp core install \
        --allow-root \
        --path="$WP_PATH" \
        --url="https://$DOMAIN_NAME" \
        --title="Inception" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email

    wp user create \
        --allow-root \
        --path="$WP_PATH" \
        "$WP_USER" "$WP_USER_EMAIL" \
        --role=editor \
        --user_pass="$WP_USER_PASSWORD"
fi

exec php-fpm8.2 --nodaemonize
