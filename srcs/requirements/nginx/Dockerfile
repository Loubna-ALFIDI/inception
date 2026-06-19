FROM debian:bookworm-slim

# Install NGINX and OpenSSL (for self-signed TLS cert)
RUN apt-get update && apt-get install -y --no-install-recommends \
        nginx       \
        openssl     \
        gettext-base     \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Drop our server block into conf.d/ – the container's default nginx.conf
# already contains:  include /etc/nginx/conf.d/*.conf;
COPY conf/nginx.conf /etc/nginx/conf.d/default.conf
RUN rm -f /etc/nginx/sites-enabled/default
COPY tools/setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

EXPOSE 443

# Run NGINX in the foreground – "daemon off" keeps it as PID 1
ENTRYPOINT ["setup.sh"]
