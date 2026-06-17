USE DATABASE BRONZE;
USE SCHEMA AIR_QUALITY;
USE ROLE INGEST_ROLE;

CREATE TABLE IF NOT EXISTS RAW_AIR_QUALITY
(
    date_debut              VARCHAR(255),
    date_fin                VARCHAR(255),
    organisme               VARCHAR(255),
    code_zas                VARCHAR(255),
    zas                     VARCHAR(255),
    code_site               VARCHAR(255),
    nom_site                VARCHAR(255),
    type_implantation       VARCHAR(255),
    polluant                VARCHAR(255),
    type_influence          VARCHAR(255),
    discriminant            VARCHAR(255),
    reglementaire           VARCHAR(255),
    type_evaluation         VARCHAR(255),
    procedure_mesure        VARCHAR(255),
    type_valeur             VARCHAR(255),
    valeur                  VARCHAR(255),
    valeur_brute            VARCHAR(255),
    unite_mesure            VARCHAR(255),
    taux_saisie             VARCHAR(255),
    couverture_temporelle   VARCHAR(255),
    couverture_donnees      VARCHAR(255),
    code_qualite            VARCHAR(255),
    validite                VARCHAR(255),
    -- colonnes techniques Snowpipe
    _file_name              VARCHAR(500),
    _loaded_at              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
