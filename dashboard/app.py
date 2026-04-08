"""
UNITEE - Dashboard Streamlit
Veille automatisée marchés publics (Bâtiment Modulaire)

Usage:
    streamlit run dashboard/app.py

Connexion: MySQL unitee via mysql-connector-python
Variables: DB_HOST, DB_USER, DB_PASS, DB_NAME (ou defaults)
"""

import os
import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from sqlalchemy import create_engine, text
from datetime import datetime

# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────

st.set_page_config(
    page_title="UNITEE - Veille Marches Publics",
    page_icon=":building_construction:",
    layout="wide",
    initial_sidebar_state="expanded",
)

DB_URL = (
    f"mysql+mysqlconnector://"
    f"{os.getenv('DB_USER', 'unitee_user')}:"
    f"{os.getenv('DB_PASS', 'UniteeStrong1234')}@"
    f"{os.getenv('DB_HOST', 'localhost')}:"
    f"{os.getenv('DB_PORT', '3306')}/"
    f"{os.getenv('DB_NAME', 'unitee')}?charset=utf8mb4"
)

# ─────────────────────────────────────────────
# CONNEXION
# ─────────────────────────────────────────────

@st.cache_resource(show_spinner=False)
def get_engine():
    """Retourne un engine SQLAlchemy (mis en cache)."""
    try:
        engine = create_engine(DB_URL, pool_pre_ping=True)
        return engine
    except Exception as e:
        st.error(f"Connexion MySQL impossible : {e}")
        return None


def run_query(sql: str) -> pd.DataFrame:
    """Execute une requete SELECT et retourne un DataFrame."""
    engine = get_engine()
    if engine is None:
        return pd.DataFrame()
    try:
        with engine.connect() as conn:
            return pd.read_sql(text(sql), conn)
    except Exception as e:
        st.warning(f"Erreur requete : {e}")
        return pd.DataFrame()


# ─────────────────────────────────────────────
# SIDEBAR
# ─────────────────────────────────────────────

with st.sidebar:
    st.title("UNITEE")
    st.caption("Veille marchés publics — Bâtiment modulaire")
    st.divider()

    # Filtre région
    regions_df = run_query("SELECT DISTINCT region FROM annonces WHERE region IS NOT NULL ORDER BY region")
    regions = ["Toutes"] + list(regions_df["region"]) if not regions_df.empty else ["Toutes"]
    filtre_region = st.selectbox("Région", regions)

    # Filtre statut
    filtre_statut = st.multiselect(
        "Statut",
        options=["NEW", "QUALIFIED", "IGNORED", "RESPONDED"],
        default=["NEW", "QUALIFIED"],
    )

    st.divider()
    if st.button("Rafraîchir les données"):
        st.cache_data.clear()
        st.rerun()

    st.caption(f"Actualisé le {datetime.now().strftime('%d/%m/%Y %H:%M')}")


# ─────────────────────────────────────────────
# DONNÉES DEPUIS LES VUES
# ─────────────────────────────────────────────

@st.cache_data(ttl=300)
def load_kpi():
    return run_query("SELECT * FROM vw_kpi_resume LIMIT 1")

@st.cache_data(ttl=300)
def load_priorite():
    return run_query("SELECT * FROM vw_repartition_priorite")

@st.cache_data(ttl=300)
def load_evolution():
    return run_query("SELECT * FROM vw_evolution_temporelle ORDER BY date_publication")

@st.cache_data(ttl=300)
def load_geo():
    return run_query("SELECT * FROM vw_repartition_geo ORDER BY nb_annonces DESC")

@st.cache_data(ttl=300)
def load_alertes():
    return run_query("SELECT * FROM vw_alertes_prioritaires ORDER BY jours_restants ASC LIMIT 20")

@st.cache_data(ttl=300)
def load_sources():
    return run_query("SELECT * FROM vw_performance_sources")

@st.cache_data(ttl=300)
def load_qualite():
    return run_query("SELECT * FROM vw_qualite_donnees LIMIT 1")


def load_annonces_filtrees(region: str, statuts: list) -> pd.DataFrame:
    where_parts = []
    if region != "Toutes":
        safe_region = region.replace("'", "''")
        where_parts.append(f"a.region = '{safe_region}'")
    if statuts:
        statuts_str = ", ".join(f"'{s}'" for s in statuts)
        where_parts.append(f"a.statut IN ({statuts_str})")
    where_clause = f"WHERE {' AND '.join(where_parts)}" if where_parts else ""
    sql = f"""
        SELECT
            a.id_annonce,
            a.titre,
            a.region,
            a.statut,
            a.montant_estime,
            a.date_publication,
            a.date_limite_reponse,
            DATEDIFF(a.date_limite_reponse, NOW()) AS jours_restants,
            s.nom_source,
            qs.score_pertinence,
            qs.niveau_alerte
        FROM annonces a
        JOIN sources s ON a.source_id = s.id_source
        LEFT JOIN qualification_scores qs ON a.id_annonce = qs.annonce_id
        {where_clause}
        ORDER BY a.date_limite_reponse ASC
        LIMIT 200
    """
    return run_query(sql)


