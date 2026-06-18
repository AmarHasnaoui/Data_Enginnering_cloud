-- L'agrégation journalière doit respecter min <= moyenne <= max.
-- Une ligne retournée ici signale un bug d'agrégation dans dm_air_quality_daily.
SELECT
    code_site,
    polluant,
    date_mesure,
    valeur_min,
    valeur_moyenne,
    valeur_max
FROM {{ ref('dm_air_quality_daily') }}
WHERE NOT (valeur_min <= valeur_moyenne AND valeur_moyenne <= valeur_max)
