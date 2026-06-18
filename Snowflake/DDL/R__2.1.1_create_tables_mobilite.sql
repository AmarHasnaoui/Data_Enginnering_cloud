USE DATABASE BRONZE;
USE SCHEMA MOBILITE;

-- Comptages horaires vélo (opendata.paris.fr)
CREATE TABLE IF NOT EXISTS RAW_TRAFIC_VELO
(
    compteur_id                     VARCHAR(255),
    compteur_nom                    VARCHAR(255),
    site_id                         VARCHAR(255),
    name                            VARCHAR(255),
    sum_counts                      VARCHAR(50),
    date                            VARCHAR(50),
    date_installation               VARCHAR(50),
    lien_photo_site                 VARCHAR(1024),
    coordonnees_geographiques       VARCHAR(255),
    counter                         VARCHAR(255),
    photos                          VARCHAR(255),
    test_lien_vers_photo            VARCHAR(500),
    id_photo_1                      VARCHAR(500),
    url_sites                       VARCHAR(1024),
    type_image                      VARCHAR(64),
    mois_annee_comptage             VARCHAR(10),
    -- colonnes techniques
    _file_name                      VARCHAR(500),
    _loaded_at                      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Comptages horaires trafic routier (opendata.paris.fr)
CREATE TABLE IF NOT EXISTS RAW_TRAFIC_ROUTIER
(
    iu_ac                           VARCHAR(64),
    libelle                         VARCHAR(255),
    t_1h                            VARCHAR(50),
    k                               VARCHAR(50),
    q                               VARCHAR(50),
    etat_trafic                     VARCHAR(32),
    iu_nd_amont                     VARCHAR(50),
    libelle_nd_amont                VARCHAR(255),
    iu_nd_aval                      VARCHAR(50),
    libelle_nd_aval                 VARCHAR(255),
    etat_barre                      VARCHAR(40),
    date_debut                      VARCHAR(50),
    date_fin                        VARCHAR(50),
    geo_point_2d                    VARCHAR(100),
    geo_shape                       VARCHAR(10000),
    -- colonnes techniques
    _file_name                      VARCHAR(500),
    _loaded_at                      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Élargit geo_shape si la table existe déjà avec l'ancienne taille VARCHAR(500)
-- (un GeoJSON de tronçon routier peut contenir de nombreuses coordonnées)
ALTER TABLE RAW_TRAFIC_ROUTIER ALTER COLUMN geo_shape SET DATA TYPE VARCHAR(16777216);

-- Emplacements statiques des stations Vélib (JSON → colonnes)
CREATE TABLE IF NOT EXISTS RAW_STATIONS_VELIB
(
    stationcode                     VARCHAR(50),
    name                            VARCHAR(255),
    capacity                        VARCHAR(20),
    coordonnees_geo_lat             VARCHAR(50),
    coordonnees_geo_lon             VARCHAR(50),
    nom_arrondissement_communes     VARCHAR(255),
    code_insee_commune              VARCHAR(20),
    -- colonnes techniques
    _file_name                      VARCHAR(500),
    _loaded_at                      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

DROP TABLE IF EXISTS RAW_VELIB_REALTIME;
