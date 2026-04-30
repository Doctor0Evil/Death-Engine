# BCI Geometry Bindings – Research Questions and Directions v1

This document collects high‑impact research questions, definition requests, detail queries, and objections related to BCI geometry bindings and the surrounding Rust/Lua toolchain. The goal is to drive concrete improvements to code quality, schemas, crates, and AI‑chat authoring patterns for HorrorPlace’s VM‑constellation. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_cdb90fc3-8a6a-46e2-89a6-187b2f85f988/2c681b6f-1845-4a79-9464-ddf8cfa3208d/this-research-focuses-on-desig-DemATE1ZRtOBxLRQlhB93g.md)

Each item is phrased to be directly actionable and aligned with the current architecture: Rust as the numeric/safety kernel, Lua as the orchestration and engine‑integration layer, and AI‑chat as a schema‑bound authoring/compiler surface. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_cdb90fc3-8a6a-46e2-89a6-187b2f85f988/1c3e38a9-000b-42d6-bb93-f005b8cfad2f/1-should-the-research-prioriti-tQnn6sdDQ06XDNmNoVKx.g.md)

***

## 1. Schema and binding‑model questions

1. **BCI summary vs. feature envelopes**  
   How should `BciSummary` (stress, overload, attention bands) and the more detailed `bci-feature-envelope-v1` relate to each other in schemas and code: should the geometry bindings attach directly to `BciSummary`‐like fields, or should they always be fed by a feature‑to‑summary mapping step in Rust? [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_cdb90fc3-8a6a-46e2-89a6-187b2f85f988/2c681b6f-1845-4a79-9464-ddf8cfa3208d/this-research-focuses-on-desig-DemATE1ZRtOBxLRQlhB93g.md)

2. **Granularity of `regionClass` enums**  
   Is the current `regionClass` enum set in `bci-geometry-binding-v1.json` sufficient (corridors, thresholds, ritual sites, safe buffers, archives, marshes), or should we split further into, for example, “narrow corridor”, “multi‑entry ritual hall”, or “dead‑end liminal cul‑de‑sac” to give AI‑chat finer control over BCI geometry?  

3. **Binding precedence and conflict resolution**  
   When multiple bindings’ filters all match the same `(region, BCI, metrics)` slice, what precedence rules should the resolver use: most specific invariant range, tightest `bciFilter`, highest tier, or an explicit `priority` field that we should add to the schema?  

4. **Lifecycle of lab vs. standard bindings**  
   What formal promotion path should a binding follow from `tier: "lab"` to `"standard"` or `"mature"` (review steps, CI checks, telemetry evidence thresholds), and should the schema gain a `promotionCriteria` field to record this?  

5. **Schema evolution and compatibility**  
   When we extend `bci-geometry-binding-v1` with new fields (e.g., new output channels or family codes), how do we version bindings and keep AI‑chat safely constrained—should we use `schemaVersion` gating in the AI prompts, or a “feature flags” field in the manifest?  

6. **Input domain constraints in schema vs. code**  
   How much of the input domain (e.g., valid ranges for `stressScore`, `visualOverloadIndex`, or `CIC`) should be enforced at schema level vs. Rust runtime assertions, and do we need explicit `inputDomainVersion` tags tied to the invariants/metrics spine?  

7. **Representing “no binding” states**  
   Should the resolver explicitly support a “no binding matched” state that Lua can inspect (and fall back to a default non‑BCI mapping), and if so, should bindings be allowed to declare whether they are **mandatory** for a region class or **optional**?  

8. **Binding composability**  
   Do we want to support composable bindings (e.g., one binding for visual masking, another for haptics) instead of a single `curves.visual/audio/haptics` bundle, and would that be better represented as multiple binding objects or a new `bindingKind` field?  

9. **Filter semantics for metrics**  
   Should `metricsFilter` ranges be interpreted strictly (binding only active when UEC/ARR are inside the bands) or as hints to encourage/avoid bindings (e.g., prefer a binding while ARR is low but do not hard‑disable others)?  

10. **Schema references to contract context**  
    Should the binding schema directly reference contract‑related IDs (policyEnvelope, regionContractCard) to make explicit which narrative contracts the binding is intended to operate under, or should that mapping live in a separate registry indexed by `bindingId`?  

