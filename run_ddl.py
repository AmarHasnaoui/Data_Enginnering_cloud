import os
import re
import glob
import snowflake.connector

account = f"{os.environ['SNOWFLAKE_ORG']}-{os.environ['SNOWFLAKE_ACCOUNT']}"

conn = snowflake.connector.connect(
    user      = "GITHUB_USER",
    password  = os.environ['SNOWFLAKE_PASSWORD'],
    account   = account,
    role      = "GITHUB_ROLE",
    warehouse = "TRANSFORM_WH"
)

def split_sql(sql):
    sql = re.sub(r'--[^\n]*', '', sql)       # strip single-line comments
    sql = re.sub(r'/\*.*?\*/', '', sql, flags=re.DOTALL)  # strip block comments
    return [s.strip() for s in sql.split(';') if s.strip()]

for file in sorted(glob.glob("Snowflake/DDL/*.sql")):
    print(f"Executing {file}...")
    with open(file, "r") as f:
        sql_content = f.read()
    skip_markers = [
        "CREATE OR REPLACE NETWORK RULE",  # Gold Postgres — ACCOUNTADMIN requis
        "CREATE OR REPLACE SECRET",        # Gold Postgres — ACCOUNTADMIN requis
        "CREATE POSTGRES INSTANCE",        # Gold Postgres — ACCOUNTADMIN requis
    ]
    if any(marker in sql_content.upper() for marker in skip_markers):
        print(f"  Skipping {file} (requires ACCOUNTADMIN - deploy manually)")
        continue
    for stmt in split_sql(sql_content):
        cur = conn.cursor()
        cur.execute(stmt)
        for row in cur:
            print(f"  => {row}")
        cur.close()

conn.close()
print("DDL deployment complete.")
