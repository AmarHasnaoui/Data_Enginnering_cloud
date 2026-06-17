-- Provisionne l'instance Snowflake Postgres servant de couche Gold
-- DOIT être exécuté manuellement par ACCOUNTADMIN (privilège CREATE POSTGRES INSTANCE)
-- run_ddl.py ignore ce fichier (ACCOUNTADMIN requis)
-- Feature en Public Preview (2026).
-- Doc : https://docs.snowflake.com/en/user-guide/snowflake-postgres/postgres-create-instance


-- COMPUTE_FAMILY : reporter la plus petite valeur de la table de référence des tailles
--   https://docs.snowflake.com/en/user-guide/snowflake-postgres/  (section sizes)
-- STORAGE_SIZE_GB : minimum autorisé = 10
CREATE POSTGRES INSTANCE IF NOT EXISTS GOLD_PG_INSTANCE
  COMPUTE_FAMILY           = STANDARD_M  -- /!\ à compléter depuis la doc des tailles
  STORAGE_SIZE_GB          = 10
  AUTHENTICATION_AUTHORITY = POSTGRES
  POSTGRES_VERSION         = 17
  HIGH_AVAILABILITY        = FALSE        -- FALSE = moins cher (pas de réplica)
  COMMENT                  = 'Couche Gold - serving layer API NovaSight';

-- IMPORTANT : la commande retourne host + 2 jeux d'identifiants à SAUVEGARDER
-- immédiatement (non récupérables ensuite) :
--   * snowflake_admin  -> admin complet  -> credentials du workflow Gold DDL (CREATE TABLE)
--   * application      -> accès standard -> credentials du SECRET (procédure export) + API FastAPI
SHOW POSTGRES INSTANCES LIKE 'GOLD_PG_INSTANCE';
