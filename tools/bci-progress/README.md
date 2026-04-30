# BCI Constellation Progress Tracker

This directory contains a single, unified CSV that tracks the implementation status of all major BCI artifacts across the Horror.Place constellation. It is designed to be easy for both humans and AI-chat to read, diff, and update.

## File layout

- `bci_constellation_progress.csv`  
  Canonical progress table for BCI-related schemas, Rust crates, FFI surfaces, Lua modules, telemetry schemas, and docs.

Recommended location in each repo:

```text
tools/bci-progress/bci_constellation_progress.csv
tools/bci-progress/README.md
```

## CSV schema

The CSV uses a fixed set of columns:

1. `Category`  
   High-level type of artifact, for example:
   - `Schema`
   - `Rust`
   - `FFI`
   - `Lua`
   - `Docs`
   - `Telemetry`
   - `Tooling`

2. `Object`  
   Human-readable name of the artifact, such as:
   - `bci-mapping-request-v1`
   - `BciMappingRequest struct`
   - `hpnrl_bci_evaluate_mapping`
   - `scripts/bci/geometry.lua`

3. `Target Repo`  
   Which repository owns the artifact, exactly matching one of:
   - `HorrorPlace-Constellation-Contracts`
   - `HorrorPlace-Neural-Resonance-Lab`
   - `Death-Engine`
   - Or another constellation repo if explicitly added.

4. `File Path`  
   Repo-relative path where the artifact lives or is intended to live, for example:
   - `schemas/bci/bci-mapping-request-v1.json`
   - `crates/bci_kernel/src/api.rs`
   - `crates/bci_ffi/src/ffi.rs`
   - `scripts/bci/geometry.lua`
   - `docs/ai-chat-integration/monster-mode-authoring-v1.md`

5. `Status`  
   Short status string. Use one of:
   - `Missing` – not yet created
   - `Conceptual` – only defined in prose
   - `Planned` – agreed but not yet implemented
   - `Drafted` – file exists but needs refinement
   - `In Review` – under active review
   - `Complete` – implemented, aligned with schemas

6. `Notes`  
   One-line description of what is needed or special constraints. Keep this brief and factual.

## How AI-chat should update this CSV

AI-chat is allowed to:

- **Add new rows** when it proposes or implements a new BCI artifact that fits the schema above.
- **Update the `Status` and `Notes` fields** when it generates code, schemas, or docs that move an artifact forward.
- **Correct `File Path` or `Target Repo`** when it detects an inconsistency with the actual repository layout.

AI-chat must not:

- Change the header row or column order.
- Remove rows for existing artifacts.
- Invent new `Status` values outside the allowed set.
- Move artifacts to different repos without an explicit instruction in the surrounding discussion.

## Workflow for humans and AI-chat

1. **Discover existing work**

   Before adding new rows, scan the CSV for an existing `Object` that matches what you are working on. Prefer updating `Status` and `Notes` over creating duplicates.

2. **Add or update entries**

   When you create or modify a BCI artifact (schema, Rust type, FFI function, Lua module, telemetry schema, or doc), ensure there is a row with:
   - Correct `Category`
   - Exact `Object` name
   - Correct `Target Repo` and `File Path`
   - Updated `Status` (`Drafted`, `In Review`, or `Complete`)
   - A short `Notes` line describing the change

3. **Keep it aligned with the repos**

   The `File Path` column should always match a real or planned path in one of the constellation repositories. If paths change due to refactors, update the CSV in the same change.

4. **Use the CSV as an index**

   AI-chat and tooling should treat `bci_constellation_progress.csv` as the primary index for:
   - Which BCI contracts exist (e.g., `bci-summary-v1.json`, `bci-geometry-binding-v1.json`)
   - Which unified mapping artifacts are missing (`bci-mapping-request-v1`, `BciMappingRequest`, `hpnrl_bci_evaluate_mapping`)
   - Where to place new code, schemas, and docs.

By keeping this CSV up to date, the constellation maintains a single, auditable view of BCI progress that both humans and AI tools can rely on when planning work and generating code.
