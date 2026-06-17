-- Staging : cast des types depuis BRONZE, ajout d'une clé de chargement incrémental
{{
  config(
    materialized = 'view'
  )
}}

SELECT
    TO_TIMESTAMP_NTZ(date_debut, 'YYYY/MM/DD HH24:MI:SS')  AS date_debut,
    TO_TIMESTAMP_NTZ(date_fin,   'YYYY/MM/DD HH24:MI:SS')  AS date_fin,
    organisme,
    code_zas,
    zas,
    code_site,
    nom_site,
    type_implantation,
    polluant,
    type_influence,
    discriminant,
    CASE WHEN UPPER(reglementaire) = 'OUI' THEN TRUE ELSE FALSE END AS reglementaire,
    type_evaluation,
    procedure_mesure,
    type_valeur,
    TRY_CAST(valeur       AS FLOAT)  AS valeur,
    TRY_CAST(valeur_brute AS FLOAT)  AS valeur_brute,
    unite_mesure,
    TRY_CAST(taux_saisie  AS FLOAT)  AS taux_saisie,
    couverture_temporelle,
    couverture_donnees,
    code_qualite,
    TRY_CAST(validite     AS FLOAT)  AS validite,
    _loaded_at,
    _file_name
FROM BRONZE.AIR_QUALITY.RAW_AIR_QUALITY
WHERE date_debut IS NOT NULL
  AND code_site  IS NOT NULL
