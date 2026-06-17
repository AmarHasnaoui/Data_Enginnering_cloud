# --- DATABASES ---
resource "snowflake_database" "bronze_db" {
  name    = "BRONZE"
  comment = "Raw landing database - données brutes depuis S3 via Snowpipe"
}

resource "snowflake_database" "silver_db" {
  name    = "SILVER"
  comment = "Transformed database - données normalisées via dbt"
}

# --- WAREHOUSES ---
resource "snowflake_warehouse" "ingest_wh" {
  name                                = "INGEST_WH"
  warehouse_size                      = var.warehouse_size
  auto_suspend                        = 60
  auto_resume                         = true
  enable_query_acceleration           = false
  query_acceleration_max_scale_factor = 0
  comment                             = "Warehouse pour ingestion Snowpipe"
}

resource "snowflake_warehouse" "transform_wh" {
  name                                = "TRANSFORM_WH"
  warehouse_size                      = var.transform_wh_size
  auto_suspend                        = 60
  auto_resume                         = true
  enable_query_acceleration           = false
  query_acceleration_max_scale_factor = 0
  comment                             = "Warehouse pour transformations dbt et Snowflake Tasks"
}

resource "snowflake_warehouse" "query_wh" {
  name                                = "QUERY_WH"
  warehouse_size                      = var.query_wh_size
  auto_suspend                        = 60
  auto_resume                         = true
  enable_query_acceleration           = false
  query_acceleration_max_scale_factor = 0
  comment                             = "Warehouse console - requêtes ad-hoc DA et DE"
}

# --- USERS ---
resource "snowflake_user" "ingest_user" {
  name              = "INGEST_USER"
  login_name        = "ingest_user"
  password          = var.ingest_user_password
  default_role      = snowflake_account_role.ingest_role.name
  default_warehouse = snowflake_warehouse.ingest_wh.name
  comment           = "User applicatif - ingestion Snowpipe"
}

resource "snowflake_user" "transform_user" {
  name              = "TRANSFORM_USER"
  login_name        = "transform_user"
  password          = var.transform_user_password
  default_role      = snowflake_account_role.transform_role.name
  default_warehouse = snowflake_warehouse.transform_wh.name
  comment           = "User dbt - transformations SILVER via Tasks"
}

resource "snowflake_user" "analyst_user" {
  name              = "ANALYST_USER"
  login_name        = "analyst_user"
  password          = var.analyst_user_password
  default_role      = snowflake_account_role.data_analyst.name
  default_warehouse = snowflake_warehouse.query_wh.name
  comment           = "User lecture seule sur SILVER"
}
