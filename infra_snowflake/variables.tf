# --- Snowflake Account Info ---
variable "snowflake_account" {}
variable "snowflake_user" {}
variable "snowflake_password" {}
variable "snowflake_role" {
  default = "GITHUB_ROLE"
}
variable "snowflake_org" {
  type        = string
  description = "Nom de l'organisation Snowflake"
}

# --- Users passwords ---
variable "ingest_user_password" {}
variable "transform_user_password" {}
variable "analyst_user_password" {}

# --- Databases ---
variable "bronze_db_name" {
  default = "BRONZE"
}
variable "silver_db_name" {
  default = "SILVER"
}

# --- Warehouses ---
variable "warehouse_size" {
  default = "XSMALL"
}
variable "transform_wh_size" {
  default = "XSMALL"
}
variable "query_wh_size" {
  default = "XSMALL"
}
