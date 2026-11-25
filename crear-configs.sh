#!/bin/sh
# Crea en el Swarm los configs que usa el stack (correr en un manager, desde esta carpeta).
set -e
docker config create celda01_patroni_yml_v1 patroni/patroni.yml
docker config create celda01_haproxy_cfg_v1 haproxy/haproxy.cfg
docker config create celda01_pgbouncer_ini_v1 pgbouncer/pgbouncer.ini
docker config create celda01_pgbouncer_userlist_v1 pgbouncer/userlist.txt
