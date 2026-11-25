# Celda PostgreSQL 18 · Patroni, etcd, HAProxy y PgBouncer

Opción 1 de la pizarra «Despliegue Flexxus Order»: la celda corre dentro del Swarm, en dos workers reservados para bases (worker2 y worker3), con etcd en tres nodos distintos.

## Despliegue actual

- Swarm de 10.250.0.98, stack `flexxuserpweb-postgres` en Portainer, desplegado desde este repo (rama `main`) con actualización automática cada 5 minutos: un push a `main` se aplica solo.
- pgAdmin y otras herramientas: `10.250.0.98:15432` (primario) y `:15433` (réplicas).
- Configs `celda01_*_v1` y secrets creados aparte en Portainer: no están en el repo.

## Qué levanta

| Servicio | Réplicas | Dónde | Para qué |
|---|---|---|---|
| etcd1, etcd2, etcd3 | 1 c/u | manager01, worker1, worker3 | Registro de quién es el primario |
| postgres-worker2, postgres-worker3 | 1 c/u | worker2, worker3 | PostgreSQL 18 con Patroni, replicación síncrona |
| haproxy | 2 | workers, uno por nodo | :5000 al primario, :5001 a las réplicas, :7000 estadísticas |
| pgbouncer | 2 | workers, uno por nodo | :6432, modo transacción, `auth_query` |

La API de Order se conecta a `pgbouncer:6432` por la red `celda-01-app`.

## Pasos

1. Revisar los nodos: PostgreSQL va fijado por nombre a `PG_NODE_1` y `PG_NODE_2` (worker2 y worker3), etcd a `ETCD_NODE_1..3` (manager01, worker1, worker3). HAProxy y PgBouncer van a cualquier worker, uno por nodo.
2. Construir y subir la imagen: `docker build -t <registro>/patroni-pg18:1 patroni/` y `docker push`.
3. Crear los secrets con las contraseñas (Portainer > Secrets, o `docker secret create`): `pg_superuser_password`, `pg_replication_password`, `patroni_api_password`. No se guardan en el repo.
4. Crear los configs: `./crear-configs.sh` en un manager (o en Portainer > Configs con los mismos nombres).
5. Desplegar: `docker stack deploy -c docker-compose.yml celda01`. Variables opcionales: `REGISTRO`, `PATRONI_TAG`, `PG_NODE_1`, `PG_NODE_2`, `ETCD_NODE_1..3`.
6. Ver el estado: `docker exec -it <contenedor pg> patronictl -c /etc/patroni.yml list` debe mostrar un `Leader` y un `Sync Standby`.
7. Correr `init.sql` en el primario (`psql -h haproxy -p 5000 -U postgres`) y poner el hash SCRAM de `pgbouncer_auth` en `pgbouncer/userlist.txt` (`SELECT passwd FROM pg_shadow WHERE usename='pgbouncer_auth'`). Crear el config `celda01_pgbouncer_userlist_v2` con ese contenido, cambiar el nombre en el compose y redesplegar.
8. Probar la caída: detener `postgres-worker2` (o el que sea primario) y confirmar con `patronictl list` que el otro pasa a `Leader` en unos 30 segundos y que PgBouncer sigue respondiendo.

## Notas

- La replicación síncrona es de toda la instancia, no de cada base. Por base se ajusta con `synchronous_commit` (ver `init.sql`).
- `synchronous_mode_strict: false`: si cae la réplica, el primario sigue escribiendo sin esperarla. Con `true` las ventas se frenan hasta que vuelva.
- Con dos nodos de base no hay segunda réplica para la próxima caída: la réplica asíncrona del segundo sitio se suma después.
- Fijar las versiones de las imágenes (`PGBOUNCER_TAG`, etcd, haproxy) antes de producción.
- worker2 hoy corre unos 200 stacks fijados a él. Para reservarlo a bases hay que moverlos antes, o usar otro worker.
