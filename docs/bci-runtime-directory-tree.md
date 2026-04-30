# Death-Engine BCI Runtime Directory Tree

## Overview

This document proposes the canonical directory tree for BCI components inside Death-Engine. It assumes that canonical BCI schemas live in HorrorPlace-Constellation-Contracts and that Death-Engine only implements runtime code that consumes those schemas and envelopes.

The layout separates four layers:

- Device adapters and capture.
- Canonical envelope handling and mapping evaluation.
- Lua facades and horror systems integration.
- Tests, fixtures, and CI harnesses.

## Top-level layout

At engine root:

- `crates/`
  - `bci/`
    - `device/`
    - `envelopes/`
    - `mapping-eval/`
    - `policy-client/`
    - `tests/`
- `scripts/`
  - `hpc/`
    - `bci/`
- `tests/`
  - `bci/`

### `crates/bci/device/`

Rust crates that abstract hardware and external pipelines.

- `crates/bci/device/hpc-bci-convert/`
  - Rust CLI and library that converts external EEG/BCI datasets into `bci-feature-envelope-v2` NDJSON, with anonymization and license-compliance enforced.
- `crates/bci/device/hpc-bci-stream/`
  - Runtime feature server that exposes validated feature envelopes to the rest of the engine.

### `crates/bci/envelopes/`

Rust crates that own envelope types and validation.

- `crates/bci/envelopes/hpc-bci-feature/`
  - Types for `bci-feature-envelope-v2` and validation functions.
- `crates/bci/envelopes/hpc-bci-metrics/`
  - Types for `bci-metrics-envelope-v2`, mapping from features to metrics, and EMA calibration plumbing.
- `crates/bci/envelopes/hpc-bci-intensity/`
  - Types and logic for `bci-core-intensity-envelope-v1` and the discrete intensity state machine.

### `crates/bci/mapping-eval/`

Rust crate for evaluating HorrorMappingConfig.BCI mappings.

- `crates/bci/mapping-eval/`
  - `HorrorMappingConfig.BCI.v1` typed mirror.
  - Implementation of mapping families (linear, logistic, hysteresis, multi-input).
  - Differential envelope safety helpers (T, T_session, T_cap) for CI and runtime clamps.

### `crates/bci/policy-client/`

Policy and ledger client.

- `crates/bci/policy-client/`
  - Rust client for `Policy.DeadLedger.BCI`, consuming derived `bcistate` from `bci-core-intensity-envelope-v1`.

### `scripts/hpc/bci/`

Lua-facing layer.

- `scripts/hpc/bci/hpcbciimport.lua`
  - Imports NDJSON feature envelopes, validates them against `bci-feature-envelope-v2`, and forwards to Rust via FFI.
- `scripts/hpc/bci/hpcbciadapter.lua`
  - Calls Rust mapping/evaluation and intensity envelopes to produce BCI state for game systems.
- `scripts/hpc/bci/H.BCI.lua`
  - Single Lua facade module (`H.BCI`) exposing features, metrics bands, intensity mode, and snapshots to HorrorDirector and gameplay scripts.

### `tests/bci/`

Engine tests and CI harnesses.

- `tests/bci/feature-fixtures/`
  - Synthetic fixture NDJSON for canonical feature envelopes.
- `tests/bci/metrics-fixtures/`
  - Expected metrics envelopes from the reference pipeline.
- `tests/bci/intensity-fixtures/`
  - Expected intensity sequences and bcistate for canonical scenarios.
- `tests/bci/mapping-fixtures/`
  - Golden `HorrorMappingConfig.BCI.v1` bindings and expected outputs.

This layout keeps low-level device code, schema-driven envelopes, mapping evaluation, policy integration, and Lua facades cleanly separated, while matching the constellation’s schema and CI spine.
