import io
import zipfile
import pandas as pd
import altair as alt
import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="NovaSight Analytics", layout="wide")

session = get_active_session()

# ─────────────────────────────────────────────────────────
# Tables SILVER lues via Snowpark (pas d'API HTTP)
# ─────────────────────────────────────────────────────────
TABLES = {
    "kpi_summary_journalier":   "SILVER.SMARTCITY.DM_SMARTCITY_KPI_DAILY",
    "top_congestion":           "SILVER.MOBILITE.DM_TRAFIC_ROUTIER_DAILY",
    "alertes_pollution":        "SILVER.AIR_QUALITY.DM_ALERTES_POLLUTION",
    "heures_trafic":            "SILVER.MOBILITE.DM_TRAFIC_ROUTIER_DAILY",
    "trafic_journalier":        "SILVER.MOBILITE.DM_TRAFIC_ROUTIER_DAILY",
    "velo_journalier":          "SILVER.MOBILITE.DM_VELO_DAILY",
    "air_quality_journalier":   "SILVER.AIR_QUALITY.DM_AIR_QUALITY_DAILY",
    "velo_trafic_air":          "SILVER.SMARTCITY.DM_SMARTCITY_KPI_DAILY",
}

KPI_LABELS = {
    "kpi_summary_journalier":  "KPI Global Smart City",
    "top_congestion":          "Top Congestion Routière",
    "alertes_pollution":       "Alertes Pollution",
    "heures_trafic":           "Heures Critiques Trafic",
    "trafic_journalier":       "Trafic Journalier",
    "velo_journalier":         "Comptage Vélo",
    "air_quality_journalier":  "Qualité de l'Air",
    "velo_trafic_air":         "Croisement Vélos / Trafic / Air",
}

# ─────────────────────────────────────────────────────────
# Utils
# ─────────────────────────────────────────────────────────
@st.cache_data(ttl=3600, show_spinner=True)
def load_table(table_fqn: str) -> pd.DataFrame:
    df = session.table(table_fqn).to_pandas()
    df.columns = [c.lower() for c in df.columns]
    return df

def _num(s): return pd.to_numeric(s, errors="coerce")
def _date(s): return pd.to_datetime(s, errors="coerce")

def csv_bytes(df: pd.DataFrame) -> bytes:
    return df.to_csv(index=False).encode("utf-8")

def make_zip(files: dict) -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        for name, content in files.items():
            z.writestr(name, content)
    buf.seek(0)
    return buf.read()

# ─────────────────────────────────────────────────────────
# UI — Layout principal
# ─────────────────────────────────────────────────────────
st.title("NovaSight Analytics — Smart City Paris IDF")
st.divider()

left, right = st.columns([2, 1], vertical_alignment="top")

