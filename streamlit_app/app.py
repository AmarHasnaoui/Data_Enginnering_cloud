import json
from datetime import date, timedelta

import pandas as pd
import pydeck as pdk
import streamlit as st
from botocore.exceptions import ClientError

import api_client as api
from auth import login
from colorscale import value_to_rgba

st.set_page_config(page_title="NovaSight", layout="wide")

PARIS_LAT, PARIS_LON = 48.8566, 2.3522


# ─────────────────────────────────────────────────────────
# Authentification
# ─────────────────────────────────────────────────────────
def render_login():
    st.title("NovaSight")
    st.caption("Plateforme Smart City — qualite de l'air, mobilite et zones administratives, Paris IDF.")

    with st.form("login_form"):
        username = st.text_input("Identifiant")
        password = st.text_input("Mot de passe", type="password")
        submitted = st.form_submit_button("Se connecter")

    if submitted:
        try:
            token = login(username, password)
            st.session_state["id_token"] = token
            st.session_state["username"] = username
            st.rerun()
        except ClientError as e:
            st.error(f"Authentification refusee : {e.response['Error']['Message']}")


if "id_token" not in st.session_state:
    render_login()
    st.stop()


# ─────────────────────────────────────────────────────────
# Sidebar — session et filtres communs
# ─────────────────────────────────────────────────────────
with st.sidebar:
    st.write(f"Connecte : {st.session_state.get('username', '')}")
    if st.button("Se deconnecter"):
        st.session_state.clear()
        st.rerun()

    st.divider()
    st.subheader("Periode")
    default_end   = date.today()
    default_start = default_end - timedelta(days=30)
    date_start, date_end = st.date_input(
        "Plage de dates",
        value=(default_start, default_end),
        max_value=default_end,
    )

date_start_str = date_start.isoformat()
date_end_str   = date_end.isoformat()


# ─────────────────────────────────────────────────────────
# Onglets
# ─────────────────────────────────────────────────────────
tab_overview, tab_air, tab_mobilite, tab_zones = st.tabs(
    ["Vue d'ensemble", "Qualite de l'air", "Mobilite", "Carte des zones"]
)


# ─────────────────────────────────────────────────────────
# Vue d'ensemble
# ─────────────────────────────────────────────────────────
with tab_overview:
    kpi = pd.DataFrame(api.get_kpi_summary(date_start_str, date_end_str, limit=400))

    if kpi.empty:
        st.info("Aucune donnee KPI sur cette periode.")
    else:
        kpi["date_jour"] = pd.to_datetime(kpi["date_jour"])
        kpi = kpi.sort_values("date_jour")
        latest = kpi.iloc[-1]

        c1, c2, c3, c4 = st.columns(4)
        c1.metric("NO2 moyen (derniere date)", f"{latest.get('no2_moyen', 0):.1f} ug/m3")
        c2.metric("Debit routier moyen", f"{latest.get('debit_routier_moyen', 0):.1f}")
        c3.metric("Total velos", f"{int(latest.get('total_velos') or 0):,}")
        c4.metric("Stations en alerte", int(latest.get("nb_stations_alerte") or 0))

        st.divider()
        col1, col2 = st.columns(2)
        with col1:
            st.caption("Polluants (ug/m3)")
            poll_cols = [c for c in ["no2_moyen", "pm10_moyen", "pm25_moyen", "o3_moyen"] if c in kpi.columns]
            st.line_chart(kpi.set_index("date_jour")[poll_cols])
        with col2:
            st.caption("Mobilite")
            mob_cols = [c for c in ["total_velos", "debit_routier_moyen"] if c in kpi.columns]
            st.line_chart(kpi.set_index("date_jour")[mob_cols])