***

## 2. Curve families, parameters, and safety

11. **Parameter semantics per family code**  
    For each `familyCode` (linear, sigmoid, hysteresis, oscillatory, piecewise, noise‑augmented), what precise semantic meaning should we assign to the four `params` (e.g., `min`, `max`, `midpoint`, `steepness`, or `amplitude`, `frequency`, `bias`, `jitter`), and should we codify that in a Rust doc module plus a small machine‑readable `curve-family-table.json` in Neural‑Resonance‑Lab? [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_cdb90fc3-8a6a-46e2-89a6-187b2f85f988/1c3e38a9-000b-42d6-bb93-f005b8cfad2f/1-should-the-research-prioriti-tQnn6sdDQ06XDNmNoVKx.g.md)

12. **Family‑specific safety envelopes**  
    Should each curve family have its own safety envelope constraints (e.g., max slope for sigmoid, max amplitude and rate of change for oscillatory) enforced by the Rust kernel, and how do we express these limits so AI‑chat can avoid proposing pathological parameter sets?  

13. **CSI and DET coupling in evaluation**  
    What exact formula should the Rust kernel use to cap outputs based on `CSI` and `DET` (e.g., global multiplicative caps vs. per‑channel clamps), and do we need a `csiSensitivity` or `detSensitivity` field at the binding level to tune this?  

14. **Family code extensibility**  
    How should we handle introducing new `familyCode` values (e.g., for spline‑based or data‑driven mappings) without destabilizing AI‑chat’s understanding—should we have a `familyCodeCatalog` registry and train AI‑chat to consult it before use?  

15. **Parameter sampling strategies for tuning**  
    What strategies should Neural‑Resonance‑Lab use to explore parameter spaces (e.g., Latin hypercube sampling, evolutionary search) against telemetry and to lock in “good” genes for inclusion in bindings, and how should those experiments be logged?  

16. **Multi‑channel correlation limits**  
    Do we need explicit constraints in the kernel to prevent combinations of curves (e.g., high pressure + high noise + intense haptics) that might exceed safe sensory load even if each channel individually respects caps, and how would those be configured?  

17. **Determinism and floating‑point stability**  
    What guarantees do we require about deterministic evaluation of curve families across platforms (x86, ARM) and compilers, and should we restrict ourselves to a specific set of `f32` operations or use fixed‑point for critical paths?  

18. **Explicit “cooldown” behavior in families**  
    Should some family types explicitly model cooldown behavior (e.g., hysteresis curves that resist rising again after a spike) tied to CSI history, and how would bindings indicate when this behavior should be engaged?  

19. **Family combinations vs. single family**  
    Do we need support for combining multiple family evaluations (e.g., base linear + oscillatory modulation) for a single output channel, and if so, should that be encoded as nested `curveAssignment` objects or as a new composite family?  

20. **Safety profile tiering**  
    How many distinct `safetyProfile` tiers (e.g., “tutorial_soft”, “standard_corridor”, “liminal_strict”, “experimental_lab”) should we define, and should they be centrally registered so bindings refer only to IDs instead of inline numbers?  

***

## 3. Rust crate design and FFI boundaries

21. **Crate layout for BCI geometry**  
    Should the BCI geometry kernel live as a standalone crate (e.g., `crates/bci_geometry_kernel`) shared between Death‑Engine and Neural‑Resonance‑Lab, or should each repo have a thin crate that wraps a common core module kept in one repository?  

22. **Separation of concerns inside the crate**  
    How should we structure the kernel crate modules (`summary`, `inputs`, `curves`, `safety`, `ffi`) to make it easy for AI‑chat to target the right types and functions without exposing internal implementation details?  

23. **C ABI surface minimization**  
    What is the minimal C ABI surface we want to expose for BCI geometry evaluation (e.g., a single `evaluate_binding` vs. multiple specialized functions), and how do we ensure the structs are POD and stable for C++ and Lua FFI?  

24. **Schema‑aware validation in Rust**  
    Should the Rust kernel own JSON‑schema validation for bindings (e.g., using `jsonschema` crate) so that bindings deserialized at runtime are re‑checked against `bci-geometry-binding-v1.json`, or should validation remain a CI‑only concern?  

