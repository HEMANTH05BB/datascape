# dashboard.py
import pandas as pd
import streamlit as st
import plotly.express as px
import numpy as np

# --- load data (update path if needed) ---
PATH = "/mnt/data/ObesityDataSet_raw_and_data_sinthetic.csv"
df = pd.read_csv(PATH)

# --- basic cleaning & derived columns ---
# Ensure correct column names
df.columns = [c.strip() for c in df.columns]

# Compute BMI if not present
if "BMI" not in df.columns:
    # Height expected in meters
    df["BMI"] = df["Weight"] / (df["Height"] ** 2)

# Age band
bins = [0, 17, 24, 34, 44, 54, 120]
labels = ["<18","18-24","25-34","35-44","45-54","55+"]
df["AgeBand"] = pd.cut(df["Age"].astype(float), bins=bins, labels=labels, include_lowest=True)

# Map NObeyesdad to simple groups (Underweight/Normal/Overweight/Obese)
mapping = {
    "Insufficient_Weight": "Underweight",
    "Normal_Weight": "Normal",
    "Overweight_Level_I": "Overweight",
    "Overweight_Level_II": "Overweight",
    "Obesity_Type_I": "Obese",
    "Obesity_Type_II": "Obese",
    "Obesity_Type_III": "Obese"
}
if "NObeyesdad" in df.columns:
    df["ObesityGroup"] = df["NObeyesdad"].map(mapping).fillna(df.get("NObeyesdad"))

# Convert FAF to numeric if noisy
df["FAF"] = pd.to_numeric(df["FAF"], errors="coerce")

# --- Sidebar filters ---
st.sidebar.header("Filters")
genders = st.sidebar.multiselect("Gender", options=sorted(df["Gender"].dropna().unique()), default=sorted(df["Gender"].dropna().unique()))
agebands = st.sidebar.multiselect("Age bands", options=labels, default=labels)
favc_sel = st.sidebar.multiselect("FAVC (high cal food)", options=sorted(df["FAVC"].dropna().unique()), default=sorted(df["FAVC"].dropna().unique()))
calc_sel = st.sidebar.multiselect("CALC (calorie consumption)", options=sorted(df["CALC"].dropna().unique()), default=sorted(df["CALC"].dropna().unique()))
fam_hist_sel = st.sidebar.multiselect("Family history with overweight", options=sorted(df["family_history_with_overweight"].dropna().unique()), default=sorted(df["family_history_with_overweight"].dropna().unique()))
faf_min, faf_max = float(df["FAF"].min(skipna=True)), float(df["FAF"].max(skipna=True))
faf_range = st.sidebar.slider("FAF (physical activity) range", min_value=float(np.floor(faf_min)), max_value=float(np.ceil(faf_max)), value=(float(np.floor(faf_min)), float(np.ceil(faf_max))))

# Apply filters
mask = (
    df["Gender"].isin(genders) &
    df["AgeBand"].isin(agebands) &
    df["FAVC"].isin(favc_sel) &
    df["CALC"].isin(calc_sel) &
    df["family_history_with_overweight"].isin(fam_hist_sel) &
    df["FAF"].between(faf_range[0], faf_range[1])
)
filtered = df[mask].copy()

# --- Top metrics ---
st.title("Obesity Explorer Dashboard")
c1, c2, c3 = st.columns(3)
total = len(filtered)
obese_pct = (filtered["ObesityGroup"] == "Obese").mean() * 100 if "ObesityGroup" in filtered.columns else None
avg_bmi = filtered["BMI"].mean()

c1.metric("Records", f"{total}")
c2.metric("Avg BMI", f"{avg_bmi:.2f}")
c3.metric("% Obese", f"{obese_pct:.1f}%" if obese_pct is not None else "N/A")

# --- Chart 1: Gender distribution ---
st.subheader("Gender distribution")
fig1 = px.histogram(filtered, x="Gender", title="Count by Gender", text_auto=True)
st.plotly_chart(fig1, use_container_width=True)

# --- Chart 2: Age band counts ---
st.subheader("Age band distribution")
fig2 = px.histogram(filtered, x="AgeBand", category_orders={"AgeBand": labels}, title="Count by Age band", text_auto=True)
st.plotly_chart(fig2, use_container_width=True)

# --- Chart 3: Stacked proportions of Obesity by Age band ---
if "ObesityGroup" in filtered.columns:
    st.subheader("Obesity group proportion by Age band")
    fig3 = px.histogram(filtered, x="AgeBand", color="ObesityGroup", barnorm="percent",
                        category_orders={"AgeBand": labels},
                        title="Proportion of Obesity groups per Age band")
    fig3.update_layout(yaxis_title="Percent (%)")
    st.plotly_chart(fig3, use_container_width=True)

# --- Chart 4: BMI boxplot by FAVC and CALC ---
st.subheader("BMI distributions by dietary behaviors")
fig4 = px.box(filtered, x="FAVC", y="BMI", color="CALC", points="outliers",
              title="BMI by FAVC (freq high-cal food) split by CALC")
st.plotly_chart(fig4, use_container_width=True)

# --- Chart 5: Heatmap — % obese by FAVC x family_history_with_overweight ---
st.subheader("Obesity prevalence by FAVC and family history")
if "ObesityGroup" in filtered.columns:
    pivot = (filtered.assign(is_obese = (filtered["ObesityGroup"]=="Obese").astype(int))
             .groupby(["FAVC","family_history_with_overweight"])["is_obese"]
             .mean().unstack().fillna(0))
    fig5 = px.imshow(pivot*100, text_auto=".1f", title="% Obese (FAVC × Family history)")
    fig5.update_layout(xaxis_title="Family history", yaxis_title="FAVC")
    st.plotly_chart(fig5, use_container_width=True)

# --- Optional scatter (Weight vs Height colored by ObesityGroup) ---
st.subheader("Weight vs Height (diagnostic)")
fig6 = px.scatter(filtered, x="Height", y="Weight", color="ObesityGroup" if "ObesityGroup" in filtered.columns else None,
                  hover_data=["Age","BMI"], title="Weight vs Height colored by obesity group", opacity=0.8)
st.plotly_chart(fig6, use_container_width=True)

# --- Data table / export ---
with st.expander("View data table"):
    st.dataframe(filtered.reset_index(drop=True))
st.markdown("**How to interpret:** use the filters to compare groups (e.g., FAVC=yes vs no).")
