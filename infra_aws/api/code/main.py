from datetime import date
from typing import Optional

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from mangum import Mangum

from db import query
from models import (
    AirQualityRow, AlerteRow, VeloRow,
    TraficRow, KpiRow,
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
):
    where, params = date_clause("date_mesure", date_start, date_end)
    if polluant:
        connector = "AND" if where else "WHERE"
        where += f" {connector} polluant = %s"
        params.append(polluant)
    params.append(limit)
    return query(f"SELECT * FROM dm_alertes_pollution {where} ORDER BY date_mesure DESC, ratio_depassement DESC LIMIT %s", tuple(params))


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


# ─────────────────────────────────────────────────────────
# Handler Lambda (Mangum — ASGI adapter)
# ─────────────────────────────────────────────────────────
handler = Mangum(app, lifespan="off")
