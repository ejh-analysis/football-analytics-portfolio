"""
bayesian_load_model.py
Bayesian Latent AR(1) state-space model for sprint-load decay across match segments.
Direct match for FA telemetry forecasting and MCMC statistical validation.
"""

import arviz as az
import numpy as np
import pymc as pm


def fit_physical_decay_model(sprint_counts: np.ndarray) -> az.InferenceData:
    """
    Fits an autoregressive AR(1) latent state-space model with Student-t likelihood
    to capture dynamic physical load degradation across match segments.
    """
    n_bins = len(sprint_counts)

    with pm.Model() as model:
        # Priors on autoregressive persistence and volatility
        rho = pm.Beta("rho", alpha=2.0, beta=2.0)
        sigma_latent = pm.HalfNormal("sigma_latent", sigma=1.0)
        mu_0 = pm.Normal("mu_0", mu=float(np.mean(sprint_counts)), sigma=2.0)

        # Latent AR(1) state-space decay process
        mu = [mu_0]
        for t in range(1, n_bins):
            mu_t = pm.Normal(f"mu_{t}", mu=rho * mu[-1], sigma=sigma_latent)
            mu.append(mu_t)

        mu_stack = pm.math.stack(mu)
        sigma_obs = pm.HalfNormal("sigma_obs", sigma=1.5)
        nu = pm.Exponential("nu", 1.0 / 10.0)  # Fat tails for counter-attack sprint bursts

        # Observation likelihood
        pm.StudentT("obs", nu=nu, mu=mu_stack, sigma=sigma_obs, observed=sprint_counts)

        # MCMC Sampling
        trace = pm.sample(
            draws=500,
            tune=500,
            chains=2,
            target_accept=0.9,
            random_seed=42,
            return_inferencedata=True
        )

    return trace


if __name__ == "__main__":
    # Simulated 15-minute high-intensity sprint instances across 6 match intervals (90 mins)
    match_sprints = np.array([12, 10, 8, 9, 6, 4])
    print(f"Sampling Bayesian AR(1) model across match bins: {match_sprints}...")

    trace = fit_physical_decay_model(match_sprints)

    # Output MCMC convergence diagnostics
    summary = az.summary(trace, var_names=["rho", "sigma_latent", "sigma_obs"])
    print("\n================== MCMC DIAGNOSTICS ==================")
    print(summary[["mean", "sd", "hdi_3%", "hdi_97%", "r_hat", "ess_bulk"]])
    print("======================================================")