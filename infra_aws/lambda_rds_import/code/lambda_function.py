import os
import psycopg2

# Clé S3 (chemin fixe, écrasé chaque jour par la Task Snowflake) → table RDS cible.
TABLE_KEYS = {
    "gold_export/dm_air_quality_daily.csv":    "dm_air_quality_daily",
    "gold_export/dm_alertes_pollution.csv":    "dm_alertes_pollution",
    "gold_export/dm_velo_daily.csv":           "dm_velo_daily",
    "gold_export/dm_trafic_routier_daily.csv": "dm_trafic_routier_daily",
    "gold_export/dm_smartcity_kpi_daily.csv":  "dm_smartcity_kpi_daily",
    "gold_export/dm_zone_kpi_daily.csv":       "dm_zone_kpi_daily",
    "gold_export/ref_arrondissements.csv":     "ref_arrondissements",
}


def get_pg_conn():
    print(f"Connexion à {os.environ['RDS_HOST']}:{os.environ.get('RDS_PORT', 5432)}...")
    conn = psycopg2.connect(
        host=os.environ["RDS_HOST"],
        port=int(os.environ.get("RDS_PORT", 5432)),
        dbname=os.environ["RDS_DATABASE"],
        user=os.environ["RDS_USER"],
        password=os.environ["RDS_PASSWORD"],
        sslmode="require",
        connect_timeout=10,
        options="-c statement_timeout=30000",
    )
    print("Connecté.")
    return conn


def ensure_setup(pg_conn):
    print("CREATE EXTENSION aws_s3...")
    with pg_conn.cursor() as cur:
        cur.execute("CREATE EXTENSION IF NOT EXISTS aws_s3 CASCADE;")
    pg_conn.commit()
    print("Extension OK.")


def import_table(pg_conn, pg_table, bucket, key, region):
    with pg_conn.cursor() as cur:
        print(f"TRUNCATE {pg_table}...")
        cur.execute(f"TRUNCATE TABLE {pg_table};")
        print(f"Import depuis s3://{bucket}/{key}...")
        cur.execute(
            "SELECT aws_s3.table_import_from_s3("
            "%s, '', '(format csv, header true, null ''\\N'')', "
            "aws_commons.create_s3_uri(%s, %s, %s));",
            (pg_table, bucket, key, region),
        )
    pg_conn.commit()
    print("Import OK.")


def lambda_handler(event, context):
    bucket = event["detail"]["bucket"]["name"]
    key    = event["detail"]["object"]["key"]

    pg_table = TABLE_KEYS.get(key)
    if not pg_table:
        print(f"Clé ignorée (non mappée) : {key}")
        return {"statusCode": 200, "body": "ignored"}

    region = os.environ.get("AWS_REGION", "eu-west-3")
    pg_conn = get_pg_conn()
    try:
        ensure_setup(pg_conn)
        import_table(pg_conn, pg_table, bucket, key, region)
        print(f"[{pg_table}] import depuis s3://{bucket}/{key} terminé")
    finally:
        pg_conn.close()

    return {"statusCode": 200, "body": f"{pg_table} importé"}
