FROM debian:bookworm-slim

# Install MariaDB server
RUN apt-get update && apt-get install -y --no-install-recommends \
        mariadb-server \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy init SQL script and entrypoint
COPY conf/my.cnf      /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /entrypoint.sh

# Create the socket directory that MariaDB expects (not present in slim image)
# and set the entrypoint as executable in one layer
RUN mkdir -p /run/mysqld \
    && chown -R mysql:mysql /run/mysqld \
    && chmod +x /entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["/entrypoint.sh"]
