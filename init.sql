-- Usuarios de la celda y función de auth_query para PgBouncer. Se corre una vez, en el primario.
-- Las contraseñas salen de los secrets de Docker montados en el contenedor de PostgreSQL:
--
--   psql -X -v ON_ERROR_STOP=1 \
--     -v pbpw="$(cat /run/secrets/pgbouncer_auth_password)" \
--     -v apipw="$(cat /run/secrets/flexxuserp_api_password)" \
--     -h /var/run/postgresql -U postgres -d postgres -f init.sql
--
-- Es idempotente: se puede volver a correr.

SELECT format('CREATE ROLE pgbouncer_auth LOGIN PASSWORD %L', :'pbpw')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pgbouncer_auth') \gexec
SELECT format('CREATE ROLE flexxuserp_api LOGIN PASSWORD %L', :'apipw')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'flexxuserp_api') \gexec

-- La función se crea en template1 (la heredan las bases nuevas) y en postgres.
\connect template1
CREATE SCHEMA IF NOT EXISTS pgbouncer AUTHORIZATION postgres;
CREATE OR REPLACE FUNCTION pgbouncer.get_auth(p_usename text)
RETURNS TABLE (usename name, passwd text)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT usename, passwd FROM pg_catalog.pg_shadow WHERE usename = p_usename;
$$;
REVOKE ALL ON FUNCTION pgbouncer.get_auth(text) FROM PUBLIC;
GRANT USAGE ON SCHEMA pgbouncer TO pgbouncer_auth;
GRANT EXECUTE ON FUNCTION pgbouncer.get_auth(text) TO pgbouncer_auth;

\connect postgres
CREATE SCHEMA IF NOT EXISTS pgbouncer AUTHORIZATION postgres;
CREATE OR REPLACE FUNCTION pgbouncer.get_auth(p_usename text)
RETURNS TABLE (usename name, passwd text)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT usename, passwd FROM pg_catalog.pg_shadow WHERE usename = p_usename;
$$;
REVOKE ALL ON FUNCTION pgbouncer.get_auth(text) FROM PUBLIC;
GRANT USAGE ON SCHEMA pgbouncer TO pgbouncer_auth;
GRANT EXECUTE ON FUNCTION pgbouncer.get_auth(text) TO pgbouncer_auth;

-- Base de prueba de la API.
SELECT 'CREATE DATABASE cliente_prueba OWNER flexxuserp_api'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'cliente_prueba') \gexec

-- La replicación síncrona es de toda la instancia; por base se puede relajar:
-- ALTER DATABASE cliente_prueba SET synchronous_commit = local;   -- no espera a la réplica
