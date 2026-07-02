import os
import requests
import streamlit as st

API_BASE_URL = os.environ["API_BASE_URL"].rstrip("/")


def _headers() -> dict:
    token = st.session_state.get("id_token")
    return {"Authorization": token} if token else {}


def _get(path: str, params: dict | None = None):
    resp = requests.get(f"{API_BASE_URL}{path}", headers=_headers(), params=params, timeout=15)
    resp.raise_for_status()
    return resp.json()


@st.cache_data(ttl=300, show_spinner=False)
def get_kpi_summary(date_start=None, date_end=None, limit=365):
    params = {"limit": limit}
    if date_start: params["date_start"] = date_start
    if date_end:   params["date_end"]   = date_end
    return _get("/kpi/summary", params)


@st.cache_data(ttl=300, show_spinner=False)
def get_air_quality(date_start=None, date_end=None, polluant=None, code_site=None, limit=1000):
    params = {"limit": limit}
    if date_start: params["date_start"] = date_start
    if date_end:   params["date_end"]   = date_end
    if polluant:   params["polluant"]   = polluant
    if code_site:  params["code_site"]  = code_site
    return _get("/air-quality", params)


@st.cache_data(ttl=300, show_spinner=False)
def get_alertes(date_start=None, date_end=None, polluant=None, limit=2000):
    page_size = 1000
    all_rows, offset = [], 0
    while len(all_rows) < limit:
        params = {"limit": page_size, "offset": offset}
        if date_start: params["date_start"] = date_start
        if date_end:   params["date_end"]   = date_end
        if polluant:   params["polluant"]   = polluant
        batch = _get("/air-quality/alertes", params)
        all_rows.extend(batch)
        if len(batch) < page_size:
            break
        offset += page_size
    return all_rows[:limit]


@st.cache_data(ttl=300, show_spinner=False)
def get_velo(date_start=None, date_end=None, compteur_id=None, limit=1000):
    params = {"limit": limit}
    if date_start: params["date_start"] = date_start
    if date_end:   params["date_end"]   = date_end
    if compteur_id: params["compteur_id"] = compteur_id
    return _get("/mobilite/velo", params)


@st.cache_data(ttl=300, show_spinner=False)
def get_trafic(date_start=None, date_end=None, arc_id=None, limit=1000):
    params = {"limit": limit}
    if date_start: params["date_start"] = date_start
    if date_end:   params["date_end"]   = date_end
    if arc_id:     params["arc_id"]     = arc_id
    return _get("/mobilite/trafic", params)


@st.cache_data(ttl=300, show_spinner=False)
def get_trafic_daily_avg(date_start=None, date_end=None, limit=365):
    params = {"limit": limit}
    if date_start: params["date_start"] = date_start
    if date_end:   params["date_end"]   = date_end
    return _get("/mobilite/trafic/daily-avg", params)


@st.cache_data(ttl=300, show_spinner=False)
def get_zone_kpi(date_start=None, date_end=None, arrondissement_code=None, limit=1000):
    params = {"limit": limit}
    if date_start: params["date_start"] = date_start
    if date_end:   params["date_end"]   = date_end
    if arrondissement_code: params["arrondissement_code"] = arrondissement_code
    return _get("/zones/kpi", params)


@st.cache_data(ttl=3600, show_spinner=False)
def get_arrondissements():
    return _get("/zones/arrondissements")


@st.cache_data(ttl=60, show_spinner=False)
def get_velib_stations(arrondissement=None, limit=1500):
    params = {"limit": limit}
    if arrondissement: params["arrondissement"] = arrondissement
    return _get("/mobilite/velib", params)
