import {
  to = snowflake_database.bronze_db
  id = "BRONZE"
}

import {
  to = snowflake_database.silver_db
  id = "SILVER"
}

import {
  to = snowflake_warehouse.ingest_wh
  id = "INGEST_WH"
}

import {
  to = snowflake_warehouse.transform_wh
  id = "TRANSFORM_WH"
}

import {
  to = snowflake_warehouse.query_wh
  id = "QUERY_WH"
}

import {
  to = snowflake_account_role.ingest_role
  id = "INGEST_ROLE"
}

import {
  to = snowflake_account_role.transform_role
  id = "TRANSFORM_ROLE"
}

import {
  to = snowflake_account_role.data_engineer
  id = "DATA_ENGINEER"
}

import {
  to = snowflake_account_role.data_analyst
  id = "DATA_ANALYST"
}

import {
  to = snowflake_user.ingest_user
  id = "INGEST_USER"
}

import {
  to = snowflake_user.transform_user
  id = "TRANSFORM_USER"
}

import {
  to = snowflake_user.analyst_user
  id = "ANALYST_USER"
}
