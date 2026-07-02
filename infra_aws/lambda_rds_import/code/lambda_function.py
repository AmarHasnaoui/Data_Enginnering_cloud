import io
import os

import boto3
import psycopg2
import psycopg2.extras
import pyarrow.parquet as pq

# Conflict keys par table (PRIMARY KEY PostgreSQL → ON CONFLICT)
DATASET_CONFLICT = {
    "dm_air_quality_daily":    ["code_site", "polluant", "date_mesure"],
    "dm_alertes_pollution":    ["code_site", "polluant", "date_mesure"],
    "dm_velo_daily":           ["compteur_id", "date_jour"],
    "dm_trafic_routier_daily": ["arc_id", "date_jour"],
    "dm_smartcity_kpi_daily":  ["date_jour"],
    "dm_zone_kpi_daily":       ["arrondissement_code", "date_jour"],
    "ref_arrondissements":     ["arrondissement_code"],
}


def get_pg_conn():
    return psycopg2.connect(
        host=os.environ["RDS_HOST"],
        port=int(os.environ.get("RDS_PORT", 5432)),
        dbname=os.environ["RDS_DATABASE"],
        user=os.environ["RDS_USER"],
        password=os.environ["RDS_PASSWORD"],
        sslmode="require",
        connect_timeout=10,
        options="-c statement_timeout=30000",
    )


def read_parquet_from_s3(bucket: str, key: str) -> list[dict]:
    s3 = boto3.client("s3")
    obj = s3.get_object(Bucket=bucket, Key=key)
    buf = io.BytesIO(obj["Body"].read())
    return pq.read_table(buf).to_pylist()


def upsert(conn, table: str, rows: list[dict], conflict_cols: list[str]) -> None:
    if not rows:
        return
    cols = list(rows[0].keys())
    update_cols = [c for c in cols if c not in conflict_cols]

    col_names      = ", ".join(f'"{c}"' for c in cols)
    conflict_target = ", ".join(f'"{c}"' for c in conflict_cols)
    update_set     = ", ".join(f'"{c}" = EXCLUDED."{c}"' for c in update_cols)

    sql = (
        f'INSERT INTO {table} ({col_names}) VALUES %s '
        f'ON CONFLICT ({conflict_target}) DO UPDATE SET {update_set}'
    )
    data = [tuple(row.get(c) for c in cols) for row in rows]

    with conn.cursor() as cur:
        psycopg2.extras.execute_values(cur, sql, data)
    conn.commit()


def lambda_handler(event, context):
    bucket = event["detail"]["bucket"]["name"]
    key    = event["detail"]["object"]["key"]

    # key = "gold_export/<dataset>/<run_date>/data_0_0_0.parquet"
    parts   = key.split("/")
    dataset = parts[1] if len(parts) >= 2 else None

    conflict_cols = DATASET_CONFLICT.get(dataset)
    if conflict_cols is None:
        print(f"Clé ignorée (dataset non mappé) : {key}")
        return {"statusCode": 200, "body": "ignored"}

    rows   = read_parquet_from_s3(bucket, key)
    conn   = get_pg_conn()
    try:
        upsert(conn, dataset, rows, conflict_cols)
        print(f"[{dataset}] {len(rows)} lignes upsertées depuis s3://{bucket}/{key}")
    finally:
        conn.close()

    return {"statusCode": 200, "body": f"{dataset}: {len(rows)} rows"}