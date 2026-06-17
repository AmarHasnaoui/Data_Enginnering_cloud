-- Snowpark Python Procedure : export incrémental SILVER → Snowflake Postgres (Gold)
-- Déclenchée par TASK_EXPORT_TO_GOLD après TASK_RUN_DBT_ALL
USE DATABASE SILVER;
USE SCHEMA TRANSFORMATION;

CREATE OR REPLACE PROCEDURE PROC_EXPORT_SILVER_TO_GOLD()
  RETURNS VARCHAR
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  PACKAGES = ('snowflake-snowpark-python', 'psycopg2-binary')
  HANDLER = 'export_silver_to_gold'
  EXTERNAL_ACCESS_INTEGRATIONS = (GOLD_PG_ACCESS_INTEGRATION)
  SECRETS = ('pg_creds' = SECRET_GOLD_PG)
AS
$$
import _snowflake
import psycopg2
import json

TABLES_CONFIG = [
    {
        'sf_table' : 'SILVER.AIR_QUALITY.DM_AIR_QUALITY_DAILY',
        'pg_table' : 'dm_air_quality_daily',
        'pk_cols'  : ['code_site', 'polluant', 'date_mesure'],
    },
    {
        'sf_table' : 'SILVER.AIR_QUALITY.DM_ALERTES_POLLUTION',
        'pg_table' : 'dm_alertes_pollution',
        'pk_cols'  : ['code_site', 'polluant', 'date_mesure'],
    },
    {
        'sf_table' : 'SILVER.AIR_QUALITY.DM_STATIONS',
        'pg_table' : 'dm_stations_air',
        'pk_cols'  : ['code_site'],
    },
    {
        'sf_table' : 'SILVER.MOBILITE.DM_VELO_DAILY',
        'pg_table' : 'dm_velo_daily',
        'pk_cols'  : ['compteur_id', 'date_jour'],
    },
    {
        'sf_table' : 'SILVER.MOBILITE.DM_TRAFIC_ROUTIER_DAILY',
        'pg_table' : 'dm_trafic_routier_daily',
        'pk_cols'  : ['arc_id', 'date_jour'],
    },
    {
        'sf_table' : 'SILVER.MOBILITE.DM_STATIONS_VELIB',
        'pg_table' : 'dm_stations_velib',
        'pk_cols'  : ['stationcode', 'date_jour'],
    },
    {
        'sf_table' : 'SILVER.SMARTCITY.DM_SMARTCITY_KPI_DAILY',
        'pg_table' : 'dm_smartcity_kpi_daily',
        'pk_cols'  : ['date_jour'],
    },
]


def _upsert(cursor, pg_table: str, pk_cols: list, columns: list, rows: list):
    """INSERT ... ON CONFLICT (pk) DO UPDATE SET toutes les colonnes non-PK."""
    non_pk = [c for c in columns if c not in pk_cols]
    update_clause = ', '.join(f'{c} = EXCLUDED.{c}' for c in non_pk)
    conflict_target = ', '.join(pk_cols)

    sql = f"""
        INSERT INTO {pg_table} ({', '.join(columns)})
        VALUES ({', '.join(['%s'] * len(columns))})
        ON CONFLICT ({conflict_target})
        DO UPDATE SET {update_clause}
    """
    cursor.executemany(sql, rows)


def export_silver_to_gold(session) -> str:
    creds  = json.loads(_snowflake.get_generic_secret_string('pg_creds'))
    conn   = psycopg2.connect(
        host     = creds['host'],
        port     = creds.get('port', 5432),
        dbname   = creds['database'],
        user     = creds['user'],
        password = creds['password'],
        sslmode  = 'require',
    )

    cursor  = conn.cursor()
    summary = {}

    try:
        for cfg in TABLES_CONFIG:
            df      = session.table(cfg['sf_table'])
            columns = [f.name.lower() for f in df.schema.fields]
            rows    = [tuple(r) for r in df.collect()]

            if rows:
                _upsert(cursor, cfg['pg_table'], cfg['pk_cols'], columns, rows)

            summary[cfg['pg_table']] = len(rows)

        conn.commit()
    except Exception as exc:
        conn.rollback()
        raise exc
    finally:
        cursor.close()
        conn.close()

    return json.dumps(summary)
$$;
