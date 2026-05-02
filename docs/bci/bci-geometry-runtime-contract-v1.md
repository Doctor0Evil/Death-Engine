# BCI Geometry Runtime Contract v1

## Purpose

This document defines the runtime contract for BCI geometry in Death‑Engine. It fixes `scripts/bci/geometry.lua` as the single Lua entry point for BCI‑driven geometry and `scripts/bci/geometryregistry.lua` as the binding resolver.

Geometry bindings are static configuration (`bci-geometry-binding-v1.json`) that select curve families and safety profiles; all math and safety enforcement live in Rust. Lua only selects bindings, assembles requests, and routes outputs.

## Pipeline overview

At runtime, the engine executes the following fixed pipeline per player and tile:

1. **Metrics and summary**
   - Rust EMA kernel exposes `hpcbciprocess(featureJson, contractJson, outMetricsJson, outCap)`.
   - Rust summary kernel exposes `hpcbcigetsummary(playerId, outBuf, outCap)` and returns a `bci-summary-v1` JSON object.
   - `scripts/bci/init.lua` exposes `BCI.getSummary(playerId)` which returns a Lua table matching `bci-summary-v1.json`.

2. **Inputs for geometry**
   - `Invariants.getRegionSlice(regionId, tileId)` returns a slice with fields like `cic`, `lsg`, `det`, `regionClass`, plus banded fields `cicBand`, `lsgBand`, `detBand`.
   - `Metrics.getSessionSlice(playerId)` returns runtime entertainment metrics (UEC, ARR, etc.) in canonical ranges.
   - `Timing.getCSI(playerId)` returns the current cooldown saturation index in `[0,1]`.
   - `H.Contract.getCurrentPolicy(playerId)` returns a contract context table with policy and safety information.

3. **Binding selection**
   - `scripts/bci/geometryregistry.lua` loads an array of `bci-geometry-binding-v1` objects from JSON and indexes them by `regionClass`.
   - `Geometry.sample(playerId, regionId, tileId)` constructs a context:
     - `summary` (BciSummary)
     - `invariants` (region slice)
     - `metrics` (session slice)
     - `csi` (CSI scalar)
     - `contractCtx` (contract context)
   - `BindingsRegistry.resolve(ctx)`:
     - Filters candidates by `regionClass`, `invariantFilter`, `bciFilter`, and `metricsFilter`.
     - Scores candidates by `priority`, `tier`, `specificity`, and proximity to `summary.stressScore`.
     - Returns a single best binding plus a score and reasons.

4. **Geometry evaluation**
   - `Geometry.sample` maintains a per‑player binding cache keyed by `(playerId, regionId, tileId)` and stores:
     - `binding` (resolved binding object)
     - `invBands` (banded invariants)
     - `bciBands` (stress/attention bands, signal quality)
     - `csiBucket` (CSI bucket: low/mid/high)
     - `caps` (maxCsi, maxDet from `binding.safetyProfile`)
   - On cache miss or invalidation, `Geometry.sample` calls `BindingsRegistry.resolve(ctx)`.
   - Geometry then calls the Rust kernel:
     - Preferred path: `HKernels.evaluateBinding(binding, requestTable)` using a struct‑based FFI surface.
     - Fallback path: JSON FFI `hpcbci_evaluate_mapping(requestJson, outBuf, outCap)` if available.

5. **Applying outputs**
   - Rust returns a `BciMappingOutputs` struct or JSON with `visual`, `audio`, and `haptics` fields in `[0,1]` after all safety caps.
   - Lua applies them via:
     - `H.Visual.applyBciMask(playerId, outputs.visual)`
     - `H.Audio.applyBciRtpcs(playerId, outputs.audio)`
     - `H.Haptics.routeHaptics(playerId, outputs.haptics)`

## Module responsibilities

### `scripts/bci/geometry.lua`

This module is the only public Lua entry surface for BCI geometry.

Responsibilities:

- Expose:
  - `Geometry.sample(playerId, regionId, tileId) -> outputsTable | nil`
  - `Geometry.peekBinding(playerId, regionId, tileId) -> debugTable | nil`
  - `Geometry.clearCache()`
  - `Geometry.clearCacheForPlayer(playerId)`
