# --- ROLES ---
resource "snowflake_account_role" "ingest_role" {
  name    = "INGEST_ROLE"
  comment = "Propriétaire BRONZE - crée schémas, tables, stages, pipes, COPY INTO"
}

resource "snowflake_account_role" "transform_role" {
  name    = "TRANSFORM_ROLE"
  comment = "Propriétaire SILVER - lit BRONZE, crée tables/vues/Tasks dbt"
}

resource "snowflake_account_role" "data_engineer" {
  name    = "DATA_ENGINEER"
  comment = "Lecture BRONZE + SILVER, requêtes console QUERY_WH"
}

resource "snowflake_account_role" "data_analyst" {
  name    = "DATA_ANALYST"
  comment = "Lecture seule sur SILVER, requêtes console QUERY_WH"
}

# --- ROLE → USER ---
resource "snowflake_grant_account_role" "ingest_role_to_user" {
  role_name = snowflake_account_role.ingest_role.name
  user_name = snowflake_user.ingest_user.name
}

resource "snowflake_grant_account_role" "transform_role_to_user" {
  role_name = snowflake_account_role.transform_role.name
  user_name = snowflake_user.transform_user.name
}

resource "snowflake_grant_account_role" "data_analyst_to_user" {
  role_name = snowflake_account_role.data_analyst.name
  user_name = snowflake_user.analyst_user.name
}

# --- ROLE → GITHUB_ROLE (CI/CD peut switcher vers les rôles opérationnels) ---
resource "snowflake_grant_account_role" "ingest_role_to_github" {
  role_name        = snowflake_account_role.ingest_role.name
  parent_role_name = "GITHUB_ROLE"
}

resource "snowflake_grant_account_role" "transform_role_to_github" {
  role_name        = snowflake_account_role.transform_role.name
  parent_role_name = "GITHUB_ROLE"
}

# --- INGEST_ROLE : owner de BRONZE ---
resource "snowflake_grant_ownership" "ingest_role_bronze_owner" {
  depends_on        = [snowflake_database.bronze_db]
  account_role_name = snowflake_account_role.ingest_role.name
  on {
    object_type = "DATABASE"
    object_name = snowflake_database.bronze_db.name
  }
}

# --- TRANSFORM_ROLE : owner de SILVER ---
resource "snowflake_grant_ownership" "transform_role_silver_owner" {
  depends_on        = [snowflake_database.silver_db]
  account_role_name = snowflake_account_role.transform_role.name
  on {
    object_type = "DATABASE"
    object_name = snowflake_database.silver_db.name
  }
}

# --- SYSADMIN : USAGE + CREATE SCHEMA sur BRONZE + SILVER (pour GITHUB_ROLE via héritage) ---
resource "snowflake_grant_privileges_to_account_role" "sysadmin_bronze_ddl" {
  depends_on        = [snowflake_grant_ownership.ingest_role_bronze_owner]
  account_role_name = "SYSADMIN"
  privileges        = ["USAGE", "CREATE SCHEMA"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.bronze_db.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "sysadmin_silver_ddl" {
  depends_on        = [snowflake_grant_ownership.transform_role_silver_owner]
  account_role_name = "SYSADMIN"
  privileges        = ["USAGE", "CREATE SCHEMA"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.silver_db.name
  }
}

# --- TRANSFORM_ROLE : USAGE sur BRONZE (après transfert de propriété) ---
resource "snowflake_grant_privileges_to_account_role" "transform_bronze_usage" {
  depends_on        = [snowflake_grant_ownership.ingest_role_bronze_owner]
  account_role_name = snowflake_account_role.transform_role.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.bronze_db.name
  }
}

# --- DATA_ENGINEER : USAGE sur BRONZE + SILVER ---
resource "snowflake_grant_privileges_to_account_role" "de_bronze_usage" {
  depends_on        = [snowflake_grant_ownership.ingest_role_bronze_owner]
  account_role_name = snowflake_account_role.data_engineer.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.bronze_db.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "de_silver_usage" {
  depends_on        = [snowflake_grant_ownership.transform_role_silver_owner]
  account_role_name = snowflake_account_role.data_engineer.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.silver_db.name
  }
}

# --- DATA_ANALYST : USAGE sur SILVER uniquement ---
resource "snowflake_grant_privileges_to_account_role" "analyst_silver_usage" {
  depends_on        = [snowflake_grant_ownership.transform_role_silver_owner]
  account_role_name = snowflake_account_role.data_analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.silver_db.name
  }
}

# --- WAREHOUSE GRANTS ---
resource "snowflake_grant_privileges_to_account_role" "ingest_role_ingest_wh" {
  depends_on        = [snowflake_warehouse.ingest_wh]
  account_role_name = snowflake_account_role.ingest_role.name
  privileges        = ["USAGE", "OPERATE", "MONITOR"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.ingest_wh.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transform_role_transform_wh" {
  depends_on        = [snowflake_warehouse.transform_wh]
  account_role_name = snowflake_account_role.transform_role.name
  privileges        = ["USAGE", "OPERATE", "MONITOR"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.transform_wh.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "de_query_wh" {
  depends_on        = [snowflake_warehouse.query_wh]
  account_role_name = snowflake_account_role.data_engineer.name
  privileges        = ["USAGE", "OPERATE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.query_wh.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_query_wh" {
  depends_on        = [snowflake_warehouse.query_wh]
  account_role_name = snowflake_account_role.data_analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.query_wh.name
  }
}
