-- Override de la macro dbt par défaut.
-- Retourne directement le custom_schema_name défini dans dbt_project.yml,
-- sans le préfixer du target schema — tous les modèles atterrissent dans SILVER.AIR_QUALITY.
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is not none -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema | trim }}
    {%- endif -%}
{%- endmacro %}