- Maintain a per‑player binding cache keyed by `"player:region:tile"`.
- Invalidate cached bindings when:
  - `cicBand`, `lsgBand`, or `detBand` change.
  - `stressBand`, `attentionBand`, or `signalQuality` change.
  - The CSI bucket (`low`, `mid`, `high`) changes.
- Gather inputs from:
  - `BCI.getSummary(playerId)`
  - `Invariants.getRegionSlice(regionId, tileId)`
  - `Metrics.getSessionSlice(playerId)`
  - `Timing.getCSI(playerId)`
  - `H.Contract.getCurrentPolicy(playerId)`
- Call `BindingsRegistry.resolve(ctx)` and log selections via `BCIDebug.logBindingSelection(ctx, binding, score, reasons)`.
- Dispatch to Rust via `HKernels.evaluateBinding` or `hpcbci_evaluate_mapping`.

Lua code must not implement any mapping math or safety logic in this module. All numerics are delegated to Rust.

### `scripts/bci/geometryregistry.lua`

This module is the registry and resolver for `bci-geometry-binding-v1` objects.

Responsibilities:

- Load bindings:
  - `Registry.loadFromFile(path)` loads an array of bindings and indexes by `regionClass`.
  - `Registry.setBindings(array)` sets bindings directly (for tests or in‑engine configuration).
- Provide access:
  - `Registry.getBindings()` returns the raw bindings array.
- Resolve a binding:
  - `Registry.resolve(ctx)`:
    - Accepts a context with `summary`, `invariants`, `metrics`, `csi`, `playerId`, `regionId`, `tileId`, `contractCtx`.
    - Prefilters by `regionClass` using `ctx.invariants.regionClass` or `"any"`.
    - Applies `invariantFilter` using invariant bands and ranges (CIC/DET/LSG).
    - Applies `bciFilter` using BciSummary fields:
      - `stressBand`, `attentionBand`, `visualOverloadIndex`, `startleSpike`, `signalQuality`, `stressScore`.
    - Applies `metricsFilter` using entertainment bands such as UEC, EMD, CDL, ARR, and DET estimate where available.
    - Scores candidates with:
      - `priority` (authored integer).
      - `tier` (`lab`, `standard`, `mature`, etc.).
      - `specificity` (count of non‑nil filter fields).
      - Optional stress proximity bonus around the center of the binding’s stress range.
    - Returns a single best binding and score; ties are broken deterministically by tier and `bindingId`.

Lua code in this module must treat bindings as pure configuration. It must not inject engine‑specific fields or modify safety profiles at runtime.

## Debug and telemetry

The geometry runtime contract integrates with the debug module:

- `scripts/hpcbcidebug.lua` uses:
  - `BCI.getSummary(playerId)` for current BciSummary bands.
  - `Geometry.peekBinding(playerId, regionId, tileId)` to show `bindingId`, `tier`, `regionClass`, and caps.
  - Logging helpers such as `BCIDebug.logBindingSelection` and `BCIDebug.logSignalQuality`.

NDJSON telemetry for binding selection and mapping activation should be treated as a separate layer; this contract only defines the runtime API that debug and telemetry code may call.

## Usage guidelines

- Game systems that want BCI‑aware behavior must call `Geometry.sample(playerId, regionId, tileId)` and never call Rust geometry FFI directly.
- Bindings must be authored against `bci-geometry-binding-v1.json` and loaded via the registry. Lua must not construct or modify bindings ad‑hoc at runtime.
- BCI summary is the only BCI surface visible to Lua:
  - Geometry bindings and resolvers may only speak in terms of `stressScore`, `stressBand`, `attentionBand`, `visualOverloadIndex`, `startleSpike`, and `signalQuality`, plus invariants and entertainment metrics slices.
- All safety caps (CSI/DET, neurorights limits, recovery windows) are enforced in Rust, not Lua.

This contract should be kept in sync with the corresponding Rust kernel types (BciSummary, InvariantsSlice, BciMappingInputs, BciMappingOutputs) and the `bci-geometry-binding-v1` and `bci-summary-v1` schemas.
