-- Filtre uniquement les stations Île-de-France + jointure coordonnées
{{
  config(
    materialized = 'table'
  )
}}

WITH idf_sites AS (
    SELECT code_site FROM (VALUES
        ('FR04002'), ('FR04004'), ('FR04012'), ('FR04023'), ('FR04034'),
        ('FR04048'), ('FR04053'), ('FR04055'), ('FR04058'), ('FR04066'),
        ('FR04098'), ('FR04099'), ('FR04118'), ('FR04122'), ('FR04123'),
        ('FR04131'), ('FR04156'), ('FR04158'), ('FR04173'), ('FR04179'),
        ('FR04181'), ('FR04319'), ('FR04328'), ('FR04329')
    ) AS t(code_site)
)

SELECT
    aq.date_debut,
    aq.date_fin,
    aq.code_site,
    aq.nom_site,
    aq.type_implantation,
    aq.polluant,
    aq.valeur,
    aq.valeur_brute,
    aq.unite_mesure,
    aq.reglementaire,
    aq.type_valeur,
    aq.taux_saisie,
    aq.code_qualite,
    aq.validite,
    coord.latitude,
    coord.longitude,
    DATE(aq.date_debut) AS date_mesure
FROM {{ ref('stg_air_quality') }}  AS aq
JOIN idf_sites                      ON aq.code_site = idf_sites.code_site
LEFT JOIN {{ ref('stg_coordonnees') }} AS coord ON aq.code_site = coord.code_site
