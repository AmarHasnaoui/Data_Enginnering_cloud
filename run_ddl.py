import os
import glob
import snowflake.connector

conn = snowflake.connector.connect(
    user      = "GITHUB_USER",
    password  = os.environ['SNOWFLAKE_PASSWORD'],
    account   = os.environ['SNOWFLAKE_ACCOUNT'],
    role      = "GITHUB_ROLE",
    warehouse = "TRANSFORM_WH"
)

for file in sorted(glob.glob("Snowflake/DDL/*.sql")):
    print(f"Executing {file}...")
    with open(file, "r") as f:
        sql_content = f.read()
    skip_markers = [
        "CREATE OR REPLACE STORAGE INTEGRATION",
        "CREATE OR REPLACE NETWORK RULE",
        "CREATE OR REPLACE SECRET",
    ]
    if any(marker in sql_content.upper() for marker in skip_markers):
        print(f"  Skipping {file} (requires ACCOUNTADMIN - deploy manually)")
        continue
    list_cursor = conn.execute_string(sql_content)
    for cursor in list_cursor:
        for row in cursor:
            print(f"  => {row}")

conn.close()
print("DDL deployment complete.")
