from datetime import date
from typing import Optional
from pydantic import BaseModel


class AirQualityRow(BaseModel):
    code_site:         Optional[str]
    nom_site:          Optional[str]
    type_implantation: Optional[str]
    polluant:          Optional[str]
    unite_mesure:      Optional[str]
    date_mesure:       Optional[date]
    latitude:          Optional[float]
    longitude:         Optional[float]
    valeur_moyenne:    Optional[float]
    valeur_max:        Optional[float]
    valeur_min:        Optional[float]
    nb_mesures:        Optional[int]
    taux_saisie_moyen: Optional[float]


class AlerteRow(BaseModel):
    code_site:              Optional[str]
    nom_site:               Optional[str]
    polluant:               Optional[str]
    date_mesure:            Optional[date]
    valeur_max_journaliere: Optional[float]
    valeur_moyenne:         Optional[float]
    unite_mesure:           Optional[str]
    seuil_reglementaire:    Optional[float]
    type_seuil:             Optional[str]
    ratio_depassement:      Optional[float]
    latitude:               Optional[float]
    longitude:              Optional[float]


class VeloRow(BaseModel):
    compteur_id:         Optional[str]
    compteur_nom:        Optional[str]
    nom_site:            Optional[str]
    date_jour:           Optional[date]
    total_passages_jour: Optional[int]
    nb_mesures_horaires: Optional[int]
    pic_horaire:         Optional[int]
    latitude:            Optional[float]
    longitude:           Optional[float]


class TraficRow(BaseModel):
    arc_id:                Optional[str]
    libelle_arc:           Optional[str]
    date_jour:             Optional[date]
    debit_moyen:           Optional[float]
    debit_max:             Optional[float]
    taux_occupation_moyen: Optional[float]
    nb_heures_bloque:      Optional[int]
    nb_heures_sature:      Optional[int]
    nb_heures_dense:       Optional[int]
    nb_heures_fluide:      Optional[int]
    nb_mesures:            Optional[int]
    latitude:              Optional[float]
    longitude:             Optional[float]



class KpiRow(BaseModel):
    date_jour:             Optional[date]
    no2_moyen:             Optional[float]
    pm10_moyen:            Optional[float]
    pm25_moyen:            Optional[float]
    o3_moyen:              Optional[float]
    nb_stations_alerte:    Optional[int]
    debit_routier_moyen:   Optional[float]
    taux_occupation_moyen: Optional[float]
    total_heures_bloque:   Optional[int]
    nb_arcs_surveilles:    Optional[int]
    total_velos:           Optional[int]
    nb_compteurs_actifs:   Optional[int]
