-- Datamart : agrégats journaliers par station et polluant (IDF uniquement)
{{
  config(
    materialized  = 'incremental',
    unique_key    = ['code_site', 'polluant', 'date_mesure'],
    on_schema_change = 'sync_all_columns'
  )
}}

SELECT
    code_site,
    nom_site,
    type_implantation,
    polluant,
    unite_mesure,
    date_mesure,
    latitude,
    longitude,
    AVG(valeur)            AS valeur_moyenne,
    MAX(valeur)            AS valeur_max,
    MIN(valeur)            AS valeur_min,
    COUNT(*)               AS nb_mesures,
    AVG(taux_saisie)       AS taux_saisie_moyen,
    CURRENT_TIMESTAMP()    AS updated_at
FROM {{ ref('int_air_quality_idf') }}
WHERE valeur IS NOT NULL

{% if is_incremental() %}
  AND date_mesure > (SELECT COALESCE(MAX(date_mesure), '1970-01-01') FROM {{ this }})
{% endif %}

GROUP BY code_site, nom_site, type_implantation, polluant, unite_mesure,
         date_mesure, latitude, longitude
