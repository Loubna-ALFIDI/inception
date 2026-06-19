#!/bin/bash

# Substitute environment variables in nginx config
envsubst '${DOMAIN_NAME}' < /etc/nginx/conf.d/nginx.conf > /etc/nginx/conf.d/nginx.conf.tmp
mv /etc/nginx/conf.d/nginx.conf.tmp /etc/nginx/conf.d/nginx.conf

# Generate self-signed SSL certificate if it doesn't exist
if [ ! -f /etc/nginx/ssl/inception.crt ]; then
  mkdir -p /etc/nginx/ssl \
    && openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/inception.key \
        -out    /etc/nginx/ssl/inception.crt \
        -subj "/C=MA/ST=RB/L=RABAT/O=1337/OU=1337/CN=${DOMAIN_NAME}"
fi

# Start nginx in foreground (PID 1)
exec nginx -g "daemon off;"
