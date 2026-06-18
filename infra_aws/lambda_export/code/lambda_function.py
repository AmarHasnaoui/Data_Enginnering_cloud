import os
import snowflake.connector
import psycopg2
from psycopg2.extras import execute_values
from datetime import date, timedelta

TABLES = [
    {
        "sf_table": "SILVER.AIR_QUALITY.DM_AIR_QUALITY_DAILY",
        "pg_table": "dm_air_quality_daily",
        "date_col": "DATE_MESURE",
        "pk":       ["code_site", "polluant", "date_mesure"],
    },
    {
        "sf_table": "SILVER.AIR_QUALITY.DM_ALERTES_POLLUTION",
        "pg_table": "dm_alertes_pollution",
        "date_col": "DATE_MESURE",
        "pk":       ["code_site", "polluant", "date_mesure"],
    },
    {
        "sf_table": "SILVER.MOBILITE.DM_VELO_DAILY",
        "pg_table": "dm_velo_daily",
        "date_col": "DATE_JOUR",
        "pk":       ["compteur_id", "date_jour"],
    },
    {
        "sf_table": "SILVER.MOBILITE.DM_TRAFIC_ROUTIER_DAILY",
        "pg_table": "dm_trafic_routier_daily",
        "date_col": "DATE_JOUR",
        "pk":       ["arc_id", "date_jour"],
    },
    {
        "sf_table": "SILVER.SMARTCITY.DM_SMARTCITY_KPI_DAILY",
        "pg_table": "dm_smartcity_kpi_daily",
        "date_col": "DATE_JOUR",
        "pk":       ["date_jour"],
    },
    {
        "sf_table": "SILVER.ZONES_ADMINISTRATIVES.DM_ZONE_KPI_DAILY",
        "pg_table": "dm_zone_kpi_daily",
        "date_col": "DATE_JOUR",
        "pk":       ["arrondissement_code", "date_jour"],
    },
]

# Référentiels statiques : pas de filtre par date, sync complet à chaque run
# (peu de lignes — 20 arrondissements — donc négligeable en coût).
REFERENCE_TABLES = [
    {
        "sf_table": "SILVER.ZONES_ADMINISTRATIVES.STG_ARRONDISSEMENTS",
        "pg_table": "ref_arrondissements",
        "pk":       ["arrondissement_code"],
    },
]

CREATE_STATEMENTS = {
    "dm_air_quality_daily": """
        CREATE TABLE IF NOT EXISTS dm_air_quality_daily (
            code_site         TEXT,
            nom_site          TEXT,
            type_implantation TEXT,
            polluant          TEXT,
            unite_mesure      TEXT,
            date_mesure       DATE,
            latitude          FLOAT,
            longitude         FLOAT,
            valeur_moyenne    FLOAT,
            valeur_max        FLOAT,
            valeur_min        FLOAT,
            nb_mesures        INTEGER,
            taux_saisie_moyen FLOAT,
            updated_at        TIMESTAMP,
            PRIMARY KEY (code_site, polluant, date_mesure)
        )
    """,
    "dm_alertes_pollution": """
        CREATE TABLE IF NOT EXISTS dm_alertes_pollution (
            code_site              TEXT,
            nom_site               TEXT,
            polluant               TEXT,
            date_mesure            DATE,
            valeur_max_journaliere FLOAT,
            valeur_moyenne         FLOAT,
            unite_mesure           TEXT,
            seuil_reglementaire    FLOAT,
            type_seuil             TEXT,
            ratio_depassement      FLOAT,
            latitude               FLOAT,
            longitude              FLOAT,
            updated_at             TIMESTAMP,
            PRIMARY KEY (code_site, polluant, date_mesure)
        )
    """,
    "dm_velo_daily": """
        CREATE TABLE IF NOT EXISTS dm_velo_daily (
            compteur_id         TEXT,
            compteur_nom        TEXT,
            nom_site            TEXT,
            date_jour           DATE,
            total_passages_jour INTEGER,
            nb_mesures_horaires INTEGER,
            pic_horaire         INTEGER,
            latitude            FLOAT,
            longitude           FLOAT,
            updated_at          TIMESTAMP,
            PRIMARY KEY (compteur_id, date_jour)
        )
    """,
    "dm_trafic_routier_daily": """
        CREATE TABLE IF NOT EXISTS dm_trafic_routier_daily (
            arc_id                TEXT,
            libelle_arc           TEXT,
            date_jour             DATE,
            debit_moyen           FLOAT,
            debit_max             FLOAT,
            taux_occupation_moyen FLOAT,
            nb_heures_bloque      INTEGER,
            nb_heures_sature      INTEGER,
            nb_heures_dense       INTEGER,
            nb_heures_fluide      INTEGER,
            nb_mesures            INTEGER,
            latitude              FLOAT,
            longitude             FLOAT,
            updated_at            TIMESTAMP,
            PRIMARY KEY (arc_id, date_jour)
        )
    """,
    "dm_smartcity_kpi_daily": """
        CREATE TABLE IF NOT EXISTS dm_smartcity_kpi_daily (
            date_jour             DATE PRIMARY KEY,
            no2_moyen             FLOAT,
            pm10_moyen            FLOAT,
            pm25_moyen            FLOAT,
            o3_moyen              FLOAT,
            nb_stations_alerte    INTEGER,
            debit_routier_moyen   FLOAT,
            taux_occupation_moyen FLOAT,
            total_heures_bloque   INTEGER,
            nb_arcs_surveilles    INTEGER,
            total_velos           INTEGER,
            nb_compteurs_actifs   INTEGER,
            updated_at            TIMESTAMP
        )
    """,
    "dm_zone_kpi_daily": """
        CREATE TABLE IF NOT EXISTS dm_zone_kpi_daily (
            arrondissement_code   INTEGER,
            nom_arrondissement    TEXT,
            date_jour             DATE,
            no2_moyen             FLOAT,
            pm10_moyen            FLOAT,
            pm25_moyen            FLOAT,
            pollution_indice_moyen FLOAT,
            debit_routier_moyen   FLOAT,
            taux_occupation_moyen FLOAT,
            total_heures_bloque   INTEGER,
            total_velos           INTEGER,
            nb_compteurs_actifs   INTEGER,
            ratio_mobilite_verte  FLOAT,
            updated_at            TIMESTAMP,
            PRIMARY KEY (arrondissement_code, date_jour)
        )
    """,
    "ref_arrondissements": """
        CREATE TABLE IF NOT EXISTS ref_arrondissements (
            arrondissement_code INTEGER PRIMARY KEY,
            code_insee          TEXT,
            nom_arrondissement  TEXT,
            surface_m2          FLOAT,
            centroid_lat        FLOAT,
            centroid_lon        FLOAT,
            geometry            TEXT
        )
    """,
}


