#!/bin/sh
# Lee las contraseñas de los secrets de Docker (*_FILE) y arranca Patroni.
set -e
for v in PATRONI_SUPERUSER_PASSWORD PATRONI_REPLICATION_PASSWORD PATRONI_RESTAPI_PASSWORD; do
  f=$(eval echo "\${${v}_FILE:-}")
  if [ -n "$f" ] && [ -f "$f" ]; then
    export "$v=$(cat "$f")"
  fi
done
exec patroni /etc/patroni.yml
