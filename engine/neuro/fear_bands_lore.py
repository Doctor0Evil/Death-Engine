from __future__ import annotations
from typing import Dict


def describe_state(metrics: Dict[str, float]) -> str:
    """
    Convert metrics into short horror-flavor text, safe for adult players.
    No medical meaning; pure narrative dressing.
    """
    terror = metrics.get("terror_index") or metrics.get("custom_terror_index") or 0.0
    dread = metrics.get("dread_index") or metrics.get("custom_dread_index") or 0.0
    sanity = metrics.get("sanity_score") or metrics.get("custom_sanity_score") or 0.0

    lines = []

    if terror > 80:
        lines.append("Terror saturates the nervous haze; every shadow feels sentient.")
    elif terror > 50:
        lines.append("Unease sharpens into a hunting presence at the edge of sight.")
    else:
        lines.append("Fear flickers like a warning pilot light, not yet a blaze.")

    if dread > 70:
        lines.append("Something slow and inevitable presses in, like a verdict already signed.")
    elif dread > 40:
        lines.append("Dread coils beneath awareness, a tension with no clear source.")
    else:
        lines.append("The world feels unsettled, but the ground has not yet split.")

    if sanity < 20:
        lines.append("Reason frays; familiar shapes warp into accusations.")
    elif sanity < 50:
        lines.append("Thoughts stagger, re-checking every sound for hidden teeth.")
    else:
        lines.append("Rational anchors still hold, though they creak under strain.")

    return " ".join(lines)
