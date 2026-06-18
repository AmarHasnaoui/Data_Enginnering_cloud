-- Datamart : dépassements de seuils réglementaires OMS par station et jour
{{
  config(
    materialized  = 'incremental',
    unique_key    = ['code_site', 'polluant', 'date_mesure'],
    on_schema_change = 'sync_all_columns'
  )
}}

WITH seuils AS (
    SELECT * FROM (VALUES
        ('NO2',  40.0,  'µg/m3', 'OMS annuel'),
        ('NO2', 200.0,  'µg/m3', 'OMS horaire'),
        ('PM10', 50.0,  'µg/m3', 'OMS journalier'),
        ('PM2.5',25.0,  'µg/m3', 'OMS journalier'),
        ('O3',  100.0,  'µg/m3', 'OMS 8h glissant'),
        ('SO2',  20.0,  'µg/m3', 'OMS 24h')
    ) AS t(polluant, seuil, unite, type_seuil)
)

SELECT
    aq.code_site,
    aq.nom_site,
    aq.polluant,
    aq.date_mesure,
    aq.valeur_max                       AS valeur_max_journaliere,
    aq.valeur_moyenne,
    aq.unite_mesure,
    s.seuil                             AS seuil_reglementaire,
    s.type_seuil,
    ROUND(aq.valeur_max / s.seuil, 2)  AS ratio_depassement,
    aq.latitude,
    aq.longitude,
    CURRENT_TIMESTAMP()                 AS updated_at
FROM {{ ref('dm_air_quality_daily') }} AS aq
JOIN seuils AS s
  ON aq.polluant    = s.polluant
 AND aq.unite_mesure = s.unite
WHERE aq.valeur_max > s.seuil

{% if is_incremental() %}
  AND aq.date_mesure > (SELECT COALESCE(MAX(date_mesure), '1970-01-01') FROM {{ this }})
{% endif %}
