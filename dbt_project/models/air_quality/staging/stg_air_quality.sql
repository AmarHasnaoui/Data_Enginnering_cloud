-- Staging : cast des types depuis BRONZE.
-- Dédup par jour : si la Lambda d'extraction est relancée plusieurs fois pour
-- la même date (RAW est append-only), on ne garde que les lignes du dernier
-- chargement (_loaded_at max) de ce jour-là, pas un mix de plusieurs runs.
{{
  config(
    materialized = 'view'
  )
}}

WITH latest_load_per_day AS (
    SELECT
        DATE(TO_TIMESTAMP_NTZ(date_debut, 'YYYY/MM/DD HH24:MI:SS')) AS day,
        MAX(_loaded_at) AS max_loaded_at
    FROM {{ source('bronze_air_quality', 'RAW_AIR_QUALITY') }}
    WHERE date_debut IS NOT NULL
    GROUP BY day
)

SELECT
    TO_TIMESTAMP_NTZ(raw.date_debut, 'YYYY/MM/DD HH24:MI:SS')  AS date_debut,
    TO_TIMESTAMP_NTZ(raw.date_fin,   'YYYY/MM/DD HH24:MI:SS')  AS date_fin,
    raw.organisme,
    raw.code_zas,
    raw.zas,
    raw.code_site,
    raw.nom_site,
    raw.type_implantation,
    raw.polluant,
    raw.type_influence,
    raw.discriminant,
    CASE WHEN UPPER(raw.reglementaire) = 'OUI' THEN TRUE ELSE FALSE END AS reglementaire,
    raw.type_evaluation,
    raw.procedure_mesure,
    raw.type_valeur,
    TRY_CAST(raw.valeur       AS FLOAT)  AS valeur,
    TRY_CAST(raw.valeur_brute AS FLOAT)  AS valeur_brute,
    raw.unite_mesure,
    TRY_CAST(raw.taux_saisie  AS FLOAT)  AS taux_saisie,
    raw.couverture_temporelle,
    raw.couverture_donnees,
    raw.code_qualite,
    TRY_CAST(raw.validite     AS FLOAT)  AS validite,
    raw._loaded_at,
    raw._file_name
FROM {{ source('bronze_air_quality', 'RAW_AIR_QUALITY') }} AS raw
JOIN latest_load_per_day AS ll
  ON DATE(TO_TIMESTAMP_NTZ(raw.date_debut, 'YYYY/MM/DD HH24:MI:SS')) = ll.day
 AND raw._loaded_at = ll.max_loaded_at
WHERE raw.date_debut IS NOT NULL
  AND raw.code_site  IS NOT NULL