# ─────────────────────────────────────────────
# TITRE
# ─────────────────────────────────────────────

st.title("🏗️ UNITEE — Tableau de bord Veille Marchés Publics")
st.caption("Marchés publics bâtiment modulaire · Données temps réel")
st.divider()

# ─────────────────────────────────────────────
# KPI ROW
# ─────────────────────────────────────────────

kpi = load_kpi()
qualite = load_qualite()

col1, col2, col3, col4, col5, col6 = st.columns(6)

if not kpi.empty:
    row = kpi.iloc[0]
    col1.metric("Total annonces",   int(row.get("total_annonces", 0)))
    col2.metric("Avec montant",     int(row.get("annonces_avec_montant", 0)))
    col3.metric("Montant moyen",    f"{float(row.get('montant_moyen', 0)):,.0f} €")
    col4.metric("Régions couvertes", int(row.get("regions_couvertes", 0)))
    col5.metric("Sources actives",  int(row.get("sources_actives", 0)))
    if not qualite.empty:
        taux = qualite.iloc[0].get("taux_unicite_pct", 100)
        col6.metric("Unicité données", f"{float(taux):.1f} %")
else:
    st.warning("KPI non disponibles.")

st.divider()

# ─────────────────────────────────────────────
# ROW 2 : Priorité + Évolution temporelle
# ─────────────────────────────────────────────

col_left, col_right = st.columns([1, 2])

with col_left:
    st.subheader("Répartition par niveau d'alerte")
    priorite = load_priorite()
    if not priorite.empty and "niveau_alerte" in priorite.columns:
        color_map = {
            "CRITIQUE": "#e74c3c",
            "URGENT":   "#e67e22",
            "NORMAL":   "#2ecc71",
            "IGNORE":   "#95a5a6",
        }
        fig_pie = px.pie(
            priorite,
            names="niveau_alerte",
            values="nb_annonces",
            color="niveau_alerte",
            color_discrete_map=color_map,
            hole=0.4,
        )
        fig_pie.update_traces(textposition="inside", textinfo="percent+label")
        fig_pie.update_layout(showlegend=False, margin=dict(t=20, b=20, l=20, r=20), height=300)
        st.plotly_chart(fig_pie, use_container_width=True)

        # Scores moyens par niveau
        if "score_moyen" in priorite.columns:
            st.dataframe(
                priorite[["niveau_alerte", "nb_annonces", "score_moyen"]].rename(columns={
                    "niveau_alerte": "Niveau",
                    "nb_annonces":   "Nb",
                    "score_moyen":   "Score moy.",
                }),
                hide_index=True,
                use_container_width=True,
            )
    else:
        st.info("Aucune donnée de qualification disponible.")

with col_right:
    st.subheader("Évolution temporelle des annonces")
    evolution = load_evolution()
    if not evolution.empty and "date_publication" in evolution.columns:
        evolution["date_publication"] = pd.to_datetime(evolution["date_publication"])
        fig_line = px.bar(
            evolution,
            x="date_publication",
            y="nb_annonces",
            color_discrete_sequence=["#3498db"],
            labels={"date_publication": "Date", "nb_annonces": "Annonces"},
        )
        if "montant_moyen" in evolution.columns:
            fig_line.add_scatter(
                x=evolution["date_publication"],
                y=evolution["montant_moyen"] / 10000,
                mode="lines+markers",
                name="Montant moy. (÷10k€)",
                yaxis="y2",
                line=dict(color="#e67e22", width=2),
            )
            fig_line.update_layout(yaxis2=dict(overlaying="y", side="right", showgrid=False))
        fig_line.update_layout(margin=dict(t=20, b=40), height=320, showlegend=True)
        st.plotly_chart(fig_line, use_container_width=True)
    else:
        st.info("Aucune donnée temporelle.")

st.divider()

# ─────────────────────────────────────────────
# ROW 3 : Géographie + Sources
# ─────────────────────────────────────────────

col_geo, col_src = st.columns(2)

with col_geo:
    st.subheader("Répartition géographique")
    geo = load_geo()
    if not geo.empty and "region" in geo.columns:
        fig_geo = px.bar(
            geo.head(10),
            x="nb_annonces",
            y="region",
            orientation="h",
            color="montant_moyen" if "montant_moyen" in geo.columns else "nb_annonces",
            color_continuous_scale="Blues",
            labels={"nb_annonces": "Annonces", "region": "Région", "montant_moyen": "Montant moy. (€)"},
        )
        fig_geo.update_layout(margin=dict(t=20, b=20), height=350, coloraxis_showscale=False)
        st.plotly_chart(fig_geo, use_container_width=True)
    else:
        st.info("Aucune donnée géographique.")

