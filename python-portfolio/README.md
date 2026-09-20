# 🛰️ Optical Tracking & Bayesian Physical Load Forecasting

[![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org/)
[![PyMC](https://img.shields.io/badge/PyMC-v5.10-red?style=flat)](https://www.pymc.io/)
[![ArviZ](https://img.shields.io/badge/ArviZ-Diagnostics-orange?style=flat)](https://arviz-devs.github.io/arviz/)

An applied football analytics module parsing 25Hz optical tracking telemetry and modeling physical fatigue degradation across match intervals using Bayesian state-space autoregression.

---

## 📌 Technical Pipeline

```text
[Metrica 25Hz Optical Stream]
             │
             ▼
[tracking_loader.py] ─── Savitzky-Golay Coordinate Smoothing (25Hz)
             │        ─── Continuous Velocity & Acceleration Derivation
             ▼        ─── High-Intensity Running Flag (≥ 5.5 m/s)
[Sprint Interval Aggregates]
             │
             ▼
[bayesian_load_model.py] ─── Latent AR(1) State-Space Model in PyMC
             │           ─── Student-t Observation Likelihood (Fat-Tailed Bursts)
             ▼
[ArviZ Diagnostics Engine] ─── MCMC Convergence (r_hat ≤ 1.01, ESS Bulk)