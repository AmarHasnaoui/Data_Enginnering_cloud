-- Export Gold vers S3 → RDS Postgres (lambda_rds_import).
-- Remplace l'export CSV par un calcul Snowpark (Python) qui lit les tables Silver
-- intermediate, calcule les datamarts Gold et exporte en Parquet.
-- La table GOLD_WATERMARK assure le traitement delta (seules les nouvelles dates).

USE DATABASE SILVER;
USE SCHEMA TRANSFORMATION;
USE ROLE TRANSFORM_ROLE;

-- Watermark delta : dernière date traitée par dataset
CREATE TABLE IF NOT EXISTS SILVER.TRANSFORMATION.GOLD_WATERMARK (
    dataset   VARCHAR(100) NOT NULL PRIMARY KEY,
    last_date DATE         NOT NULL DEFAULT '1970-01-01'::DATE
);

USE ROLE GITHUB_ROLE;
ALTER STORAGE INTEGRATION s3_integration
  SET STORAGE_ALLOWED_LOCATIONS = (
    's3://s3-projet-efrei/bronze/',
    's3://s3-projet-efrei/gold_export/'
  );

CREATE STAGE IF NOT EXISTS stage_gold_export
  URL                 = 's3://s3-projet-efrei/gold_export/'
  STORAGE_INTEGRATION = s3_integration;

USE ROLE TRANSFORM_ROLE;

-- Stored procedure Snowpark Python — remplace l'ancienne procédure SQL.
-- Lit les tables Silver intermediate, calcule les agrégats (anciennement dbt dm_*),
-- exporte en Parquet via copy_into_location (format override du stage).
CREATE OR REPLACE PROCEDURE SP_EXPORT_GOLD_TO_S3()
  RETURNS STRING
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.10'
  PACKAGES = ('snowflake-snowpark-python')
  HANDLER = 'run'
  EXECUTE AS CALLER
AS $$
import snowflake.snowpark.functions as F
from snowflake.snowpark.types import FloatType, StringType, StructField, StructType
from datetime import date

STAGE = '@SILVER.TRANSFORMATION.stage_gold_export'

def _get_wm(session, dataset):
    rows = session.sql(
        "SELECT COALESCE(TO_VARCHAR(last_date),'1970-01-01') "
        "FROM SILVER.TRANSFORMATION.GOLD_WATERMARK "
        f"WHERE dataset='{dataset}'"
    ).collect()
    return rows[0][0] if rows else '1970-01-01'

def _set_wm(session, dataset, last_date):
    session.sql(f"""
        MERGE INTO SILVER.TRANSFORMATION.GOLD_WATERMARK t
        USING (SELECT '{dataset}' AS d, '{last_date}'::DATE AS ld) s ON t.dataset=s.d
        WHEN MATCHED THEN UPDATE SET t.last_date=s.ld
        WHEN NOT MATCHED THEN INSERT (dataset,last_date) VALUES(s.d,s.ld)
    """).collect()

def _export(df, dataset, run_date):
    df.write.copy_into_location(
        f"{STAGE}/{dataset}/{run_date}.parquet",
        file_format_type="parquet",
        overwrite=True,
        single=True,
    )

