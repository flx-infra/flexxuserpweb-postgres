#!/bin/sh
# Prepara el directorio de datos (como root), lee las contrasenas de los secrets de Docker (*_FILE)
# y arranca Patroni como usuario postgres.
set -e
if [ "$(id -u)" = "0" ]; then
  mkdir -p /var/lib/postgresql/data
  chown postgres:postgres /var/lib/postgresql/data
  chmod 700 /var/lib/postgresql/data
  exec gosu postgres "$0" "$@"
fi
for v in PATRONI_SUPERUSER_PASSWORD PATRONI_REPLICATION_PASSWORD PATRONI_RESTAPI_PASSWORD; do
  f=$(eval echo "\${${v}_FILE:-}")
  if [ -n "$f" ] && [ -f "$f" ]; then
    export "$v=$(cat "$f")"
  fi
done
exec patroni /etc/patroni.yml
