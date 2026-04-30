# BCI Telemetry Guide v1

## Overview

This document defines the telemetry events emitted by the BCI subsystem for analysis by Neural-Resonance-Lab. All events are NDJSON (one JSON object per line) and must validate against schemas in `HorrorPlace-Constellation-Contracts/schemas/telemetry/`.

## Event Types

### `bci-mapping-activation`
Emitted when `BciGeometry.sample()` evaluates a binding.

**Schema**: `bci-mapping-activation-v1.json`  
**Purpose**: Track which bindings are active in which contexts, and verify safety caps are applied correctly.

**Example**:
```json
{
  "schemaVersion": "1.0.0",
  "eventType": "bci-mapping-activation",
  "timestamp": 1714521600000,
  "playerId": "anon-session-7f3a",
  "regionId": "corridor_03",
  "tileId": "tile_12",
  "bindingId": "corridor_high_cic_sigmoid_tunnel",
  "inputs": {
    "stressScore": 0.72,
    "stressBand": "High",
    "visualOverloadIndex": 0.68,
    "startleSpike": false,
    "signalQuality": "Good",
    "csi": 0.72,
    "det": 7.2,
    "cic": 0.65,
    "lsg": 0.81
  },
  "outputs": {
    "visual": { "rawValue": 0.85, "clampedValue": 0.29, "capSource": "safeZone" },
    "audio": { "rawValue": 0.62, "clampedValue": 0.62, "capSource": "none" },
    "haptics": { "rawValue": 0.44, "clampedValue": 0.44, "capSource": "none" }
  },
  "telemetry": {
    "safetyProfileId": "corridor_med",
    "capsApplied": {
      "intensityClamp": false,
      "rateClamp": false,
      "recoveryActive": false,
      "safeZoneActive": true
    },
    "processingTimeMs": 1.2
  }
}
```

### `binding-selection`
Emitted when the Rust `BindingResolver` selects a binding.

**Schema**: `binding-selection-v1.json`  
**Purpose**: Analyze resolver behavior, detect "holes" (no binding matches), and tune scoring weights.

### `prism-activation`
Emitted when any prism connector (`H.Prism.*.sample()`) is evaluated.

**Schema**: `prism-activation-v1.json`  
**Purpose**: Correlate prism outputs with comfort outcomes and session metrics.

## Logging Configuration

Enable telemetry in `config/engine.toml`:

```toml
[bci.telemetry]
enable = true
log_dir = "logs/bci-telemetry"
events = ["bci-mapping-activation", "binding-selection", "prism-activation"]
sample_rate = 1.0  # 1.0 = log every event; 0.1 = 10% sampling
```

## Privacy & Anonymization

All telemetry MUST:
- Use anonymized `playerId` (session-scoped UUID, not persistent)
- Exclude raw EEG data, PII, or demographic information
- Respect player consent flags (skip logging if `consent.telemetry = false`)

## Analysis Workflow

1. **Collect**: NDJSON logs from playtest sessions
2. **Validate**: Run `bci_schema_validator` to ensure schema compliance
3. **Aggregate**: Use Neural-Resonance-Lab tools to compute:
   - Binding usage frequency by region class
   - Comfort outcome distribution vs. `pressure`/`visualInstability`
   - Safety cap trigger rates (how often `safeZoneActive = true`)
4. **Iterate**: Tune binding weights, prism formulas, or safety profiles based on empirical data

## Darkwood-Inspired Analysis Patterns

When analyzing telemetry, look for patterns that mirror atmospheric horror design:

- **"Uncanny Valley" detection**: High `visualInstability` + moderate `det` + `comfortOutcome = "tooIntense"` → reduce CDL weight in visual prism
- **"Breathing World" validation**: `noveltyBudget` depletion rate should correlate with player-reported pacing satisfaction
- **"Somatic Echo" routing**: Peripheral haptic bias (`hapticRoutingBias < -0.3`) should increase exploration behavior in liminal regions

These evidence-based refinements ensure the BCI system enhances horror atmosphere while respecting player comfort and neurorights commitments.