25. **Error reporting and telemetry hooks**  
    How should the FFI functions report errors (numeric codes vs. structured error JSON), and do we need a dedicated telemetry output path for logging evaluation failures or clamping events back into Neural‑Resonance‑Lab?  

26. **Runtime configuration vs. compile‑time constants**  
    Which parts of the geometry kernel (family code catalog, safety profile defaults) should be compile‑time constants, and which should be loaded from JSON so experiments can be run without recompiling the engine?  

27. **Testing and CI harnesses**  
    How should we extend the existing lab C‑ABI harness pattern (mock driver, NDJSON trace replay) to test BCI geometry evaluation across bindings, ensuring outputs stay within caps and bindings behave as expected under canonical traces? [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_cdb90fc3-8a6a-46e2-89a6-187b2f85f988/2c681b6f-1845-4a79-9464-ddf8cfa3208d/this-research-focuses-on-desig-DemATE1ZRtOBxLRQlhB93g.md)

28. **Docstrings and Rustdoc for AI‑chat**  
    What level of Rustdoc detail should we add to the kernel types (especially `BciSummary`, `BciMappingInputs`, `CurveFamilyCode`, `BciMappingOutputs`) to maximize AI‑chat’s ability to produce correct code directly against the crate?  

29. **Feature gating for experimental bindings**  
    Should the crate expose feature flags (Cargo features) for experimental binding behaviors (e.g., enabling new family codes or debug logging) to separate lab vs. production builds, and how should AI‑chat be instructed to use those?  

30. **Performance profiling expectations**  
    What performance budgets per frame (in microseconds) do we want for BCI geometry evaluation on typical hardware, and how should we instrument the Rust crate (e.g., `tracing` spans) to verify we stay within those budgets?  

***

## 4. Lua orchestration, H. APIs, and engine integration

31. **Binding lookup strategy in Lua**  
    Should the Lua resolver (`BciGeometry.resolveBinding`) operate strictly on pre‑filtered arrays of bindings by region class, or should it always scan all bindings with heuristics to choose the “best” match, and how do we expose this behavior in a way AI‑chat can reason about? [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_cdb90fc3-8a6a-46e2-89a6-187b2f85f988/1c3e38a9-000b-42d6-bb93-f005b8cfad2f/1-should-the-research-prioriti-tQnn6sdDQ06XDNmNoVKx.g.md)

32. **Contract context injection**  
    How should contract context (`policyEnvelope`, `regionContractCard`, `seedContractCard`) be injected into the BCI mapping pipeline in Lua—via a dedicated `H.Contract` API, or passed explicitly to every BCI call as a structured table?  

33. **Metric state update semantics**  
    After Rust returns `BciMappingOutputs` and/or a `bci-metrics-envelope`, what is the canonical Lua API for updating engine metric state: should there be a single `H.Metrics.applyBciMetrics(envelope)` function, or separate setters per metric?  

34. **Drift detection location**  
    Should drift detection (comparing live metrics vs. contract expectations) live inside `hpcbciadapter.lua`, a dedicated Lua module, or a Rust component, and how should its output be serialized (e.g., NDJSON events) for AI‑authoring tools?  

35. **Event hooks for BCI transitions**  
    Do we need standard Lua events (e.g., `OnBciStateChanged`, `OnOverloadFlagRaised`) that other systems (AI, audio, level logic) can subscribe to, and how should they be parameterized to avoid leaking raw BCI details?  

36. **DeadLantern and VFX integration patterns**  
    What is the recommended Lua pattern for connecting `BciMappingOutputs.visual` to DeadLantern and other VFX parameters—should we define a single `H.Visual.applyBciMask(params)` function, or explicit mapping tables per system?  

37. **Haptics routing decisions in Lua**  
    How should Lua decide which haptic devices/channels to route `HapticParams` to (e.g., chest vs. hands vs. chair), and should bindings be able to specify routing hints, or should routing be an engine‑specific configuration?  

38. **BCI debugging and visualization**  
    What kind of in‑engine debug visualization should we support (e.g., overlays showing CIC/LSG vs. stress/overload vs. binding ID), and should Lua helpers be responsible for rendering these, or should debug UIs be driven from Rust metrics?  

