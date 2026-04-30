# Death‑Engine

Death‑Engine is the runtime BCI and geometry kernel for **Horror.Place**, responsible for turning canonical BCI envelopes, invariants, and safety profiles into concrete visual, audio, and haptic behavior. It sits alongside Constellation‑Contracts and Neural‑Resonance‑Lab and focuses exclusively on **runtime execution**, **FFI‑friendly kernels**, and **platform‑agnostic configuration**.

***

## Role in the Horror.Place Constellation

Within the Horror.Place constellation, Death‑Engine has a focused mandate: it consumes validated BCI envelopes and bindings defined upstream and applies them safely inside the live game loop.

At a high level:

- **Constellation‑Contracts** defines schemas for BCI envelopes, safety profiles, and geometry bindings.  
- **Neural‑Resonance‑Lab** runs offline analysis, calibration, and authoring experiments, producing bindings and profiles that pass CI and schema validation.  
- **Death‑Engine** ingests those lab‑approved artifacts and executes them in real time: resolving geometry, evaluating curve families, enforcing safety caps, and routing outputs into visuals, audio, and haptics.

Death‑Engine does not define raw EEG formats or new metric systems; it treats BCI as an additional observation channel layered on top of existing horror metrics and invariants, and it enforces neurorights‑aligned safety contracts at runtime. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_b5bbed5e-6469-4076-9528-305f2ec886fc/8ec8d7a3-c055-485c-a7de-ccf6cb5237a2/e90fecc7-8c83-49c7-848a-aec1ad8495ed.md)

***

## Core Concepts

Death‑Engine is built around a few key BCI concepts:

- **BciSummary and invariants:** A compact view of the player’s state (stress bands, attention bands, visual overload, startle spikes, signal quality) combined with environment invariants (CIC, LSG, DET and related fields) drive all BCI geometry decisions. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_b5bbed5e-6469-4076-9528-305f2ec886fc/42dc24b6-4ba5-4242-a830-6eb872e4e66c/f47e303e-f715-4fcf-826c-968d01bf9866.md)
- **Geometry bindings:** JSON‑authored bindings (from Neural‑Resonance‑Lab) describe how BciSummary and invariants map into visual/audio/haptic parameters through curve families and safety profiles; Death‑Engine resolves and executes them. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_b5bbed5e-6469-4076-9528-305f2ec886fc/42dc24b6-4ba5-4242-a830-6eb872e4e66c/f47e303e-f715-4fcf-826c-968d01bf9866.md)
- **Safety profiles:** Neurorights‑aligned caps on intensity, rate of change, CSI/DET exposure, and recovery windows are enforced in Rust kernels before any effect reaches the player. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_b5bbed5e-6469-4076-9528-305f2ec886fc/8ec8d7a3-c055-485c-a7de-ccf6cb5237a2/e90fecc7-8c83-49c7-848a-aec1ad8495ed.md)
- **Platform‑agnostic configuration:** All runtime behavior is driven by JSON/TOML configuration files and schemas, so the same BCI logic can be reused across engines and platforms.

Everything in this repository is gaming‑only, platform‑agnostic, and oriented around reproducible horror pacing and geometry, not medical or real‑world infrastructure.

***

## Repository Layout

This section explains the key directories and files Death‑Engine expects, so that tools and AI‑assisted code generation can target them consistently.

### 1. Runtime Configuration (`config/`)

The `config/` directory contains platform‑agnostic JSON and TOML files that describe how BCI geometry, audio, haptics, debugging, and invariants are wired at runtime.

#### 1.1 BCI Geometry and Profiles (`config/bci/`)

**Directory:** `config/bci/`  
This subtree captures the runtime configuration for how BCI state is interpreted and applied.

##### 1.1.1 Octa‑region geometry

- **File:** `config/bci/octa/octa-region-geometry-v1.json`  
  Defines a library of **octa‑regions** in invariant space (e.g., CIC, AOS, LSG). Each entry describes a region ID and its geometry parameters (such as vertices or ranges), allowing the BCI kernel to treat different slices of the horror world (corridors, liminal edges, safe pockets) as distinct BCI‑aware regions. This file is referenced by the octa kernel in `crates/bci_kernel/src/octa.rs` when resolving which region a player currently occupies.

##### 1.1.2 Hex‑array mapping

- **File:** `config/bci/hex/hex-array-mapping-v1.json`  
  Configures a **hexagonal projection** of the world into hex cells, each with invariants and BCI response hints. Entries map hex coordinates to invariant profiles and may reference curve assignments or geometry bindings for different attention bands. This mapping is consumed by the `bci_hex_array` crate and by audio/haptics modules that want to reason about space on a hex grid.

##### 1.1.3 Quadrant hyperdocker

