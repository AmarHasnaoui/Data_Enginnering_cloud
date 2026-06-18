-- Trafic vélo journalier agrégé par compteur
{{
  config(
    materialized = 'incremental',
    unique_key   = ['compteur_id', 'date_jour']
  )
}}

SELECT
    compteur_id,
    compteur_nom,
    nom_site,
    date_jour,
    total_passages_jour,
    nb_mesures_horaires,
    pic_horaire,
    latitude,
    longitude,
    CURRENT_TIMESTAMP() AS updated_at
FROM {{ ref('int_velo_daily') }}

{% if is_incremental() %}
WHERE date_jour > (COALESCE(MAX(date_jour), '1970-01-01') FROM {{ this }})
{% endif %}
