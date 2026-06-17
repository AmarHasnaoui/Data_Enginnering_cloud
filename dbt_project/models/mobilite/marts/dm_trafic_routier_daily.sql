{{
  config(
    materialized = 'incremental',
    unique_key   = ['arc_id', 'date_jour']
  )
}}

SELECT
    arc_id,
    libelle_arc,
    date_jour,
    debit_moyen,
    debit_max,
    taux_occupation_moyen,
    nb_heures_bloque,
    nb_heures_sature,
    nb_heures_dense,
    nb_heures_fluide,
    nb_mesures,
    latitude,
    longitude,
    CURRENT_TIMESTAMP() AS updated_at
FROM {{ ref('int_trafic_daily') }}

{% if is_incremental() %}
WHERE date_jour > (SELECT MAX(date_jour) FROM {{ this }})
{% endif %}
