from __future__ import annotations
from dataclasses import dataclass
from math import log, pi, e
from typing import Dict


def clamp(value: float, min_val: float, max_val: float) -> float:
    return max(min_val, min(value, max_val))


@dataclass
class BandPowers:
    alpha: float
    beta: float
    theta: float
    gamma: float
    delta: float


@dataclass
class AdvancedContext:
    # All of these are purely for game telemetry, not medical use.
    alpha_left: float
    alpha_right: float
    plv_frontal_temporal: float     # 0–1
    pli: float                      # 0–1
    hfd: float                      # fractal dimension proxy 0–2
    csp_variance: float            # 0–1 range after normalization

    var_alpha: float
    var_beta: float
    var_theta: float
    var_gamma: float
    var_delta: float


def _safe_var(v: float, eps: float = 1e-9) -> float:
    return max(v, eps)


def _differential_entropy(var_band: float) -> float:
    """
    Differential entropy (Gaussian assumption) in nats, scaled
    for game use only: DE = 0.5 * log(2πeσ²).
    """
    v = _safe_var(var_band)
    return 0.5 * log(2.0 * pi * e * v)


def calculate_fear_metrics(b: BandPowers) -> Dict[str, float]:
    """
    Baseline Death-Engine fear metrics.
    Input values are expected in a normalized 0–100 range per band.
    """
    alpha = max(b.alpha, 0.0)
    beta = max(b.beta, 0.0)
    theta = max(b.theta, 0.0)
    gamma = max(b.gamma, 0.0)
    delta = max(b.delta, 0.0)

    base_arousal = beta + gamma
    dream_tension = theta + delta
    cortical_quiet = alpha

    terror_index = clamp(((dream_tension + cortical_quiet) /
                          (base_arousal + 1.0)) * 100.0, 0.0, 100.0)
    shock_index = clamp(base_arousal * 0.8 + gamma * 0.2, 0.0, 100.0)
    dread_index = clamp(theta * 0.6 + delta * 0.4, 0.0, 100.0)
    gore_suscept = clamp(shock_index * 0.7 + terror_index * 0.3, 0.0, 100.0)
    spiritual_open = clamp(delta * 0.5 + alpha * 0.5, 0.0, 100.0)
    sanity_score = clamp(100.0 - terror_index, 0.0, 100.0)

    return {
        "terror_index": terror_index,
        "shock_index": shock_index,
        "dread_index": dread_index,
        "gore_suscept": gore_suscept,
        "spiritual_open": spiritual_open,
        "sanity_score": sanity_score,
    }


def calculate_custom_fear_metrics(b: BandPowers) -> Dict[str, float]:
    alpha = max(b.alpha, 0.0)
    beta = max(b.beta, 0.0)
    theta = max(b.theta, 0.0)
    gamma = max(b.gamma, 0.0)
    delta = max(b.delta, 0.0)

    base_arousal = beta + gamma

    custom_terror = clamp(
        ((0.7 * (theta + delta) + 0.3 * alpha) /
         (beta + 1.2 * gamma + 1.0)) * 100.0,
        0.0,
        100.0,
    )

    custom_shock = clamp(
        (0.5 * beta + 0.5 * gamma) * 0.9 + (theta * 0.1),
        0.0,
        100.0,
    )

    custom_dread = clamp(
        (0.5 * theta + 0.5 * delta) + (0.2 * (gamma - alpha)),
        0.0,
        100.0,
    )

    custom_gore = clamp(
        (0.6 * custom_shock + 0.4 * custom_terror) - (0.1 * alpha),
        0.0,
        100.0,
    )

    custom_spiritual = clamp(
        (0.6 * delta + 0.4 * theta) / (alpha + 1.0),
        0.0,
        100.0,
    )

    custom_sanity = clamp(
        100.0 - (0.8 * custom_terror + 0.2 * custom_dread),
        0.0,
        100.0,
    )

    return {
        "custom_terror_index": custom_terror,
        "custom_shock_index": custom_shock,
        "custom_dread_index": custom_dread,
        "custom_gore_suscept": custom_gore,
        "custom_spiritual_open": custom_spiritual,
        "custom_sanity_score": custom_sanity,
    }


def calculate_advanced_fear_metrics(
    b: BandPowers,
    ctx: AdvancedContext,
) -> Dict[str, float]:
    """
    Advanced “entropy + connectivity” horror indices for Death-Engine.

    All values are *fictional telemetry* for horror pacing.
    Do NOT map to medical or real-world safety decisions.
    """
    alpha = max(b.alpha, 0.0)
    beta = max(b.beta, 0.0)
    theta = max(b.theta, 0.0)
    gamma = max(b.gamma, 0.0)
    delta = max(b.delta, 0.0)

    base_arousal = beta + gamma

    DE_gamma = _differential_entropy(ctx.var_gamma)
    DE_beta = _differential_entropy(ctx.var_beta)
    DE_theta = _differential_entropy(ctx.var_theta)

    alpha_asym = (
        (ctx.alpha_left - ctx.alpha_right) /
        (ctx.alpha_left + ctx.alpha_right + 1.0)
    )

    advanced_terror = clamp(
        (
            DE_gamma * 0.5
            + DE_beta * 0.3
            + ((theta + delta) / (alpha + 1.0)) * 0.2
        ) * 100.0 / (base_arousal + 1.0),
        0.0,
        100.0,
    )

    advanced_shock = clamp(
        (0.6 * beta + 0.4 * gamma)
        + DE_gamma * 0.2
        - alpha_asym * 10.0,  # scale asymmetry for 0–100 space
        0.0,
        100.0,
    )

    advanced_dread = clamp(
        (0.5 * theta + 0.4 * delta + 0.1 * ctx.plv_frontal_temporal * 100.0)
        + (DE_theta * 0.2),
        0.0,
        100.0,
    )

    advanced_spiritual = clamp(
        (0.5 * delta + 0.3 * alpha + 0.2 * ctx.pli * 100.0) / (beta + 1.0),
        0.0,
        100.0,
    )

    advanced_gore = clamp(
        (0.5 * advanced_shock + 0.3 * advanced_terror + 0.2 * ctx.hfd * 50.0)
        - (alpha * 0.1),
        0.0,
        100.0,
    )

    advanced_sanity = clamp(
        100.0
        - (0.6 * advanced_terror + 0.3 * advanced_dread
           + 0.1 * ctx.csp_variance * 100.0),
        0.0,
        100.0,
    )

    return {
        "advanced_terror_index": advanced_terror,
        "advanced_shock_index": advanced_shock,
        "advanced_dread_index": advanced_dread,
        "advanced_gore_suscept": advanced_gore,
        "advanced_spiritual_open": advanced_spiritual,
        "advanced_sanity_score": advanced_sanity,
    }
