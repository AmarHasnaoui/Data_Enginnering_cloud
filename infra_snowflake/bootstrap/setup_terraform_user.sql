-- Bootstrap Terraform : à exécuter UNE SEULE FOIS en ACCOUNTADMIN via une worksheet Snowflake
-- Crée un utilisateur de service dédié à Terraform avec le minimum de privilèges.
-- Ne jamais versionner ce fichier avec les mots de passe remplis.
-- Après exécution : renseigner SNOWFLAKE_USER=TERRAFORM_USER et SNOWFLAKE_PASSWORD=<password>
-- dans les GitHub Secrets du repository.

USE ROLE ACCOUNTADMIN;

-- Rôle dédié Terraform : hérite de SYSADMIN (databases, warehouses)
-- et SECURITYADMIN (roles, users, grants) — sans les privilèges account-level d'ACCOUNTADMIN
CREATE ROLE IF NOT EXISTS GITHUB_ROLE
  COMMENT = 'Rôle de service Terraform - moindre privilège (SYSADMIN + SECURITYADMIN)';

GRANT ROLE SYSADMIN     TO ROLE GITHUB_ROLE;
GRANT ROLE SECURITYADMIN TO ROLE GITHUB_ROLE;

-- Utilisateur de service Terraform
-- Remplacer <TERRAFORM_USER_PASSWORD> par un mot de passe fort AVANT exécution
CREATE USER IF NOT EXISTS GITHUB_USER
  LOGIN_NAME        = 'github_user'
  PASSWORD          = 'xxxxxx'
  DEFAULT_ROLE      = GITHUB_ROLE
  DEFAULT_WAREHOUSE = 'COMPUTE_WH'
  MUST_CHANGE_PASSWORD = FALSE
  COMMENT           = 'Service account - CI/CD GitHub Actions';

GRANT ROLE GITHUB_ROLE TO USER GITHUB_USER;
