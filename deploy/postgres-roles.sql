-- OpenReply on a shared Postgres: one schema, three roles.
--
-- For a database that several apps share (one schema per app), instead of
-- giving OpenReply a database of its own:
--
--   openreply_manager  owns the schema, runs `prisma migrate deploy`
--   openreply_app      what the web app and worker connect as (read/write rows)
--   openreply_viewer   read-only, for dashboards and ad-hoc queries
--
-- Run as a superuser, connected to the target database, with the passwords as
-- psql variables so they stay out of shell history and this file:
--
--   psql -d <database> \
--     -v manager_pw="$(openssl rand -hex 24)" \
--     -v app_pw="$(openssl rand -hex 24)" \
--     -v viewer_pw="$(openssl rand -hex 24)" \
--     -f deploy/postgres-roles.sql
--
-- Print the generated passwords first if you use the form above: psql does not
-- echo them back. The grants below apply to the database you are connected to.
--
-- Connection strings (see docker-compose.prod.yml):
--   DATABASE_URL          openreply_app,     ...?schema=openreply
--   MIGRATE_DATABASE_URL  openreply_manager, ...?schema=openreply

\set ON_ERROR_STOP on
SELECT current_database() AS db \gset

CREATE ROLE openreply_manager LOGIN PASSWORD :'manager_pw';
CREATE ROLE openreply_app     LOGIN PASSWORD :'app_pw';
CREATE ROLE openreply_viewer  LOGIN PASSWORD :'viewer_pw';

GRANT CONNECT ON DATABASE :"db" TO openreply_manager, openreply_app, openreply_viewer;

CREATE SCHEMA openreply AUTHORIZATION openreply_manager;
GRANT USAGE ON SCHEMA openreply TO openreply_app, openreply_viewer;

-- Unqualified names resolve to the app's own schema. The app passes the schema
-- explicitly as well (lib/db/client.ts), this covers psql sessions and tools.
ALTER ROLE openreply_manager SET search_path = openreply;
ALTER ROLE openreply_app     SET search_path = openreply;
ALTER ROLE openreply_viewer  SET search_path = openreply;

-- Tables and sequences the manager creates from now on (every migration).
ALTER DEFAULT PRIVILEGES FOR ROLE openreply_manager IN SCHEMA openreply
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO openreply_app;
ALTER DEFAULT PRIVILEGES FOR ROLE openreply_manager IN SCHEMA openreply
  GRANT SELECT ON TABLES TO openreply_viewer;
ALTER DEFAULT PRIVILEGES FOR ROLE openreply_manager IN SCHEMA openreply
  GRANT SELECT, USAGE ON SEQUENCES TO openreply_app;

-- The first migration opens with `CREATE SCHEMA IF NOT EXISTS "public"`, and
-- Postgres checks CREATE on the database before it checks whether the schema
-- exists, so without this the very first `migrate deploy` fails with
-- "permission denied for database". Only that first run needs it: once the
-- web container has started and migrated, take it back:
--
--   REVOKE CREATE ON DATABASE <database> FROM openreply_manager;
--
-- Later deploys (and later migrations) run without it.
GRANT CREATE ON DATABASE :"db" TO openreply_manager;