with left:
    st.subheader("1) Afficher un KPI")
    kpi_key = st.selectbox(
        "KPI à afficher",
        list(KPI_LABELS.keys()),
        format_func=lambda k: KPI_LABELS[k],
        index=0,
        key="kpi_select"
    )
    btn_show = st.button("Afficher", type="primary", key="btn_show")

    if btn_show:
        try:
            df = load_table(TABLES[kpi_key])
            st.session_state["df_display"] = df
            st.session_state["kpi_display"] = kpi_key
        except Exception as e:
            st.error(f"Erreur de chargement : {e}")

    df_display = st.session_state.get("df_display", pd.DataFrame())
    kpi_display = st.session_state.get("kpi_display", None)

    if kpi_display is None:
        st.info("Choisis un KPI et clique sur **Afficher**.")
    elif df_display.empty:
        st.warning("Table vide ou non disponible.")
    else:
        st.success(f"{len(df_display):,} lignes — {TABLES[kpi_display]}")
        st.dataframe(df_display.head(25), use_container_width=True)

        df = df_display.copy()

        # ─────────────────────────────────────────────────────────
        # KPI 1 — KPI Global Smart City (dm_smartcity_kpi_daily)
        # Colonnes : date_jour, no2_moyen, pm10_moyen, pm25_moyen, o3_moyen,
        #            nb_stations_alerte, debit_routier_moyen, taux_occupation_moyen,
        #            total_heures_bloque, total_velos, nb_compteurs_actifs
        # ─────────────────────────────────────────────────────────
        if kpi_display == "kpi_summary_journalier":
            for c in ["debit_routier_moyen", "taux_occupation_moyen", "total_heures_bloque", "total_velos"]:
                if c in df.columns: df[c] = _num(df[c])
            if "date_jour" in df.columns: df["date_jour"] = _date(df["date_jour"])
            dfs = df.sort_values("date_jour")

            dates = sorted(dfs["date_jour"].dropna().dt.strftime("%Y-%m-%d").unique())
            choice = st.selectbox("Date", ["Toutes"] + dates, index=0, key="kpi_date")
            picked = pd.to_datetime(choice) if choice != "Toutes" else None
            df1 = dfs[dfs["date_jour"] == picked] if picked else dfs

            c1, c2, c3 = st.columns(3)
            if "debit_routier_moyen"   in df1.columns: c1.metric("Débit routier moyen", f"{df1['debit_routier_moyen'].mean():.1f}")
            if "total_velos"           in df1.columns: c2.metric("Total vélos", f"{df1['total_velos'].sum():,.0f}")
            if "nb_stations_alerte"    in df1.columns: c3.metric("Stations en alerte", int(df1["nb_stations_alerte"].sum()))

            col1, col2 = st.columns(2)
            with col1:
                if {"date_jour","debit_routier_moyen"} <= set(dfs.columns):
                    st.caption("Débit routier moyen")
                    st.line_chart(dfs.set_index("date_jour")["debit_routier_moyen"])
            with col2:
                if {"date_jour","total_velos"} <= set(dfs.columns):
                    st.caption("Total vélos")
                    st.line_chart(dfs.set_index("date_jour")["total_velos"])

            poll_cols = [c for c in ["no2_moyen","pm10_moyen","pm25_moyen","o3_moyen"] if c in dfs.columns]
            if poll_cols:
                st.caption("Évolution des polluants (µg/m³)")
                st.line_chart(dfs.set_index("date_jour")[poll_cols])

        # ─────────────────────────────────────────────────────────
        # KPI 2 — Top Congestion (dm_trafic_routier_daily)
        # Colonnes : arc_id, libelle_arc, date_jour, debit_moyen, debit_max,
        #            taux_occupation_moyen, nb_heures_bloque, nb_heures_dense, nb_heures_fluide
        # ─────────────────────────────────────────────────────────
        elif kpi_display == "top_congestion":
            for c in ["debit_moyen","taux_occupation_moyen","nb_heures_bloque"]:
                if c in df.columns: df[c] = _num(df[c])
            if "date_jour" in df.columns: df["date_jour"] = _date(df["date_jour"])

            dates = sorted(df["date_jour"].dropna().dt.strftime("%Y-%m-%d").unique())
            choice = st.selectbox("Date", ["Date la plus récente"] + dates, index=0, key="cong_date")
            picked = df["date_jour"].max() if choice == "Date la plus récente" else pd.to_datetime(choice)
            dfd = df[df["date_jour"] == picked].copy()

            # Score congestion = taux_occ × poids blocage
            if {"taux_occupation_moyen","nb_heures_bloque"} <= set(dfd.columns):
                dfd["score_congestion"] = (
                    _num(dfd["taux_occupation_moyen"]) +
                    _num(dfd["nb_heures_bloque"]) * 10
                ).round(1)

            topN = st.slider("Top N arcs", 1, 30, 10, key="top_n_cong")
            if {"score_congestion","libelle_arc"} <= set(dfd.columns):
                top = (dfd.sort_values("score_congestion", ascending=False)
                          .drop_duplicates("libelle_arc").head(topN))
                st.caption(f"Top {topN} arcs congestionnés le {picked.strftime('%Y-%m-%d')}")
                st.bar_chart(top.set_index("libelle_arc")["score_congestion"])

                top_arcs = top["libelle_arc"].tolist()
                if "date_jour" in df.columns:
                    evo = df[df["libelle_arc"].isin(top_arcs)].pivot_table(
                        index="date_jour", columns="libelle_arc",
                        values="score_congestion", aggfunc="mean"
                    )
                    st.caption("Évolution temporelle")
                    st.line_chart(evo)

        # ─────────────────────────────────────────────────────────
        # KPI 3 — Alertes Pollution (dm_alertes_pollution)
        # Colonnes : code_site, nom_site, polluant, date_mesure,
        #            valeur_max_journaliere, ratio_depassement, seuil_reglementaire, type_seuil
        # ─────────────────────────────────────────────────────────
        elif kpi_display == "alertes_pollution":
            if "valeur_max_journaliere" in df.columns: df["valeur_max_journaliere"] = _num(df["valeur_max_journaliere"])
            if "date_mesure"            in df.columns: df["date_mesure"] = _date(df["date_mesure"])

            polluants = sorted(df["polluant"].dropna().unique()) if "polluant" in df.columns else []
            pol = st.selectbox("Polluant", polluants, key="alert_pol") if polluants else None

            if pol:
                dfd = df[df["polluant"] == pol].copy()
                dates = sorted(dfd["date_mesure"].dropna().dt.strftime("%Y-%m-%d").unique())
                choice = st.selectbox("Date", ["Date la plus récente"] + dates, key="alert_date")
                picked = dfd["date_mesure"].max() if choice == "Date la plus récente" else pd.to_datetime(choice)
                dfd = dfd[dfd["date_mesure"] == picked]

                topN = st.slider("Top N sites", 1, 30, 10, key="alert_topN")
                if {"valeur_max_journaliere","nom_site"} <= set(dfd.columns):
                    top = dfd.sort_values("valeur_max_journaliere", ascending=False).drop_duplicates("nom_site").head(topN)
                    st.caption(f"Sites en alerte {pol} le {picked.strftime('%Y-%m-%d')}")
                    st.bar_chart(top.set_index("nom_site")["valeur_max_journaliere"])

        # ─────────────────────────────────────────────────────────
        # KPI 4 — Heures Critiques Trafic (dm_trafic_routier_daily)
        # On utilise les colonnes nb_heures_* pour reconstituer la répartition
        # ─────────────────────────────────────────────────────────
        elif kpi_display == "heures_trafic":
            for c in ["debit_moyen","taux_occupation_moyen","nb_heures_bloque","nb_heures_dense","nb_heures_fluide"]:
                if c in df.columns: df[c] = _num(df[c])
            if "date_jour" in df.columns: df["date_jour"] = _date(df["date_jour"])

            dates = sorted(df["date_jour"].dropna().dt.strftime("%Y-%m-%d").unique())
            choice = st.selectbox("Date", ["Date la plus récente"] + dates, key="ht_date")
            picked = df["date_jour"].max() if choice == "Date la plus récente" else pd.to_datetime(choice)
            dfd = df[df["date_jour"] == picked].copy()

            col1, col2 = st.columns(2)
            with col1:
                if "debit_moyen" in dfd.columns:
                    st.caption("Débit moyen")
                    st.bar_chart(dfd.set_index("arc_id")["debit_moyen"] if "arc_id" in dfd.columns else dfd["debit_moyen"])
            with col2:
                if "taux_occupation_moyen" in dfd.columns:
                    st.caption("Taux d'occupation moyen (%)")
                    st.bar_chart(dfd.set_index("arc_id")["taux_occupation_moyen"] if "arc_id" in dfd.columns else dfd["taux_occupation_moyen"])

            cols_states = [c for c in ["nb_heures_fluide","nb_heures_dense","nb_heures_bloque"] if c in dfd.columns]
            if len(cols_states) == 3:
                totaux = {c: dfd[c].sum() for c in cols_states}
                st.caption("Répartition des états de circulation (total heures)")
                st.bar_chart(pd.Series(totaux))

        # ─────────────────────────────────────────────────────────
        # KPI 5 — Trafic Journalier (dm_trafic_routier_daily)
        # ─────────────────────────────────────────────────────────
        elif kpi_display == "trafic_journalier":
            for c in ["debit_moyen","taux_occupation_moyen","nb_heures_bloque","nb_heures_dense","nb_heures_fluide"]:
                if c in df.columns: df[c] = _num(df[c])
            if "date_jour" in df.columns: df["date_jour"] = _date(df["date_jour"])
            dfs = df.sort_values("date_jour")

            col1, col2 = st.columns(2)
            with col1:
                if {"date_jour","debit_moyen"} <= set(dfs.columns):
                    agg = dfs.groupby("date_jour")["debit_moyen"].mean()
                    st.caption("Débit moyen journalier")
                    st.line_chart(agg)
            with col2:
                if {"date_jour","taux_occupation_moyen"} <= set(dfs.columns):
                    agg = dfs.groupby("date_jour")["taux_occupation_moyen"].mean()
                    st.caption("Taux d'occupation moyen")
                    st.line_chart(agg)

            cols_states = [c for c in ["nb_heures_fluide","nb_heures_dense","nb_heures_bloque"] if c in dfs.columns]
            if len(cols_states) == 3:
                pct = dfs.groupby("date_jour")[cols_states].sum()
                pct = pct.div(pct.sum(axis=1), axis=0).mul(100)
                st.caption("Répartition des états de circulation (%)")
                st.area_chart(pct)

        # ─────────────────────────────────────────────────────────
        # KPI 6 — Vélo Journalier (dm_velo_daily)
        # Colonnes : compteur_id, compteur_nom, nom_site, date_jour,
        #            total_passages_jour, nb_mesures_horaires, pic_horaire
        # ─────────────────────────────────────────────────────────
        elif kpi_display == "velo_journalier":
            if "total_passages_jour" in df.columns: df["total_passages_jour"] = _num(df["total_passages_jour"])
            if "date_jour"           in df.columns: df["date_jour"] = _date(df["date_jour"])
            dfs = df.sort_values("date_jour")

            dates = sorted(dfs["date_jour"].dropna().dt.strftime("%Y-%m-%d").unique())
            choice = st.selectbox("Date", ["Date la plus récente"] + dates, key="velo_date")
            picked = dfs["date_jour"].max() if choice == "Date la plus récente" else pd.to_datetime(choice)
            dfd = dfs[dfs["date_jour"] == picked].copy()

            topN = st.slider("Top N sites", 5, 30, 10, key="velo_topN")
            if {"total_passages_jour","compteur_nom"} <= set(dfd.columns):
                top = dfd.sort_values("total_passages_jour", ascending=False).drop_duplicates("compteur_nom").head(topN)
                st.caption(f"Top {topN} compteurs le {picked.strftime('%Y-%m-%d')}")
                st.bar_chart(top.set_index("compteur_nom")["total_passages_jour"])

                top_sites = top["compteur_nom"].tolist()
                evo = dfs[dfs["compteur_nom"].isin(top_sites)].pivot_table(
                    index="date_jour", columns="compteur_nom", values="total_passages_jour", aggfunc="sum"
                )
                st.caption("Évolution temporelle des top sites")
                st.line_chart(evo)

            if {"date_jour","total_passages_jour"} <= set(dfs.columns):
                ts = dfs.groupby("date_jour")["total_passages_jour"].sum()
                st.caption("Trafic vélo total (tous compteurs)")
                st.line_chart(ts)

            c1, c2, c3, c4 = st.columns(4)
            if "total_passages_jour" in dfd.columns:
                c1.metric("Total passages", f"{dfd['total_passages_jour'].sum():,.0f}")
                c2.metric("Moyenne/site", f"{dfd['total_passages_jour'].mean():,.0f}")
                c3.metric("Maximum", f"{dfd['total_passages_jour'].max():,.0f}")
                c4.metric("Sites actifs", int((dfd["total_passages_jour"] > 0).sum()))

        # ─────────────────────────────────────────────────────────
        # KPI 7 — Qualité de l'Air (dm_air_quality_daily)
        # Colonnes : code_site, nom_site, polluant, date_mesure,
        #            valeur_moyenne, valeur_max, valeur_min, nb_mesures
        # ─────────────────────────────────────────────────────────
        elif kpi_display == "air_quality_journalier":
            for c in ["valeur_moyenne","valeur_max"]:
                if c in df.columns: df[c] = _num(df[c])
            if "date_mesure" in df.columns: df["date_mesure"] = _date(df["date_mesure"])

            if {"date_mesure","polluant","valeur_moyenne"} <= set(df.columns):
                pivot = df.pivot_table(index="date_mesure", columns="polluant", values="valeur_moyenne", aggfunc="mean")
                st.caption("Évolution journalière des polluants (µg/m³)")
                st.line_chart(pivot)

            dates = sorted(df["date_mesure"].dropna().dt.strftime("%Y-%m-%d").unique())
            choice = st.selectbox("Date", ["Date la plus récente"] + dates, key="aq_date")
            picked = df["date_mesure"].max() if choice == "Date la plus récente" else pd.to_datetime(choice)
            dfd = df[df["date_mesure"] == picked]

            if {"polluant","valeur_moyenne"} <= set(dfd.columns):
                chart = dfd.groupby("polluant")["valeur_moyenne"].mean().sort_values(ascending=False)
                st.caption(f"Niveau moyen par polluant le {picked.strftime('%Y-%m-%d')}")
                st.bar_chart(chart)

            polluants = sorted(dfd["polluant"].dropna().unique()) if "polluant" in dfd.columns else []
            pol = st.selectbox("Polluant (top sites exposés)", polluants, key="aq_pol") if polluants else None
            if pol and {"valeur_max","nom_site"} <= set(dfd.columns):
                top = dfd[dfd["polluant"]==pol].groupby("nom_site")["valeur_max"].max().sort_values(ascending=False).head(10)
                st.caption(f"Top 10 sites exposés au {pol}")
                st.bar_chart(top)

        # ─────────────────────────────────────────────────────────
        # KPI 8 — Croisement Vélos / Trafic / Air (dm_smartcity_kpi_daily)
        # ─────────────────────────────────────────────────────────
        elif kpi_display == "velo_trafic_air":
            for c in ["total_velos","debit_routier_moyen","taux_occupation_moyen","no2_moyen","pm10_moyen"]:
                if c in df.columns: df[c] = _num(df[c])
            if "date_jour" in df.columns: df["date_jour"] = _date(df["date_jour"])
            dfs = df.sort_values("date_jour")

            col1, col2 = st.columns(2)
            with col1:
                if {"date_jour","total_velos"} <= set(dfs.columns):
                    st.caption("Trafic vélo total")
                    st.line_chart(dfs.set_index("date_jour")["total_velos"])
            with col2:
                if {"date_jour","debit_routier_moyen"} <= set(dfs.columns):
                    st.caption("Débit routier moyen")
                    st.line_chart(dfs.set_index("date_jour")["debit_routier_moyen"])

            poll_cols = [c for c in ["no2_moyen","pm10_moyen","pm25_moyen","o3_moyen"] if c in dfs.columns]
            if poll_cols:
                st.caption("Polluants (µg/m³)")
                st.line_chart(dfs.set_index("date_jour")[poll_cols])

            # Heatmap calendrier
            st.divider()
            st.subheader("Heatmap calendrier (heure × jour)")
            if "date_jour" in dfs.columns and "total_velos" in dfs.columns:
                cal = dfs.copy()
                cal["ym"]   = cal["date_jour"].dt.strftime("%Y-%m")
                cal["day"]  = cal["date_jour"].dt.day
                ym_opts = sorted(cal["ym"].dropna().unique())
                if ym_opts:
                    ym = st.selectbox("Mois", ym_opts, index=len(ym_opts)-1, key="heatmap_ym")
                    heat = cal[cal["ym"]==ym].groupby("day")["total_velos"].sum().reset_index()
                    chart_cal = (alt.Chart(heat).mark_rect()
                        .encode(
                            x=alt.X("day:O", title="Jour"),
                            color=alt.Color("total_velos:Q", title="Total vélos"),
                            tooltip=["day:O","total_velos:Q"]
                        ))
                    st.altair_chart(chart_cal, use_container_width=True)

