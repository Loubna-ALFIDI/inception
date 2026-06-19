FROM debian:bookworm-slim

# Install php-fpm and WordPress dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates     \
        php8.2-fpm          \
        php8.2-mysql        \
        php8.2-curl         \
        php8.2-gd           \
        php8.2-mbstring     \
        php8.2-xml          \
        php8.2-zip          \
        curl                \
        wget                \
        mariadb-client      \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install WP-CLI
RUN curl -sS https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
        -o /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp

# Download WordPress core into /usr/src/wordpress (NOT /var/www/html which gets
# shadowed by the volume mount at runtime). The entrypoint copies files from here.
RUN mkdir -p /usr/src/wordpress /var/www/html \
    && wget -q https://wordpress.org/latest.tar.gz -O /tmp/wordpress.tar.gz \
    && tar -xzf /tmp/wordpress.tar.gz --strip-components=1 -C /usr/src/wordpress \
    && rm /tmp/wordpress.tar.gz \
    && chown -R www-data:www-data /usr/src/wordpress

# php-fpm: listen on TCP instead of a Unix socket (needed for NGINX in another container)
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

# Entrypoint that runs WP setup on first boot then starts php-fpm
COPY tools/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9000

ENTRYPOINT ["/entrypoint.sh"]