- **File:** `config/bci/hyperdocker/quadrant-hyperdocker-v1.json`  
  Describes a 4‑dimensional horror state space (e.g., CIC, AOS, LSG, CSI) divided into quadrants. Each quadrant defines override parameters or indices into safety profiles and curve families, allowing BCI behavior to change qualitatively as the combined state moves between regions of this hypercube.  

- **File:** `config/bci/hyperdocker/hyperdocker-blending-policy-v1.json`  
  Configures how outputs from neighboring quadrants are blended (for example, nearest, linear, or Gaussian blending, plus any tunable parameters). The Rust `hyperdocker` module uses this policy to produce smooth transitions when inputs straddle quadrant boundaries.

##### 1.1.4 Quantum telemetry profile (gaming‑only)

- **File:** `config/bci/quantum/quantum-telemetry-profile-v1.json`  
  Defines fictional **quantum telemetry profiles** for use with the `qct_simulator` crate. Profiles specify parameters such as simulated noise characteristics and modality enums for game‑only “quantum‑style” telemetry streams. This file exists solely to parameterize test harnesses and bindings that want to model speculative sensor backends in a safe, entertainment‑only way.

##### 1.1.5 Custom mapping envelopes

- **File:** `config/bci/custom/custom-mapping-envelope-v1.json`  
  Provides a generic envelope for describing platform‑specific mapping rules from BciSummary and invariants into engine‑specific parameters (e.g., RTPC names, shader parameters), without modifying core kernels. The envelope lists allowed inputs, outputs, and declarative rule blocks, and must validate against its schema and pass safety checks.  

- **File:** `config/bci/custom/per-platform-mapping-registry-v1.json`  
  Acts as a registry mapping logical `platformId` (for example, engine or hardware profile) to the set of allowed `custom-mapping-envelope` files. This registry lets deployments constrain which custom mappings can be loaded at runtime, simplifying review and governance.

##### 1.1.6 Safety profiles

- **File:** `config/bci/safety/safety-profile-registry-v1.json`  
  Contains a list of approved **BCI safety profiles**, keyed by `profileId`. Each profile encodes caps on channel intensities, rate‑of‑change limits, CSI/DET bounds, recovery windows, and stress‑gated multipliers. Rust kernels in `crates/bci_kernel` use this registry to look up and apply the correct safety profile for a given binding, ensuring neurorights‑aligned constraints are enforced in one central location. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_b5bbed5e-6469-4076-9528-305f2ec886fc/8ec8d7a3-c055-485c-a7de-ccf6cb5237a2/e90fecc7-8c83-49c7-848a-aec1ad8495ed.md)

##### 1.1.7 Curve family catalog

- **File:** `config/bci/curves/curve-family-catalog-v1.json`  
  Enumerates all supported curve families and their parameter semantics (for example, PKLIN, PKSIG, PKHYS, PKOSC), including parameter ranges and safety envelopes. This catalog defines the only allowed family codes and parameter shapes for geometry bindings, ensuring that AI‑generated and human‑authored bindings stay within known, validated curve behavior. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_b5bbed5e-6469-4076-9528-305f2ec886fc/42dc24b6-4ba5-4242-a830-6eb872e4e66c/f47e303e-f715-4fcf-826c-968d01bf9866.md)

#### 1.2 Audio configuration (`config/audio/`)

**Directory:** `config/audio/`  
Captures how BCI and invariants influence runtime audio parameters.

- **File:** `config/audio/audio-balance-3d-v1.json`  
  A manifest describing how audio sources should be spatially balanced based on BciSummary and hex/octa geometry. It maps logical audio sources to azimuth/elevation/distance behavior and gain/reverb curves driven by core BCI signals (for example, increasing whisper proximity with higher stress).  

- **File:** `config/audio/audio-rtpc-index-v1.json`  
  A central registry of RTPC (real‑time parameter control) names and IDs that BCI systems are allowed to modify. This registry provides a constrained list of audio controls that Rust kernels and Lua scripts can safely target, avoiding ad‑hoc RTPC usage.

#### 1.3 Haptics configuration (`config/haptics/`)

- **File:** `config/haptics/haptic-routing-table-v1.json`  
  Defines how BCI outputs and geometry regions map to individual haptic channels (for example, vest segments, peripheral devices). It maps logical haptic parameters (intensity, pulse rate, pattern IDs) to motor IDs per platform, enabling the BCI kernel to output high‑level parameters while platform adapters translate them to hardware‑specific commands.

#### 1.4 Debug configuration (`config/debug/`)

- **File:** `config/debug/bci-debug-overlay-config-v1.json`  
  Configures on‑screen debug overlays for development builds. It specifies which BCI fields, invariants, and metrics to display (for example, current stress band, chosen binding ID, CSI/DET caps), along with layout and coloring.  

