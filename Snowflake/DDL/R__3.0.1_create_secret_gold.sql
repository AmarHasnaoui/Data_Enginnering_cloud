-- Secret stockant les credentials de l'instance Snowflake Postgres (Gold)
-- DOIT être exécuté manuellement par ACCOUNTADMIN APRÈS création de l'instance Postgres
-- run_ddl.py ignore ce fichier (ACCOUNTADMIN requis + credentials sensibles)
USE DATABASE SILVER;
USE SCHEMA TRANSFORMATION;

-- Remplacer les valeurs par les credentials réels de l'instance Snowflake Postgres
-- Format JSON : host, port, database, user, password
CREATE OR REPLACE SECRET SECRET_GOLD_PG
  TYPE          = GENERIC_STRING
  SECRET_STRING = '{
    "host":     "<GOLD_PG_HOST>",
    "port":     5432,
    "database": "<GOLD_PG_DATABASE>",
    "user":     "<GOLD_PG_USER>",
    "password": "<GOLD_PG_PASSWORD>"
  }';

GRANT READ ON SECRET SECRET_GOLD_PG TO ROLE TRANSFORM_ROLE;