# ─────────────────────────────────────────────────────────
# Section 2 — Téléchargement CSV / ZIP
# ─────────────────────────────────────────────────────────
with right:
    st.subheader("2) Télécharger des KPI (CSV)")

    select_all = st.checkbox("Tout sélectionner", value=False, key="dl_all")
    kpi_to_dl = st.multiselect(
        "KPI à télécharger",
        list(KPI_LABELS.keys()),
        format_func=lambda k: KPI_LABELS[k],
        default=list(KPI_LABELS.keys()) if select_all else [],
        key="dl_kpis"
    )

    if st.button("Préparer les CSV", key="btn_csv"):
        if not kpi_to_dl:
            st.warning("Sélectionne au moins un KPI.")
        else:
            csv_files = {}
            for k in kpi_to_dl:
                try:
                    df_dl = load_table(TABLES[k])
                    if not df_dl.empty:
                        csv_files[f"{k}.csv"] = csv_bytes(df_dl)
                    else:
                        st.warning(f"Vide : {k}")
                except Exception as e:
                    st.error(f"Erreur {k} : {e}")

            if csv_files:
                from datetime import datetime as _dt
                ts = _dt.now().strftime("%Y%m%d_%H%M%S")
                st.download_button(
                    "Télécharger tout en ZIP",
                    make_zip(csv_files),
                    file_name=f"novasight_kpi_{ts}.zip",
                    mime="application/zip",
                    use_container_width=True
                )
                st.divider()
                for fname, content in csv_files.items():
                    st.download_button(
                        f"Télécharger {fname}",
                        content,
                        file_name=fname,
                        mime="text/csv",
                        use_container_width=True
                    )
