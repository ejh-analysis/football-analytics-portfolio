# Football Data Science & Analytics Portfolio

Welcome! I am Emily, a Data Scientist, with a BSc in Mathematics and an MSc in Data Science. Enthusiastic about sports analytics and data. 
Specialising in statistical analysis and machine learning using high-dimensional performance data to support player profiling and positional discovery in football.

## 📌 Featured Projects

| Project | Focus Area | Tech Stack | Status / Deliverables |
| :--- | :--- | :--- | :--- |
| **[1. FA WSL Interactive Scouting Matrix](./StatsBomb_Dashboard_1/)** | Event Data Analytics & Spatial Metrics | R (Shiny, StatsBombR, ggplot2, plotly) | [![Live App](https://img.shields.io/badge/shinyapps.io-Live%20Explorer-0284c7?style=flat&logo=r)](https://ejh-analysis.shinyapps.io/wsl-scouting-explorer/) |
| **[2. Optical Telemetry & Bayesian Load Forecasting](./tracking-kinematics-forecasting/)** | 25Hz Tracking Kinematics & MCMC Forecasting | Python (PyMC, ArviZ, SciPy, Pandas) | [View Module Code & Diagnostics](./tracking-kinematics-forecasting/) |

---

## 📁 Repository Structure

```text
football-analytics-portfolio/
│
├── StatsBomb_Dashboard_1/          # [Project 1] R/Shiny Scouting Application
│   ├── app.R                       # Production reactive UI and server
│   ├── Analysis.R                  # StatsBomb API ETL & metric derivation
│   └── players_data.rds            # Serialized Per-90 aggregate cache
│
├── python-portfolio/               # [Project 2] Python Telemetry & Bayesian Engine
│   ├── src/
│   │   ├── tracking_loader.py      # 25Hz Savitzky-Golay coordinate smoothing
│   │   └── bayesian_load_model.py  # Latent AR(1) MCMC fatigue decay forecaster
│   ├── requirements.txt            # Python dependencies (PyMC, ArviZ, etc.)
│   └── README.md                   # In-depth statistical writeup & diagnostics
│
├── wsl_offensive_threat_matrix.png  # High-res static visual artifact
└── README.md                       # Master portfolio documentation