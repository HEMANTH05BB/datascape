import streamlit as st
import pandas as pd
import plotly.express as px

df = pd.read_csv("ObesityDataSet_raw_and_data_sinthetic.csv")
df["AgeBand"] = pd.cut(df["Age"], bins=[0,20,25,30,40,100],
                       labels=["<20","20-25","26-30","31-40","41+"])

# Filters
gender = st.sidebar.multiselect("Gender", df["Gender"].unique())
favc = st.sidebar.multiselect("High Calorie Food (FAVC)", df["FAVC"].unique())
faf = st.sidebar.slider("Physical Activity (FAF)", 0, 3)
calc = st.sidebar.multiselect("Alcohol (CALC)", df["CALC"].unique())
fh = st.sidebar.multiselect("Family History", df["family_history_with_overweight"].unique())

# Filter data
filtered = df[
    (df["Gender"].isin(gender) if gender else True) &
    (df["FAVC"].isin(favc) if favc else True) &
    (df["CALC"].isin(calc) if calc else True) &
    (df["FAF"] >= faf)
]

# Chart 1
fig1 = px.bar(filtered, x="Gender", color="NObeyesdad", title="Obesity by Gender")
st.plotly_chart(fig1)
