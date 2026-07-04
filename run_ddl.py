import os
import glob
import snowflake.connector

account        = f"{os.environ['SNOWFLAKE_ORG']}-{os.environ['SNOWFLAKE_ACCOUNT']}"
aws_account_id = os.environ.get('AWS_ACCOUNT_ID', '')

conn = snowflake.connector.connect(
    user      = "GITHUB_USER",
    password  = os.environ['SNOWFLAKE_PASSWORD'],
    account   = account,
    role      = "GITHUB_ROLE",
    warehouse = "TRANSFORM_WH"
)

for file in sorted(glob.glob("Snowflake/DDL/*.sql")):
    print(f"Executing {file}...")
    with open(file, "r") as f:
        sql_content = f.read()
    sql_content = sql_content.replace('${AWS_ACCOUNT_ID}', aws_account_id)
    list_cursor = conn.execute_string(sql_content, remove_comments=True)
    for cursor in list_cursor:
        for row in cursor:
            print(f"  => {row}")

conn.close()
print("DDL deployment complete.")