def get_sf_conn():
    account = f"{os.environ['SNOWFLAKE_ORG']}-{os.environ['SNOWFLAKE_ACCOUNT']}"
    return snowflake.connector.connect(
        account=account,
        user="TRANSFORM_USER",
        password=os.environ["TRANSFORM_USER_PASSWORD"],
        role="TRANSFORM_ROLE",
        warehouse="TRANSFORM_WH",
    )


def get_pg_conn():
    return psycopg2.connect(
        host=os.environ["RDS_HOST"],
        port=int(os.environ.get("RDS_PORT", 5432)),
        dbname=os.environ["RDS_DATABASE"],
        user=os.environ["RDS_USER"],
        password=os.environ["RDS_PASSWORD"],
        sslmode="require",
        connect_timeout=10,
    )


def ensure_tables(pg_conn):
    with pg_conn.cursor() as cur:
        for sql in CREATE_STATEMENTS.values():
            cur.execute(sql)
    pg_conn.commit()


def upsert_rows(pg_conn, pg_table, pk, sf_cur, rows):
    if not rows:
        return 0
    cols = [desc[0].lower() for desc in sf_cur.description]
    non_pk = [c for c in cols if c not in pk]
    update_set = ", ".join(f"{c} = EXCLUDED.{c}" for c in non_pk)

    insert_sql = (
        f"INSERT INTO {pg_table} ({', '.join(cols)}) VALUES %s "
        f"ON CONFLICT ({', '.join(pk)}) DO UPDATE SET {update_set}"
    )
    with pg_conn.cursor() as cur:
        execute_values(cur, insert_sql, rows)
    pg_conn.commit()
    return len(rows)


def export_table(sf_conn, pg_conn, table_def, target_date):
    sf_cur = sf_conn.cursor()
    sf_cur.execute(
        f"SELECT * FROM {table_def['sf_table']} WHERE {table_def['date_col']} = %s",
        (target_date,),
    )
    rows = sf_cur.fetchall()
    return upsert_rows(pg_conn, table_def["pg_table"], table_def["pk"], sf_cur, rows)


def export_reference_table(sf_conn, pg_conn, table_def):
    sf_cur = sf_conn.cursor()
    sf_cur.execute(f"SELECT * FROM {table_def['sf_table']}")
    rows = sf_cur.fetchall()
    return upsert_rows(pg_conn, table_def["pg_table"], table_def["pk"], sf_cur, rows)


def lambda_handler(event, context):
    target_date = event.get("date") or str(date.today() - timedelta(days=1))
    print(f"Export Silver → RDS pour la date : {target_date}")

    sf_conn = get_sf_conn()
    pg_conn = get_pg_conn()
    results = {}

    try:
        ensure_tables(pg_conn)
        for table_def in TABLES:
            try:
                n = export_table(sf_conn, pg_conn, table_def, target_date)
                results[table_def["pg_table"]] = f"{n} rows"
                print(f"[{table_def['pg_table']}] {n} lignes upsertées")
            except Exception as e:
                results[table_def["pg_table"]] = f"ERROR: {e}"
                print(f"[{table_def['pg_table']}] ERREUR: {e}")

        for table_def in REFERENCE_TABLES:
            try:
                n = export_reference_table(sf_conn, pg_conn, table_def)
                results[table_def["pg_table"]] = f"{n} rows (référentiel)"
                print(f"[{table_def['pg_table']}] {n} lignes upsertées (référentiel)")
            except Exception as e:
                results[table_def["pg_table"]] = f"ERROR: {e}"
                print(f"[{table_def['pg_table']}] ERREUR: {e}")
    finally:
        sf_conn.close()
        pg_conn.close()

    print("====== EXPORT TERMINÉ ======", results)
    return {"statusCode": 200, "body": results, "date": target_date}
