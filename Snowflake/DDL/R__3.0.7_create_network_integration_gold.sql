-- Prérequis réseau pour que la Snowpark Procedure atteigne l'instance Snowflake Postgres
-- DOIT être exécuté manuellement par ACCOUNTADMIN APRÈS création de l'instance Postgres
-- run_ddl.py ignore ce fichier (ACCOUNTADMIN requis)

USE ROLE ACCOUNTADMIN;

-- Remplacer <GOLD_PG_HOST> par l'hostname de l'instance Snowflake Postgres
-- Ex : abc123.snowflakecomputing-postgres.com
CREATE OR REPLACE NETWORK RULE GOLD_PG_NETWORK_RULE
  MODE       = EGRESS
  TYPE       = HOST_PORT
  VALUE_LIST = ('<GOLD_PG_HOST>:5432');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION GOLD_PG_ACCESS_INTEGRATION
  ALLOWED_NETWORK_RULES         = (GOLD_PG_NETWORK_RULE)
  ALLOWED_AUTHENTICATION_SECRETS = (SILVER.TRANSFORMATION.SECRET_GOLD_PG)
  ENABLED                       = TRUE;

-- Autoriser TRANSFORM_ROLE à utiliser cette intégration
GRANT USAGE ON INTEGRATION GOLD_PG_ACCESS_INTEGRATION TO ROLE TRANSFORM_ROLE;
