#!/bin/bash
set -e

MYSQL_PASSWORD=$(tr -d '\n\r' < /run/secrets/mysql_password)
MYSQL_ROOT_PASSWORD=$(tr -d '\n\r' < /run/secrets/mysql_root_password)

if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db --user=mysql --datadir=/var/lib/mysql --skip-test-db
fi

mysqld --user=mysql --skip-networking --skip-grant-tables \
    --socket=/run/mysqld/mysqld.sock &
SETUP_PID=$!

while [ ! -S /run/mysqld/mysqld.sock ]; do sleep 0.3; done
sleep 1

mariadb --socket=/run/mysqld/mysqld.sock <<-EOSQL
    FLUSH PRIVILEGES;
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
    DELETE FROM mysql.user WHERE User='';
    DROP DATABASE IF EXISTS test;
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`
        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%';
    ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL

kill "$SETUP_PID"
wait "$SETUP_PID" || true

exec mysqld --user=mysql