- **File:** `config/debug/bci-geometry-debugger-config-v1.json`  
  Drives specialized geometry debugging views, including visualization of octa‑regions, hex cells, and hyperdocker quadrants. The file controls which layers are drawn and under what conditions, enabling controlled inspection of BCI‑driven spatial behavior.

#### 1.5 Hex projection configuration (`config/hex/`)

- **File:** `config/hex/invariant-hex-projection-v1.json`  
  Describes how world‑space coordinates and invariant slices are projected into the hexagonal grid used by the BCI hex array subsystem. It defines scales, offsets, and optional weighting factors so the hex grid can remain stable across engines while still reflecting the horror world’s topology.

#### 1.6 Global BCI TOML template

- **File:** `config/death-engine-bci-config-toml-template.toml`  
  A TOML template that wires all BCI subsystems together. It includes paths to the main config and schema files, feature flags (for example, enabling/disabling hex array or hyperdocker subsystems), logging levels, and sampling parameters. Engine integrations can copy this template and adjust paths to match their build/deployment layout.

***

### 2. Runtime Kernels (`crates/`)

The `crates/` directory hosts Rust crates that implement the runtime kernels for BCI geometry, hex arrays, quantum telemetry simulation, and custom mapping validation. All crates are designed for C‑friendly FFI and strict schema alignment.

#### 2.1 BCI kernel crate

- **Directory:** `crates/bci_kernel/`  
  Houses the core BCI geometry kernel logic that evaluates bindings, applies safety profiles, and computes visual/audio/haptic outputs.

  - **File:** `crates/bci_kernel/src/octa.rs`  
    Implements octa‑region resolution and blending in invariant space. It loads octa‑region definitions from `octa-region-geometry-v1.json`, determines which region(s) a given invariants slice falls into, and produces region weights that feed into the geometry evaluation pipeline.

  - **File:** `crates/bci_kernel/src/hyperdocker.rs`  
    Implements the quadrant hyperdocker subsystem: given a `BciMappingInputs` snapshot and the quadrant configuration from `quadrant-hyperdocker-v1.json` plus blending policy, it selects and blends quadrant configurations to generate intermediate control parameters before safety caps and outputs are applied.

#### 2.2 Hex‑array crate

- **Directory:** `crates/bci_hex_array/`  
  - **File:** `crates/bci_hex_array/src/lib.rs`  
    Provides types and functions for working with hexagonal coordinate systems and invariant‑aware hex cells. It builds hex grids, looks up cells based on world coordinates, and exposes a stable API to query per‑cell BCI response configuration (for example, default curve assignments per attention band). This crate integrates with `hex-array-mapping-v1.json` and `invariant-hex-projection-v1.json`.

#### 2.3 Quantum telemetry simulator

- **Directory:** `crates/qct_simulator/`  
  - **File:** `crates/qct_simulator/src/lib.rs`  
    Simulates quantum‑style telemetry frames based on profiles from `quantum-telemetry-profile-v1.json`. It generates synthetic NDJSON or in‑memory frames for lab bindings and debug tools, enabling designers to test “quantum‑aware” behavior without any real sensor data.

#### 2.4 Custom mapping validator

- **Directory:** `crates/custom_mapping_validator/`  
  - **File:** `crates/custom_mapping_validator/src/lib.rs`  
    Validates `custom-mapping-envelope-v1.json` documents against both their schema and runtime safety rules. It ensures references to curve families, safety profiles, outputs, and BCI fields are legal, enforcing that custom mapping rules cannot push effects beyond allowed ranges or use unsupported parameters.

***

### 3. Examples (`examples/`)

The `examples/` directory contains lab‑oriented example configurations that demonstrate how to use the BCI subsystems.

- **Directory:** `examples/bci/`  

  - **File:** `examples/bci/octa_bindings_lab_v1.json`  
    Example lab configuration that ties octa‑regions to specific geometry bindings and outputs. It showcases how high‑CIC corridors, low‑CIC safe pockets, and liminal edges can be given distinct BCI behavior, and serves as a starting point for new bindings.  

  - **File:** `examples/bci/qct_binding_lab_v1.json`  
    Example configuration that uses quantum telemetry simulator outputs to drive a noise‑augmented visual or audio effect, illustrating how `qct_simulator` integrates into the runtime path in a purely entertainment‑oriented way.

***

### 4. Scripting (`scripts/`)

The `scripts/` directory holds runtime Lua modules that orchestrate engine subsystems around the Rust kernels.

- **Directory:** `scripts/audio/`  

  - **File:** `scripts/audio/bci_audio_balancer.lua`  
    Provides a Lua module that adjusts 3D audio balance and RTPC values based on BciSummary, hex/octa geometry, and `audio-balance-3d-v1.json`. It reads BCI state, retrieves spatial/audio configuration, and routes normalized parameters to the audio engine via a small set of helper APIs.

