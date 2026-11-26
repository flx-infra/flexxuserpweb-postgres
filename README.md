# Celda PostgreSQL 18 · Patroni, etcd, HAProxy y PgBouncer

Opción 1 de la pizarra «Despliegue Flexxus Order»: la celda corre dentro del Swarm, en dos workers reservados para bases (worker2 y worker3), con etcd en tres nodos distintos.

## Despliegue actual

- Swarm de 10.250.0.98, stack `flexxuserpweb-postgres` en Portainer, desplegado desde este repo (rama `main`) con actualización automática cada 5 minutos: un push a `main` se aplica solo.
- pgAdmin y otras herramientas: `10.250.0.98:15432` (primario) y `:15433` (réplicas). PgBouncer: `10.250.0.98:16432`.
- Configs `celda01_*_v1` y secrets creados aparte en Portainer: no están en el repo.

## Qué levanta

| Servicio | Réplicas | Dónde | Para qué |
|---|---|---|---|
| (etcd) | — | stack aparte `etcd-flexxus` | Registro de quién es el primario, compartido por todas las celdas |
| postgres-worker2, postgres-worker3 | 1 c/u | worker2, worker3 | PostgreSQL 18 con Patroni, replicación síncrona |
| haproxy | 2 | workers, uno por nodo | :5000 al primario, :5001 a las réplicas, :7000 estadísticas |
| pgbouncer | 2 | workers, uno por nodo | :6432, modo transacción, `auth_query` |

La API de Order se conecta a `pgbouncer:6432` por la red `celda-01-app`.

## Pasos

1. Revisar los nodos: PostgreSQL va fijado por nombre a `PG_NODE_1` y `PG_NODE_2` (worker2 y worker3), etcd a `ETCD_NODE_1..3` (manager01, worker1, worker3). HAProxy y PgBouncer van a cualquier worker, uno por nodo.
2. Construir y subir la imagen: `docker build -t <registro>/patroni-pg18:1 patroni/` y `docker push`.
3. Crear los secrets con las contraseñas (Portainer > Secrets, o `docker secret create`): `pg_superuser_password`, `pg_replication_password`, `patroni_api_password`, `pgbouncer_auth_password` y `flexxuserp_api_password`. No se guardan en el repo.
4. Crear los configs: `./crear-configs.sh` en un manager (o en Portainer > Configs con los mismos nombres).
5. Desplegar: `docker stack deploy -c docker-compose.yml celda01`. Variables opcionales: `REGISTRO`, `PATRONI_TAG`, `PG_NODE_1`, `PG_NODE_2`, `ETCD_NODE_1..3`.
6. Ver el estado: `docker exec -it <contenedor pg> patronictl -c /etc/patroni.yml list` debe mostrar un `Leader` y un `Sync Standby`.
7. Crear los secrets `pgbouncer_auth_password` y `flexxuserp_api_password` y correr `init.sql` en el primario como indica su encabezado (toma las contraseñas de los secrets). PgBouncer arma su `userlist.txt` solo, desde `pgbouncer_auth_password`.
8. Probar la caída: detener `postgres-worker2` (o el que sea primario) y confirmar con `patronictl list` que el otro pasa a `Leader` en unos 30 segundos y que PgBouncer sigue respondiendo.

## Notas

- La replicación síncrona es de toda la instancia, no de cada base. Por base se ajusta con `synchronous_commit` (ver `init.sql`).
- `synchronous_mode_strict: false`: si cae la réplica, el primario sigue escribiendo sin esperarla. Con `true` las ventas se frenan hasta que vuelva.
- Con dos nodos de base no hay segunda réplica para la próxima caída: la réplica asíncrona del segundo sitio se suma después.
- PgBouncer fijado en v1.26.1-p0. Falta fijar haproxy (hoy `3.0`).
- `default_pool_size = 10` y `server_login_retry = 2` (config `celda01_pgbouncer_ini_v2`): conexiones al servidor por base y por instancia de PgBouncer; con 3 APIs y 2 PgBouncer, cada cliente usa hasta 20 conexiones al primario. `server_login_retry` baja de ~15 s a ~2 s los errores después de un failover.
- worker2 hoy corre unos 200 stacks fijados a él. Para reservarlo a bases hay que moverlos antes, o usar otro worker.
