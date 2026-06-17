-- Gold layer : tables PostgreSQL gérées par Snowflake Postgres
-- Alimentées par la Snowpark Procedure PROC_EXPORT_SILVER_TO_GOLD
-- Connexion : psycopg2 / psql standard

-- ─────────────────────────────────────────────────────────
-- AIR QUALITY
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS dm_air_quality_daily (
    code_site             VARCHAR(20)      NOT NULL,
    nom_site              VARCHAR(200),
    type_implantation     VARCHAR(100),
    polluant              VARCHAR(20)      NOT NULL,
    unite_mesure          VARCHAR(20),
    date_mesure           DATE             NOT NULL,
    latitude              NUMERIC(10,6),
    longitude             NUMERIC(10,6),
    valeur_moyenne        NUMERIC(10,4),
    valeur_max            NUMERIC(10,4),
    valeur_min            NUMERIC(10,4),
    nb_mesures            INTEGER,
    taux_saisie_moyen     NUMERIC(5,2),
    updated_at            TIMESTAMP,
    PRIMARY KEY (code_site, polluant, date_mesure)
);

CREATE TABLE IF NOT EXISTS dm_alertes_pollution (
    code_site             VARCHAR(20)      NOT NULL,
    nom_site              VARCHAR(200),
    polluant              VARCHAR(20)      NOT NULL,
    date_mesure           DATE             NOT NULL,
    valeur_max_journaliere NUMERIC(10,4),
    valeur_moyenne        NUMERIC(10,4),
    unite_mesure          VARCHAR(20),
    seuil_reglementaire   NUMERIC(10,4),
    type_seuil            VARCHAR(100),
    ratio_depassement     NUMERIC(6,2),
    latitude              NUMERIC(10,6),
    longitude             NUMERIC(10,6),
    updated_at            TIMESTAMP,
    PRIMARY KEY (code_site, polluant, date_mesure)
);

CREATE TABLE IF NOT EXISTS dm_stations_air (
    code_site             VARCHAR(20)      NOT NULL PRIMARY KEY,
    nom_site              VARCHAR(200),
    type_implantation     VARCHAR(100),
    latitude              NUMERIC(10,6),
    longitude             NUMERIC(10,6),
    updated_at            TIMESTAMP
);

-- ─────────────────────────────────────────────────────────
-- MOBILITE
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS dm_velo_daily (
    compteur_id           VARCHAR(100)     NOT NULL,
    compteur_nom          VARCHAR(300),
    nom_site              VARCHAR(300),
    date_jour             DATE             NOT NULL,
    total_passages_jour   BIGINT,
    nb_mesures_horaires   INTEGER,
    pic_horaire           BIGINT,
    latitude              NUMERIC(10,6),
    longitude             NUMERIC(10,6),
    updated_at            TIMESTAMP,
    PRIMARY KEY (compteur_id, date_jour)
);

CREATE TABLE IF NOT EXISTS dm_trafic_routier_daily (
    arc_id                VARCHAR(100)     NOT NULL,
    libelle_arc           VARCHAR(300),
    date_jour             DATE             NOT NULL,
    debit_moyen           NUMERIC(10,2),
    debit_max             NUMERIC(10,2),
    taux_occupation_moyen NUMERIC(6,2),
    nb_heures_bloque      INTEGER,
    nb_heures_sature      INTEGER,
    nb_heures_dense       INTEGER,
    nb_heures_fluide      INTEGER,
    nb_mesures            INTEGER,
    latitude              NUMERIC(10,6),
    longitude             NUMERIC(10,6),
    updated_at            TIMESTAMP,
    PRIMARY KEY (arc_id, date_jour)
);

CREATE TABLE IF NOT EXISTS dm_stations_velib (
    stationcode                   VARCHAR(20)  NOT NULL,
    nom_station                   VARCHAR(200),
    capacite                      INTEGER,
    latitude                      NUMERIC(10,6),
    longitude                     NUMERIC(10,6),
    nom_arrondissement_communes   VARCHAR(100),
    code_insee_commune            VARCHAR(10),
    date_jour                     DATE         NOT NULL,
    velos_dispo_moyen             NUMERIC(6,2),
    places_dispo_moyen            NUMERIC(6,2),
    velos_meca_moyen              NUMERIC(6,2),
    velos_elec_moyen              NUMERIC(6,2),
    nb_releves                    INTEGER,
    updated_at                    TIMESTAMP,
    PRIMARY KEY (stationcode, date_jour)
);

-- ─────────────────────────────────────────────────────────
-- SMART CITY
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS dm_smartcity_kpi_daily (
    date_jour                DATE         NOT NULL PRIMARY KEY,
    no2_moyen                NUMERIC(10,4),
    pm10_moyen               NUMERIC(10,4),
    pm25_moyen               NUMERIC(10,4),
    o3_moyen                 NUMERIC(10,4),
    nb_stations_alerte       INTEGER,
    debit_routier_moyen      NUMERIC(10,2),
    taux_occupation_moyen    NUMERIC(6,2),
    total_heures_bloque      BIGINT,
    nb_arcs_surveilles       INTEGER,
    total_velos              BIGINT,
    nb_compteurs_actifs      INTEGER,
    updated_at               TIMESTAMP
);

-- ─────────────────────────────────────────────────────────
-- INDEX pour accès API rapide
-- ─────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_aq_daily_date   ON dm_air_quality_daily (date_mesure);
CREATE INDEX IF NOT EXISTS idx_aq_daily_pol    ON dm_air_quality_daily (polluant);
CREATE INDEX IF NOT EXISTS idx_alertes_date    ON dm_alertes_pollution (date_mesure);
CREATE INDEX IF NOT EXISTS idx_velo_date       ON dm_velo_daily (date_jour);
CREATE INDEX IF NOT EXISTS idx_trafic_date     ON dm_trafic_routier_daily (date_jour);
CREATE INDEX IF NOT EXISTS idx_velib_date      ON dm_stations_velib (date_jour);
CREATE INDEX IF NOT EXISTS idx_kpi_date        ON dm_smartcity_kpi_daily (date_jour);