***

### 5. Schemas (`schemas/`)

The `schemas/` directory contains JSON Schemas for runtime‑visible envelopes and telemetry formats specific to Death‑Engine.

#### 5.1 BCI schemas (`schemas/bci/`)

- **File:** `schemas/bci/bci-summary-full-v1.json`  
  Defines an extended BciSummary surface as used by Death‑Engine, possibly including additional optional fields (for example, extended overload indices or auxiliary bands) while remaining compatible with the core summary defined in Constellation‑Contracts. It acts as the internal contract for what BCI state the engine expects to see at runtime.

- **File:** `schemas/bci/hex-array-reactive-envelope-v1.json`  
  Describes a per‑frame envelope that records which hex cell the player occupies, which curve families were evaluated, and what normalized visual/audio/haptic parameters were produced. This NDJSON‑friendly shape powers reactive telemetry and debugging tools that analyze how BCI geometry behaves over time.

#### 5.2 Telemetry schemas (`schemas/telemetry/`)

- **File:** `schemas/telemetry/telemetry-output-format-v1.json`  
  Defines the schema for Death‑Engine’s telemetry output stream related to BCI, geometry, and safety enforcement. It specifies event types (for example, binding selection, cap application, overload recovery events) and their fields, enabling downstream tools in Neural‑Resonance‑Lab and Telemetry‑Vault to validate and analyze runtime behavior.

***

### 6. Documentation (`docs/`)

The `docs/` directory provides specifications and authoring guides for humans and AI‑assisted tools.

#### 6.1 BCI documentation (`docs/bci/`)

- **File:** `docs/bci/octa-regions-spec-v1.md`  
  Specification for octa‑region geometry: how regions are defined, how invariants are mapped into them, and how the octa kernel uses them to modulate bindings.

- **File:** `docs/bci/hex-array-spec-v1.md`  
  Defines how the hex grid is laid out, how cells are addressed and mapped to world space, and how hex cell data feeds into visual/audio/haptic behavior and telemetry.

- **File:** `docs/bci/quadrant-hyperdocker-spec-v1.md`  
  Explains the quadrant hyperdocker model, how horror state maps into quadrants, how blending policies work, and how this subsystem interacts with bindings and safety profiles.

- **File:** `docs/bci/quantum-telemetry-gaming-spec-v1.md`  
  Clarifies that quantum telemetry support in Death‑Engine is entirely simulated and entertainment‑only, and documents how to configure and use `qct_simulator` and related profiles.

- **File:** `docs/bci/custom-mapping-guide-v1.md`  
  A guide for writing `custom-mapping-envelope-v1.json` files: describing allowed inputs and outputs, rule syntax, review guidelines, and safety constraints. It is intended for third‑party platform adapters and advanced users.

- **File:** `docs/bci/platform-abstraction-layer-spec-v1.md`  
  Describes the platform abstraction layer that decouples the core BCI geometry kernels from engine‑specific or hardware‑specific details. It shows how to implement adapters that load config files, call Rust kernels, and route outputs to engine APIs.

- **File:** `docs/bci/bci-geometry-authoring-contract-v1.md`  
  Defines the contract that AI‑assisted tools and human authors must follow when generating geometry bindings, octa/hex mappings, and related configs. It specifies which schemas must be consulted, how curve families and safety profiles are chosen, and what invariants and BciSummary fields can be used as inputs.

#### 6.2 Audio documentation (`docs/audio/`)

- **File:** `docs/audio/3d-audio-balance-spec-v1.md`  
  Details how to use `audio-balance-3d-v1.json` and `audio-rtpc-index-v1.json` to achieve BCI‑responsive 3D audio in horror experiences, including example patterns for stress‑driven whispers, heartbeat‑like low‑frequency pressure, and environmental drones.

- **File:** `docs/audio/bci-hex-audio-spatialization-spec-v1.md`  
  Explains how the hex array and invariants map into spatial audio design, including patterns where audio intensity and localization respond to the player’s drift through hex cells and BCI state.

***

## Intended Use and Safety

Death‑Engine is meant for game developers, XR labs, and researchers building Horror.Place‑compatible experiences that respect neurorights and safety constraints. All BCI behavior is driven by schema‑validated envelopes and safety profiles created upstream, and all runtime mapping math and caps enforcement are implemented in Rust kernels, not scripting layers. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_b5bbed5e-6469-4076-9528-305f2ec886fc/8ec8d7a3-c055-485c-a7de-ccf6cb5237a2/e90fecc7-8c83-49c7-848a-aec1ad8495ed.md)

This repository does not contain or require raw EEG formats, PII, or real‑world infrastructure integrations. Instead, it provides a tightly constrained, schema‑driven runtime environment where BciSummary and invariants safely steer horror geometry and multimodal feedback.
