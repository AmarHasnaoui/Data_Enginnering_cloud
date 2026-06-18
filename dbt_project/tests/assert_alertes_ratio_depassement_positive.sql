-- dm_alertes_pollution ne garde que les dépassements (valeur_max > seuil),
-- donc ratio_depassement doit toujours être strictement > 1.
SELECT
    code_site,
    polluant,
    date_mesure,
    ratio_depassement
FROM {{ ref('dm_alertes_pollution') }}
WHERE ratio_depassement <= 1
