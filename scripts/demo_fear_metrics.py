from engine.neuro.fear_metrics import (
    BandPowers,
    AdvancedContext,
    calculate_fear_metrics,
    calculate_custom_fear_metrics,
    calculate_advanced_fear_metrics,
)
from engine.neuro.fear_bands_lore import describe_state

b = BandPowers(alpha=10, beta=20, theta=15, gamma=25, delta=30)

base = calculate_fear_metrics(b)
custom = calculate_custom_fear_metrics(b)

ctx = AdvancedContext(
    alpha_left=8,
    alpha_right=12,
    plv_frontal_temporal=0.9,
    pli=0.6,
    hfd=1.3,
    csp_variance=0.4,
    var_alpha=5.0,
    var_beta=8.0,
    var_theta=10.0,
    var_gamma=12.0,
    var_delta=9.0,
)

advanced = calculate_advanced_fear_metrics(b, ctx)

print("BASE:", base)
print("CUSTOM:", custom)
print("ADVANCED:", advanced)
print("LORE:", describe_state(base))
