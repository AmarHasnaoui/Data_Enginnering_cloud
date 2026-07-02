from datetime import date
from typing import Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from mangum import Mangum

from db import query
from db_dynamo import get_station, list_stations
from models import (
    AirQualityRow, AlerteRow, VeloRow,
    TraficRow, KpiRow, ZoneKpiRow, ArrondissementRow, VelibStationRow,
)

app = FastAPI(
    title="NovaSight API",
    description="API Smart City — qualité de l'air, mobilité et KPI Paris IDF.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────────────────────
# Health
# ─────────────────────────────────────────────────────────
@app.get("/health", tags=["Health"])
def health():
    return {"status": "ok"}


# ─────────────────────────────────────────────────────────
# Helper — filtre date
# ─────────────────────────────────────────────────────────
def date_clause(col: str, start: Optional[date], end: Optional[date]) -> tuple[str, list]:
    parts, params = [], []
    if start:
        parts.append(f"{col} >= %s")
        params.append(start)
    if end:
        parts.append(f"{col} <= %s")
        params.append(end)
    clause = ("WHERE " + " AND ".join(parts)) if parts else ""
    return clause, params


# ─────────────────────────────────────────────────────────
# KPI Smart City
# ─────────────────────────────────────────────────────────
@app.get("/kpi/summary", response_model=list[KpiRow], tags=["Smart City"])
def get_kpi_summary(
    date_start: Optional[date] = Query(None, description="Date de début (YYYY-MM-DD)"),
    date_end:   Optional[date] = Query(None, description="Date de fin (YYYY-MM-DD)"),
    limit:      int            = Query(100, ge=1, le=1000),
):
    where, params = date_clause("date_jour", date_start, date_end)
    params.append(limit)
    return query(f"SELECT * FROM dm_smartcity_kpi_daily {where} ORDER BY date_jour DESC LIMIT %s", tuple(params))


# ─────────────────────────────────────────────────────────
# Qualité de l'air
# ─────────────────────────────────────────────────────────
@app.get("/air-quality", response_model=list[AirQualityRow], tags=["Air Quality"])
def get_air_quality(
    date_start: Optional[date] = Query(None),
    date_end:   Optional[date] = Query(None),
    polluant:   Optional[str]  = Query(None, description="Ex: NO2, PM10, PM2.5, O3"),
    code_site:  Optional[str]  = Query(None),
    limit:      int            = Query(100, ge=1, le=1000),
):
    where, params = date_clause("date_mesure", date_start, date_end)
    if polluant:
        connector = "AND" if where else "WHERE"
        where += f" {connector} polluant = %s"
        params.append(polluant)
    if code_site:
        connector = "AND" if where else "WHERE"
        where += f" {connector} code_site = %s"
        params.append(code_site)
    params.append(limit)
    return query(f"SELECT * FROM dm_air_quality_daily {where} ORDER BY date_mesure DESC LIMIT %s", tuple(params))


@app.get("/air-quality/alertes", response_model=list[AlerteRow], tags=["Air Quality"])
def get_alertes(
    date_start: Optional[date] = Query(None),
    date_end:   Optional[date] = Query(None),
    polluant:   Optional[str]  = Query(None),
    limit:      int            = Query(100, ge=1, le=1000),
    offset:     int            = Query(0, ge=0),
):
    where, params = date_clause("date_mesure", date_start, date_end)
    if polluant:
        connector = "AND" if where else "WHERE"
        where += f" {connector} polluant = %s"
        params.append(polluant)
    params.extend([limit, offset])
    return query(f"SELECT * FROM dm_alertes_pollution {where} ORDER BY date_mesure DESC, ratio_depassement DESC LIMIT %s OFFSET %s", tuple(params))


# ─────────────────────────────────────────────────────────
# Mobilité — Vélo
# ─────────────────────────────────────────────────────────
@app.get("/mobilite/velo", response_model=list[VeloRow], tags=["Mobilité"])
def get_velo(
    date_start:   Optional[date] = Query(None),
    date_end:     Optional[date] = Query(None),
    compteur_id:  Optional[str]  = Query(None),
    limit:        int            = Query(100, ge=1, le=1000),
):
    where, params = date_clause("date_jour", date_start, date_end)
    if compteur_id:
        connector = "AND" if where else "WHERE"
        where += f" {connector} compteur_id = %s"
        params.append(compteur_id)
    params.append(limit)
    return query(f"SELECT * FROM dm_velo_daily {where} ORDER BY date_jour DESC LIMIT %s", tuple(params))


# ─────────────────────────────────────────────────────────
# Mobilité — Trafic routier
# ─────────────────────────────────────────────────────────
@app.get("/mobilite/trafic", response_model=list[TraficRow], tags=["Mobilité"])
def get_trafic(
    date_start: Optional[date] = Query(None),
    date_end:   Optional[date] = Query(None),
    arc_id:     Optional[str]  = Query(None),
    limit:      int            = Query(100, ge=1, le=1000),
):
    where, params = date_clause("date_jour", date_start, date_end)
    if arc_id:
        connector = "AND" if where else "WHERE"
        where += f" {connector} arc_id = %s"
        params.append(arc_id)
    params.append(limit)
    return query(f"SELECT * FROM dm_trafic_routier_daily {where} ORDER BY date_jour DESC LIMIT %s", tuple(params))


@app.get("/mobilite/trafic/daily-avg", tags=["Mobilité"])
def get_trafic_daily_avg(
    date_start: Optional[date] = Query(None),
    date_end:   Optional[date] = Query(None),
    limit:      int            = Query(365, ge=1, le=1000),
):
    where, params = date_clause("date_jour", date_start, date_end)
    params.append(limit)
    return query(
        f"SELECT date_jour, AVG(debit_moyen) AS debit_moyen "
        f"FROM dm_trafic_routier_daily {where} "
        f"GROUP BY date_jour ORDER BY date_jour ASC LIMIT %s",
        tuple(params),
    )


# ─────────────────────────────────────────────────────────
# Zones administratives (arrondissements Paris)
# ─────────────────────────────────────────────────────────
@app.get("/zones/kpi", response_model=list[ZoneKpiRow], tags=["Zones"])
def get_zone_kpi(
    date_start:           Optional[date] = Query(None),
    date_end:             Optional[date] = Query(None),
    arrondissement_code:  Optional[int]  = Query(None),
    limit:                int            = Query(100, ge=1, le=1000),
):
    where, params = date_clause("date_jour", date_start, date_end)
    if arrondissement_code:
        connector = "AND" if where else "WHERE"
        where += f" {connector} arrondissement_code = %s"
        params.append(arrondissement_code)
    params.append(limit)
    return query(f"SELECT * FROM dm_zone_kpi_daily {where} ORDER BY date_jour DESC LIMIT %s", tuple(params))


@app.get("/zones/arrondissements", response_model=list[ArrondissementRow], tags=["Zones"])
def get_arrondissements():
    return query("SELECT * FROM ref_arrondissements ORDER BY arrondissement_code")


# ─────────────────────────────────────────────────────────
# Mobilité — Vélib temps réel (DynamoDB, hors Snowflake)
# ─────────────────────────────────────────────────────────
@app.get("/mobilite/velib", response_model=list[VelibStationRow], tags=["Mobilité"])
def get_velib_stations(
    arrondissement: Optional[str] = Query(None, description="Ex: Paris 15e Arrondissement"),
    limit:          int           = Query(100, ge=1, le=1500),
):
    return list_stations(arrondissement=arrondissement, limit=limit)


@app.get("/mobilite/velib/{station_id}", response_model=VelibStationRow, tags=["Mobilité"])
def get_velib_station(station_id: str):
    station = get_station(station_id)
    if not station:
        raise HTTPException(status_code=404, detail="Station inconnue")
    return station


# ─────────────────────────────────────────────────────────
# Handler Lambda (Mangum — ASGI adapter)
# ─────────────────────────────────────────────────────────
handler = Mangum(app, lifespan="off")
