USE DATABASE BRONZE;
USE SCHEMA AIR_QUALITY;

CREATE FILE FORMAT IF NOT EXISTS my_csv_format
  TYPE                      = CSV
  FIELD_DELIMITER           = ';'
  SKIP_HEADER               = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF                   = ('', 'NULL')
  EMPTY_FIELD_AS_NULL       = TRUE;