with col_src:
    st.subheader("Performance des sources")
    sources = load_sources()
    if not sources.empty and "nom_source" in sources.columns:
        cols_show = ["nom_source", "nb_annonces_total", "montant_moyen", "annonces_30_derniers_jours"]
        cols_available = [c for c in cols_show if c in sources.columns]
        rename_map = {
            "nom_source":                   "Source",
            "nb_annonces_total":            "Total",
            "montant_moyen":                "Montant moy. (€)",
            "annonces_30_derniers_jours":   "30 derniers jours",
        }
        st.dataframe(
            sources[cols_available].rename(columns=rename_map),
            hide_index=True,
            use_container_width=True,
        )

        # Graphique part des sources
        fig_src = px.pie(
            sources,
            names="nom_source",
            values="nb_annonces_total",
            color_discrete_sequence=px.colors.qualitative.Set2,
            hole=0.35,
        )
        fig_src.update_traces(textposition="inside", textinfo="percent+label")
        fig_src.update_layout(showlegend=False, margin=dict(t=20, b=20), height=250)
        st.plotly_chart(fig_src, use_container_width=True)
    else:
        st.info("Aucune donnée sources.")

st.divider()

# ─────────────────────────────────────────────
# ROW 4 : Alertes prioritaires
# ─────────────────────────────────────────────

st.subheader("Alertes prioritaires (deadline imminente)")
alertes = load_alertes()
if not alertes.empty:
    def badge_niveau(niveau):
        colors = {"CRITIQUE": "🔴", "URGENT": "🟠", "NORMAL": "🟢", "IGNORE": "⚪"}
        return colors.get(niveau, "⚪") + " " + str(niveau)

    alertes_display = alertes.copy()
    if "niveau_alerte" in alertes_display.columns:
        alertes_display["niveau_alerte"] = alertes_display["niveau_alerte"].apply(badge_niveau)
    if "score_pertinence" in alertes_display.columns:
        alertes_display["score_pertinence"] = alertes_display["score_pertinence"].apply(lambda x: f"{x}/100")
    if "jours_restants" in alertes_display.columns:
        alertes_display["jours_restants"] = alertes_display["jours_restants"].apply(
            lambda x: f"⚠️ {x}j" if isinstance(x, (int, float)) and x <= 7 else f"{x}j"
        )

    rename_alertes = {
        "id_annonce":     "ID",
        "titre":          "Titre",
        "jours_restants": "Délai",
        "score_pertinence": "Score",
        "niveau_alerte":  "Niveau",
    }
    cols_alertes = [c for c in rename_alertes if c in alertes_display.columns]
    st.dataframe(
        alertes_display[cols_alertes].rename(columns=rename_alertes),
        hide_index=True,
        use_container_width=True,
        height=250,
    )
else:
    st.success("Aucune alerte prioritaire en cours.")

st.divider()

# ─────────────────────────────────────────────
# ROW 5 : Tableau annonces filtré
# ─────────────────────────────────────────────

st.subheader(f"Annonces — {filtre_region} · {', '.join(filtre_statut) if filtre_statut else 'tous statuts'}")

annonces = load_annonces_filtrees(filtre_region, filtre_statut)
if not annonces.empty:
    st.caption(f"{len(annonces)} annonce(s) trouvée(s)")

    # Montant formaté
    if "montant_estime" in annonces.columns:
        annonces["montant_estime"] = annonces["montant_estime"].apply(
            lambda x: f"{float(x):,.0f} €" if pd.notna(x) else "N/A"
        )
    if "score_pertinence" in annonces.columns:
        annonces["score_pertinence"] = annonces["score_pertinence"].apply(
            lambda x: f"{int(x)}/100" if pd.notna(x) else "—"
        )

    rename_annonces = {
        "id_annonce":         "ID",
        "titre":              "Titre",
        "region":             "Région",
        "statut":             "Statut",
        "montant_estime":     "Montant",
        "date_publication":   "Publication",
        "date_limite_reponse":"Deadline",
        "jours_restants":     "Jours restants",
        "nom_source":         "Source",
        "score_pertinence":   "Score",
        "niveau_alerte":      "Niveau",
    }
    cols_show = [c for c in rename_annonces if c in annonces.columns]
    st.dataframe(
        annonces[cols_show].rename(columns=rename_annonces),
        hide_index=True,
        use_container_width=True,
        height=400,
    )
else:
    st.info("Aucune annonce correspondant aux filtres.")

# ─────────────────────────────────────────────
# FOOTER
# ─────────────────────────────────────────────
st.divider()
st.caption("UNITEE · Veille automatisée marchés publics · MySQL 8.0 · Streamlit")