# ─────────────────────────────────────────────────────────
# Qualite de l'air
# ─────────────────────────────────────────────────────────
with tab_air:
    aq = pd.DataFrame(api.get_air_quality(date_start_str, date_end_str, limit=1000))

    if aq.empty:
        st.info("Aucune donnee de qualite de l'air sur cette periode.")
    else:
        aq["date_mesure"] = pd.to_datetime(aq["date_mesure"])
        polluants = sorted(aq["polluant"].dropna().unique())
        pol = st.selectbox("Polluant", polluants)

        aq_pol = aq[aq["polluant"] == pol]
        evo = aq_pol.groupby("date_mesure")["valeur_moyenne"].mean()
        st.caption(f"Evolution {pol} (ug/m3)")
        st.line_chart(evo)

        top_sites = (
            aq_pol.groupby("nom_site")["valeur_max"].max()
            .sort_values(ascending=False)
            .head(10)
        )
        st.caption(f"Top 10 sites exposes au {pol}")
        st.bar_chart(top_sites)

    st.divider()
    st.subheader("Alertes de depassement")

    # Seuils OMS officiels (valeur par defaut du slider) et seuils de capture
    # Snowpark pre-calcule dm_alertes_pollution a partir de 50% des seuils OMS,
    # ce qui permet au slider de descendre en dessous des valeurs officielles.
    SEUILS_OMS     = {"NO2": 40,  "PM10": 50,  "PM2.5": 25, "O3": 100, "SO2": 20}
    SEUILS_CAPTURE = {"NO2": 10,  "PM10": 10,  "PM2.5": 5, "O3": 10,  "SO2": 5}

    alertes = pd.DataFrame(api.get_alertes(date_start_str, date_end_str, limit=2000))

    col_sel, col_seuil = st.columns([1, 2])
    with col_sel:
        pol_alerte = st.selectbox(
            "Polluant", list(SEUILS_OMS.keys()), key="pol_alerte"
        )
    with col_seuil:
        seuil_oms     = SEUILS_OMS[pol_alerte]
        seuil_capture = SEUILS_CAPTURE[pol_alerte]
        seuil_custom  = st.slider(
            f"Seuil personnalise (µg/m3)  —  OMS : {seuil_oms} µg/m3",
            min_value=seuil_capture, max_value=500, value=seuil_oms, step=5,
        )

    if alertes.empty:
        st.info("Aucune donnee d'alerte sur cette periode.")
    else:
        alertes["date_mesure"] = pd.to_datetime(alertes["date_mesure"])
        dep = alertes[
            (alertes["polluant"] == pol_alerte) &
            (alertes["valeur_max_journaliere"] > seuil_custom)
        ].copy()
        dep["ratio"] = (dep["valeur_max_journaliere"] / seuil_custom).round(2)

        if dep.empty:
            st.success(
                f"Aucune station ne depasse {seuil_custom} µg/m3 de {pol_alerte} sur la periode."
            )
        else:
            c1, c2, c3 = st.columns(3)
            c1.metric("Depassements (lignes)", len(dep))
            c2.metric("Stations concernees", dep["code_site"].nunique())
            c3.metric("Ratio max", f"{dep['ratio'].max():.2f}x le seuil")

            map_df = dep.dropna(subset=["latitude", "longitude"])
            if not map_df.empty:
                layer = pdk.Layer(
                    "ScatterplotLayer",
                    map_df,
                    get_position=["longitude", "latitude"],
                    get_radius=400,
                    get_fill_color=[220, 50, 50, 200],
                    pickable=True,
                )
                st.pydeck_chart(pdk.Deck(
                    layers=[layer],
                    initial_view_state=pdk.ViewState(
                        latitude=PARIS_LAT, longitude=PARIS_LON, zoom=10
                    ),
                    tooltip={
                        "html": "<b>{nom_site}</b><br/>"
                                + pol_alerte
                                + " max : {valeur_max_journaliere} µg/m3<br/>Ratio : {ratio}x"
                    },
                ))

            st.dataframe(
                dep[["date_mesure", "nom_site", "valeur_max_journaliere",
                     "valeur_moyenne", "ratio"]]
                .sort_values("ratio", ascending=False),
                use_container_width=True,
                hide_index=True,
            )


