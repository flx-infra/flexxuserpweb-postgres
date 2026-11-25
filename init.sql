-- Correr una vez en el primario (por HAProxy :5000), como postgres.
-- Se crea en template1 para que toda base nueva de cliente lo herede.

-- Usuario técnico de PgBouncer (solo lee el catálogo de contraseñas a través de la función)
CREATE ROLE pgbouncer_auth LOGIN PASSWORD 'CAMBIAR';

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

-- Ejemplo de base de cliente: hereda la función desde template1.
-- CREATE DATABASE cliente_0001;
-- La replicación síncrona es de toda la instancia; por base se puede relajar:
-- ALTER DATABASE cliente_prueba SET synchronous_commit = local;   -- no espera a la réplica
-- ALTER DATABASE cliente_0001  SET synchronous_commit = on;      -- espera a la réplica (por defecto)