39. **Script‑level error handling**  
    When the Rust FFI returns an error (invalid binding, buffer too small, JSON parse error), how should `hpcbciadapter.lua` handle it: fallback to non‑BCI behavior, log and continue, or disable bindings for the session?  

40. **AI‑chat‑friendly Lua module layout**  
    How should we organize Lua source files (`scripts/hpcbciadapter.lua`, `scripts/hpcbciimport.lua`, `scripts/hpcbci_debug.lua`, `scripts/hpci_geometry.lua`) so that AI‑chat can discover and reuse patterns consistently across the engine?  

***

## 5. AI‑chat authoring, governance, and objections

41. **Authoring prompts for bindings**  
    What exact prompt templates and constraints should be used when AI‑chat is asked to generate new `BCI_GEOMETRY_BINDING` objects so that it always respects the schema, uses only approved `familyCode` values, and keeps numeric ranges within safe bounds? [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_cdb90fc3-8a6a-46e2-89a6-187b2f85f988/2c681b6f-1845-4a79-9464-ddf8cfa3208d/this-research-focuses-on-desig-DemATE1ZRtOBxLRQlhB93g.md)

42. **Schema‑first discovery flow**  
    How should AI‑chat discover the binding schema and sample file (e.g., always read `bci-geometry-binding-v1.json` and `bci-geometry-bindings.lab.sample.json` first) before generating or editing bindings, and should we formalize this as an AI‑authoring contract?  

43. **One‑file‑per‑turn enforcement**  
    How should we wrap AI‑generated bindings and docs inside the constellation’s AI‑authoring envelopes (request/response + prism), ensuring each change is tracked as a single logical changeset with associated schema references and agent profile?  

44. **Objection: over‑reliance on BCI**  
    How do we guard against over‑reliance on BCI signals in bindings (e.g., horror intensity collapsing for players with flat or noisy signals), and should bindings be required to specify a non‑BCI fallback curve or mode?  

45. **Objection: content determinism vs. personalization**  
    How do we reconcile the need for determinism (replayability, contract enforcement) with BCI‑driven personalization that can significantly change intensity, and should AI‑chat be allowed to author bindings that can swing horror intensity widely based on BCI alone?  

46. **Metadata for experiment provenance**  
    Should bindings include metadata fields for experiment provenance (e.g., which dataset analysis or telemetry cluster they were derived from), so AI‑chat and humans can distinguish “theory” bindings from empirically tuned ones?  

47. **Rating‑aware binding constraints**  
    How should content rating/intensity tiers be represented in bindings (e.g., `allowedRatings: ["T", "M"]`) so AI‑chat cannot propose high‑intensity BCI responses in low‑intensity game modes or regions?  

48. **Training data leakage risks**  
    How do we ensure that AI‑chat does not leak details of external BCI datasets (e.g., subject IDs, proprietary stimulus names) into bindings, docs, or code, and should we add explicit prohibitions and checks in AI‑authoring contracts?  

49. **Cross‑repo binding references**  
    Should we allow bindings in Death‑Engine to reference schemas or documents in Neural‑Resonance‑Lab and Horror.Place‑Constellation‑Contracts explicitly (via `schemaref` and `docRef` fields), and what governance rules are needed to keep those references stable?  

50. **“Kill switch” design for BCI geometry**  
    What is the canonical design for a BCI geometry “kill switch” (e.g., per‑session flag, tiered override, or runtime contract change) that can safely disable all BCI‑driven geometry and revert to baseline mappings without breaking bindings or invariants?  

***

These 50 questions can be used as a structured backlog for design discussions, code tasks, and AI‑assisted authoring envelopes. They are designed to surface missing definitions, schemas, crate structures, Lua entry‑points, and governance rules needed to complete the BCI geometry and mapping layer for HorrorPlace’s VM‑constellation. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_cdb90fc3-8a6a-46e2-89a6-187b2f85f988/1c3e38a9-000b-42d6-bb93-f005b8cfad2f/1-should-the-research-prioriti-tQnn6sdDQ06XDNmNoVKx.g.md)