# ─────────────────────────────────────────────────────────
# Mobilite
# ─────────────────────────────────────────────────────────
with tab_mobilite:
    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Trafic velo")
        velo = pd.DataFrame(api.get_velo(date_start_str, date_end_str, limit=1000))
        if velo.empty:
            st.info("Aucune donnee velo sur cette periode.")
        else:
            velo["date_jour"] = pd.to_datetime(velo["date_jour"])
            evo = velo.groupby("date_jour")["total_passages_jour"].sum()
            st.caption("Total passages velo par jour")
            st.line_chart(evo)

    with col2:
        st.subheader("Trafic routier")
        trafic = pd.DataFrame(api.get_trafic_daily_avg(date_start_str, date_end_str))
        if trafic.empty:
            st.info("Aucune donnee trafic sur cette periode.")
        else:
            trafic["date_jour"] = pd.to_datetime(trafic["date_jour"])
            st.caption("Debit moyen par jour")
            st.line_chart(trafic.set_index("date_jour")["debit_moyen"])

    st.divider()
    st.subheader("Velib temps reel")
    velib = pd.DataFrame(api.get_velib_stations(limit=1500))
    if velib.empty:
        st.info("Aucune station Velib disponible.")
    else:
        c1, c2, c3 = st.columns(3)
        c1.metric("Stations", len(velib))
        c2.metric("Velos disponibles", int(velib["num_bikes_available"].fillna(0).sum()))
        c3.metric("Places disponibles", int(velib["num_docks_available"].fillna(0).sum()))

        map_df = velib.dropna(subset=["latitude", "longitude"])
        if not map_df.empty:
            layer = pdk.Layer(
                "ScatterplotLayer",
                map_df,
                get_position=["longitude", "latitude"],
                get_radius=40,
                get_fill_color=[40, 110, 190, 180],
                pickable=True,
            )
            view_state = pdk.ViewState(latitude=PARIS_LAT, longitude=PARIS_LON, zoom=11)
            st.pydeck_chart(pdk.Deck(
                layers=[layer],
                initial_view_state=view_state,
                tooltip={"html": "<b>{stationId}</b><br/>Velos dispo: {num_bikes_available}"},
            ))

        st.dataframe(map_df, use_container_width=True, hide_index=True)


# ─────────────────────────────────────────────────────────
# Carte des zones
# ─────────────────────────────────────────────────────────
with tab_zones:
    arrondissements = pd.DataFrame(api.get_arrondissements())
    zone_kpi = pd.DataFrame(api.get_zone_kpi(date_start_str, date_end_str, limit=1000))

    if arrondissements.empty or zone_kpi.empty:
        st.info("Donnees de zones indisponibles sur cette periode.")
    else:
        zone_kpi["date_jour"] = pd.to_datetime(zone_kpi["date_jour"])
        latest_date = zone_kpi["date_jour"].max()
        latest_kpi  = zone_kpi[zone_kpi["date_jour"] == latest_date].drop(columns=["nom_arrondissement"])

        metric_options = {
            "Indice de pollution moyen":      "pollution_indice_moyen",
            "NO2 moyen":                      "no2_moyen",
            "PM10 moyen":                     "pm10_moyen",
            "PM2.5 moyen":                    "pm25_moyen",
            "Debit routier moyen":            "debit_routier_moyen",
            "Ratio mobilite verte":           "ratio_mobilite_verte",
        }
        metric_label = st.selectbox("Indicateur affiche sur la carte", list(metric_options.keys()))
        metric_col = metric_options[metric_label]

        merged = arrondissements.merge(latest_kpi, on="arrondissement_code", how="left")
        vmin = merged[metric_col].min()
        vmax = merged[metric_col].max()

        features = []
        for row in merged.itertuples():
            geometry = getattr(row, "geometry", None)
            if not geometry:
                continue
            value = getattr(row, metric_col, None)
            features.append({
                "type": "Feature",
                "geometry": json.loads(geometry),
                "properties": {
                    "nom_arrondissement": getattr(row, "nom_arrondissement", ""),
                    "value": round(value, 2) if pd.notna(value) else None,
                    "fill_color": value_to_rgba(value, vmin, vmax),
                },
            })
        geojson = {"type": "FeatureCollection", "features": features}

        layer = pdk.Layer(
            "GeoJsonLayer",
            geojson,
            opacity=0.7,
            stroked=True,
            filled=True,
            get_fill_color="properties.fill_color",
            get_line_color=[90, 90, 90],
            line_width_min_pixels=1,
            pickable=True,
        )
        view_state = pdk.ViewState(latitude=PARIS_LAT, longitude=PARIS_LON, zoom=11)
        st.caption(f"Donnees du {latest_date.date()}")
        st.pydeck_chart(pdk.Deck(
            layers=[layer],
            initial_view_state=view_state,
            tooltip={"html": "<b>{nom_arrondissement}</b><br/>" + metric_label + ": {value}"},
        ))

        st.dataframe(
            merged[["arrondissement_code", "nom_arrondissement", metric_col]].sort_values(metric_col, ascending=False),
            use_container_width=True,
            hide_index=True,
        )