def run(session):
    run_date = date.today().strftime("%Y%m%d")
    results = []

    # ── dm_air_quality_daily ─────────────────────────────────────────────────
    wm = _get_wm(session, 'dm_air_quality_daily')
    df = (
        session.table('SILVER.AIR_QUALITY.INT_AIR_QUALITY_IDF')
        .filter(F.col('date_mesure') > F.lit(wm))
        .filter(F.col('valeur').isNotNull())
        .group_by('code_site','nom_site','type_implantation','polluant',
                  'unite_mesure','date_mesure','latitude','longitude')
        .agg(F.avg('valeur').alias('valeur_moyenne'),
             F.max('valeur').alias('valeur_max'),
             F.min('valeur').alias('valeur_min'),
             F.count(F.lit(1)).alias('nb_mesures'),
             F.avg('taux_saisie').alias('taux_saisie_moyen'))
        .with_column('updated_at', F.current_timestamp().cast('timestamp_ntz'))
    )
    n = df.count()
    if n > 0:
        _export(df, 'dm_air_quality_daily', run_date)
        _set_wm(session, 'dm_air_quality_daily',
                df.agg(F.max('date_mesure')).collect()[0][0])
    results.append(f'dm_air_quality_daily:{n}')

    # ── dm_alertes_pollution ─────────────────────────────────────────────────
    # Seuils a 50% des valeurs OMS officielles pour capturer les cas intermediaires
    # visibles via le slider Streamlit (NO2 OMS=40->20, PM10 OMS=50->25, etc.)
    wm = _get_wm(session, 'dm_alertes_pollution')
    df_seuils = session.create_dataframe(
        [('NO2',20.,'µg/m3','OMS annuel'),('NO2',100.,'µg/m3','OMS horaire'),
         ('PM10',25.,'µg/m3','OMS journalier'),('PM2.5',12.,'µg/m3','OMS journalier'),
         ('O3',50.,'µg/m3','OMS 8h glissant'),('SO2',10.,'µg/m3','OMS 24h')],
        schema=StructType([StructField('s_polluant',StringType()),
                           StructField('seuil',FloatType()),
                           StructField('s_unite',StringType()),
                           StructField('type_seuil',StringType())])
    )
    df_aq = (
        session.table('SILVER.AIR_QUALITY.INT_AIR_QUALITY_IDF')
        .filter(F.col('date_mesure') > F.lit(wm))
        .filter(F.col('valeur').isNotNull())
        .group_by('code_site','nom_site','polluant','unite_mesure',
                  'date_mesure','latitude','longitude')
        .agg(F.max('valeur').alias('valeur_max'),
             F.avg('valeur').alias('valeur_moyenne'))
    )
    df = (
        df_aq.join(
            df_seuils,
            (F.col('polluant') == F.col('s_polluant')) &
            (F.col('unite_mesure') == F.col('s_unite'))
        )
        .filter(F.col('valeur_max') > F.col('seuil'))
        .select(
            F.col('code_site'), F.col('nom_site'), F.col('polluant'),
            F.col('date_mesure'),
            F.col('valeur_max').alias('valeur_max_journaliere'),
            F.col('valeur_moyenne'), F.col('unite_mesure'),
            F.col('seuil').alias('seuil_reglementaire'),
            F.col('type_seuil'),
            F.round(F.col('valeur_max') / F.col('seuil'), 2).alias('ratio_depassement'),
            F.col('latitude'), F.col('longitude'),
            F.current_timestamp().cast('timestamp_ntz').alias('updated_at'),
        )
    )
    n = df.count()
    if n > 0:
        _export(df, 'dm_alertes_pollution', run_date)
        _set_wm(session, 'dm_alertes_pollution',
                df.agg(F.max('date_mesure')).collect()[0][0])
    results.append(f'dm_alertes_pollution:{n}')

    # ── dm_velo_daily ────────────────────────────────────────────────────────
    wm = _get_wm(session, 'dm_velo_daily')
    df = (
        session.table('SILVER.MOBILITE.INT_VELO_DAILY')
        .filter(F.col('date_jour') > F.lit(wm))
        .select('compteur_id','compteur_nom','nom_site','date_jour',
                'total_passages_jour','nb_mesures_horaires','pic_horaire',
                'latitude','longitude')
        .with_column('updated_at', F.current_timestamp().cast('timestamp_ntz'))
    )
    n = df.count()
    if n > 0:
        _export(df, 'dm_velo_daily', run_date)
        _set_wm(session, 'dm_velo_daily',
                df.agg(F.max('date_jour')).collect()[0][0])
    results.append(f'dm_velo_daily:{n}')

    # ── dm_trafic_routier_daily ──────────────────────────────────────────────
    wm = _get_wm(session, 'dm_trafic_routier_daily')
    df = (
        session.table('SILVER.MOBILITE.INT_TRAFIC_DAILY')
        .filter(F.col('date_jour') > F.lit(wm))
        .select('arc_id','libelle_arc','date_jour','debit_moyen','debit_max',
                'taux_occupation_moyen','nb_heures_bloque','nb_heures_sature',
                'nb_heures_dense','nb_heures_fluide','nb_mesures',
                'latitude','longitude')
        .with_column('updated_at', F.current_timestamp().cast('timestamp_ntz'))
    )
    n = df.count()
    if n > 0:
        _export(df, 'dm_trafic_routier_daily', run_date)
        _set_wm(session, 'dm_trafic_routier_daily',
                df.agg(F.max('date_jour')).collect()[0][0])
    results.append(f'dm_trafic_routier_daily:{n}')

    # ── dm_smartcity_kpi_daily ───────────────────────────────────────────────
    wm = _get_wm(session, 'dm_smartcity_kpi_daily')
    df_air = (
        session.table('SILVER.AIR_QUALITY.INT_AIR_QUALITY_IDF')
        .filter(F.col('date_mesure') > F.lit(wm))
        .filter(F.col('valeur').isNotNull())
        .group_by('date_mesure')
        .agg(F.avg(F.when(F.col('polluant')==F.lit('NO2'),  F.col('valeur'))).alias('no2_moyen'),
             F.avg(F.when(F.col('polluant')==F.lit('PM10'), F.col('valeur'))).alias('pm10_moyen'),
             F.avg(F.when(F.col('polluant')==F.lit('PM2.5'),F.col('valeur'))).alias('pm25_moyen'),
             F.avg(F.when(F.col('polluant')==F.lit('O3'),   F.col('valeur'))).alias('o3_moyen'))
        .with_column_renamed('date_mesure','date_jour')
    )
    df_alertes = (
        session.table('SILVER.AIR_QUALITY.INT_AIR_QUALITY_IDF')
        .filter(F.col('date_mesure') > F.lit(wm))
        .filter(F.col('valeur') > F.lit(50))
        .group_by('date_mesure')
        .agg(F.count_distinct('code_site').alias('nb_stations_alerte'))
        .with_column_renamed('date_mesure','date_jour')
    )
    df_trafic = (
        session.table('SILVER.MOBILITE.INT_TRAFIC_DAILY')
        .filter(F.col('date_jour') > F.lit(wm))
        .group_by('date_jour')
        .agg(F.avg('debit_moyen').alias('debit_routier_moyen'),
             F.avg('taux_occupation_moyen').alias('taux_occupation_moyen'),
             F.sum('nb_heures_bloque').alias('total_heures_bloque'),
             F.count_distinct('arc_id').alias('nb_arcs_surveilles'))
    )
    df_velo = (
        session.table('SILVER.MOBILITE.INT_VELO_DAILY')
        .filter(F.col('date_jour') > F.lit(wm))
        .group_by('date_jour')
        .agg(F.sum('total_passages_jour').alias('total_velos'),
             F.count_distinct('compteur_id').alias('nb_compteurs_actifs'))
    )
    df = (df_air
          .join(df_alertes,'date_jour','left')
          .join(df_trafic, 'date_jour','left')
          .join(df_velo,   'date_jour','left')
          .with_column('updated_at', F.current_timestamp().cast('timestamp_ntz')))
    n = df.count()
    if n > 0:
        _export(df, 'dm_smartcity_kpi_daily', run_date)
        _set_wm(session, 'dm_smartcity_kpi_daily',
                df.agg(F.max('date_jour')).collect()[0][0])
    results.append(f'dm_smartcity_kpi_daily:{n}')

    # ── dm_zone_kpi_daily ────────────────────────────────────────────────────
    wm = _get_wm(session, 'dm_zone_kpi_daily')
    df_air_z = (
        session.table('SILVER.ZONES_ADMINISTRATIVES.INT_AIR_QUALITY_ZONED')
        .filter(F.col('date_jour') > F.lit(wm))
        .group_by('arrondissement_code','date_jour')
        .agg(F.avg(F.when(F.col('polluant')==F.lit('NO2'),  F.col('valeur_moyenne'))).alias('no2_moyen'),
             F.avg(F.when(F.col('polluant')==F.lit('PM10'), F.col('valeur_moyenne'))).alias('pm10_moyen'),
             F.avg(F.when(F.col('polluant')==F.lit('PM2.5'),F.col('valeur_moyenne'))).alias('pm25_moyen'),
             F.avg('valeur_moyenne').alias('pollution_indice_moyen'))
    )
    df_tr_z = (
        session.table('SILVER.ZONES_ADMINISTRATIVES.INT_TRAFIC_ZONED')
        .filter(F.col('date_jour') > F.lit(wm))
        .group_by('arrondissement_code','date_jour')
        .agg(F.avg('debit_moyen').alias('debit_routier_moyen'),
             F.avg('taux_occupation_moyen').alias('taux_occupation_moyen'),
             F.sum('nb_heures_bloque').alias('total_heures_bloque'))
    )
    df_vl_z = (
        session.table('SILVER.ZONES_ADMINISTRATIVES.INT_VELO_ZONED')
        .filter(F.col('date_jour') > F.lit(wm))
        .group_by('arrondissement_code','date_jour')
        .agg(F.sum('total_passages_jour').alias('total_velos'),
             F.count_distinct('compteur_id').alias('nb_compteurs_actifs'))
    )
    df_arr = session.table('SILVER.ZONES_ADMINISTRATIVES.STG_ARRONDISSEMENTS').select(
        'arrondissement_code','nom_arrondissement'
    )
    df_spine = (
        df_air_z.select('arrondissement_code','date_jour')
        .union(df_tr_z.select('arrondissement_code','date_jour'))
        .union(df_vl_z.select('arrondissement_code','date_jour'))
        .distinct()
    )
    df = (
        df_spine
        .join(df_arr,   'arrondissement_code','left')
        .join(df_air_z, ['arrondissement_code','date_jour'],'left')
        .join(df_tr_z,  ['arrondissement_code','date_jour'],'left')
        .join(df_vl_z,  ['arrondissement_code','date_jour'],'left')
        .with_column('ratio_mobilite_verte',
            F.when(
                (F.coalesce(F.col('total_velos'),F.lit(0))
                 + F.coalesce(F.col('debit_routier_moyen'),F.lit(0))) > F.lit(0),
                F.coalesce(F.col('total_velos'),F.lit(0))
                / (F.coalesce(F.col('total_velos'),F.lit(0))
                   + F.coalesce(F.col('debit_routier_moyen'),F.lit(0)))
            ).otherwise(F.lit(None))
        )
        .with_column('updated_at', F.current_timestamp().cast('timestamp_ntz'))
    )
    n = df.count()
    if n > 0:
        _export(df, 'dm_zone_kpi_daily', run_date)
        _set_wm(session, 'dm_zone_kpi_daily',
                df.agg(F.max('date_jour')).collect()[0][0])
    results.append(f'dm_zone_kpi_daily:{n}')

    # ── ref_arrondissements (référentiel statique, ré-export complet) ────────
    df = session.sql("""
        SELECT arrondissement_code, code_insee, nom_arrondissement,
               surface_m2, centroid_lat, centroid_lon,
               TO_VARCHAR(ST_ASGEOJSON(geometry)) AS geometry
        FROM SILVER.ZONES_ADMINISTRATIVES.STG_ARRONDISSEMENTS
    """)
    n = df.count()
    if n > 0:
        _export(df, 'ref_arrondissements', run_date)
    results.append(f'ref_arrondissements:{n}')

    return ' | '.join(results)
$$;

CREATE OR REPLACE TASK TASK_EXPORT_GOLD_TO_S3
  WAREHOUSE = TRANSFORM_WH
  AFTER SILVER.TRANSFORMATION.TASK_RUN_DBT_ALL
AS
  CALL SP_EXPORT_GOLD_TO_S3();

ALTER TASK TASK_EXPORT_GOLD_TO_S3 RESUME;
ALTER TASK TASK_RUN_DBT_ALL RESUME;

USE ROLE GITHUB_ROLE;