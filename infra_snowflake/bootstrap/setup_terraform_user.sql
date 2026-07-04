-- Bootstrap CI/CD : à exécuter UNE SEULE FOIS en ACCOUNTADMIN via une worksheet Snowflake
-- Remplacer <PASSWORD> par un mot de passe fort avant exécution

USE ROLE ACCOUNTADMIN;

-- ── Rôle CI/CD ────────────────────────────────────────────────────────────────
CREATE ROLE IF NOT EXISTS GITHUB_ROLE
  COMMENT = 'Service account CI/CD — Terraform + DDL NovaSight';

-- Place GITHUB_ROLE sous SYSADMIN dans la hiérarchie
-- → ACCOUNTADMIN peut gérer tous les objets créés par GITHUB_ROLE (pas de cycle)
GRANT ROLE GITHUB_ROLE TO ROLE SYSADMIN;

-- Privilèges compte-niveau nécessaires à Terraform + DDL
GRANT CREATE DATABASE             ON ACCOUNT TO ROLE GITHUB_ROLE;
GRANT CREATE WAREHOUSE            ON ACCOUNT TO ROLE GITHUB_ROLE;
GRANT CREATE USER                 ON ACCOUNT TO ROLE GITHUB_ROLE;
GRANT CREATE ROLE                 ON ACCOUNT TO ROLE GITHUB_ROLE;
GRANT MANAGE GRANTS               ON ACCOUNT TO ROLE GITHUB_ROLE;
GRANT CREATE INTEGRATION          ON ACCOUNT TO ROLE GITHUB_ROLE; -- Storage Integration S3 + Snowpipe

-- ── User de service ───────────────────────────────────────────────────────────
CREATE USER IF NOT EXISTS GITHUB_USER
  LOGIN_NAME           = 'github_user'
  PASSWORD             = '<PASSWORD>'
  DEFAULT_ROLE         = GITHUB_ROLE
  DEFAULT_WAREHOUSE    = 'COMPUTE_WH'
  MUST_CHANGE_PASSWORD = FALSE
  COMMENT              = 'Service account CI/CD GitHub Actions';

GRANT ROLE GITHUB_ROLE TO USER GITHUB_USER;
