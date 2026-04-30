# Monster-Mode BCI Style Catalog v1

This document is the **style catalog** for BCI‑driven monster‑mode effects in Death‑Engine. It tells AI‑chat which styles exist, where their bindings live, and how they map BciSummary fields and invariants into visual/audio behavior, without ever bypassing Rust safety kernels or schemas.

All styles are implemented as **bci‑geometry bindings** that consume:

- `BciSummary` (stressBand, attentionBand, visualOverloadIndex, startleSpike, signalQuality)
- Invariants (CIC, LSG, DET, etc.)
- Entertainment metrics (UEC, EMD, STCI, CDL, ARR)
- CSI (Cooldown Stress Index)

and produce **visual/audio/haptic outputs** through the Rust geometry kernel, with clamping enforced by `BciSafetyProfile`.

## Style discovery and directory layout

Monster‑mode styles are discoverable in two ways:

1. **Style packs (per‑style directories)**  
   Each style pack sits in **Death-Engine** under:

   ```text
   styles/<Style-Name>/
       bci-geometry-bindings.<style-name>.json   # binding collection, lab or runtime tier
       style-spec.md                             # human + AI spec
       (optional) examples/sample-telemetry.ndjson
   ```

   The binding file always conforms to `bci-geometry-binding-v1.json` and uses canonical ranges (`Range01`, `Range010`) for all filters and curves.

2. **Global style index**

   A single registry file in Death-Engine:

   ```text
   style-registry/style-index.json
   ```

   lists all known styles with fields like:

   ```json
   {
     "schema": "hpnrl-style-index-v1",
     "styles": [
       {
         "name": "Rotting-Visuals",
         "dir": "styles/Rotting-Visuals/",
         "tier": "lab",
         "tags": ["visual-rot", "monster-mode"],
         "experienceType": ["survival-horror"]
       }
       // ...
     ]
   }
   ```

   AI‑chat should **always consult `style-index.json` first** when discovering or extending styles.

---

## Existing monster-mode styles (baseline seeds)

This section lists the six baseline styles that anchor monster‑mode authoring. Each entry provides: canonical directory, binding file, BCI hooks, and a short authoring request that can be embedded in `ai-bci-geometry-request-v1` envelopes.

### Rotting-Visuals

**Dir:** `styles/Rotting-Visuals/`  
**Bindings:** `bci-geometry-bindings.rotting-visuals.json`  
**Experience:** Corridor / infection‑adjacent monster‑mode.

**Visual intent**

Surfaces, props, and distant silhouettes “rot” over time: edges crumble, textures darken, and patches of void appear. Rot progression accelerates with higher stressBand and DET, but is clamped by safety to avoid constant full‑rot.

**Audio intent**

Sub‑audible creaks and wet degradation noises that grow with UEC and STCI. High stress triggers occasional “rot pops” (micro‑bursts of crackling) but never at seizure‑risk repetition.

**BCI hooks**

- Rot intensity increases with **stressBand** and **visualOverloadIndex**.
- DET influences how long a given region can remain in heavy rot before recovery.
- Safe zones or low CSI drive visible “healing” of surfaces.

**Authoring request pattern**

When asking AI‑chat to extend Rotting‑Visuals:

```json
{
  "schemaVersion": "1.0.0",
  "targetRepo": "HorrorPlace-Neural-Resonance-Lab",
  "targetPath": "examples/bci/styles/Rotting-Visuals/bci-geometry-bindings.rotting-visuals.lab.sample.json",
  "bindingSchemaId": "hpnrl-bci-geometry-binding-v1",
  "regionHints": {
    "regionClass": "corridor",
    "style": "Rotting-Visuals"
  },
  "experienceType": "monster-mode",
  "constraints": {
    "allowedTiers": ["lab"],
    "allowedSafetyProfiles": ["monster-mode-standard"],
    "maxCurveComplexity": "medium",
    "maxBindings": 4,
    "notes": "Extend Rotting-Visuals for different CIC/DET slices, preserving neurorights caps."
  }
}
```

---

### Safe-Rot-Saferoom

**Dir:** `styles/Safe-Rot-Saferoom/`  
**Bindings:** `bci-geometry-bindings.safe-rot-saferoom.json`  
**Experience:** Saferooms with gentle rot hints, never aggressive.

**Visual intent**

Soft rot hints on the periphery, but central view remains stable. Subtle breathing of environmental grime, never full corruption. Always feels like a **buffer** between horror spikes.

**Audio intent**

Low‑mixing ambient rot: distant drips, faint structural groans. Never intrusive, never loud. Serves as a tension floor between intense encounters.

**BCI hooks**

- StressBand is used primarily as a **cap**: higher stress cuts rot intensity down.
- VisualOverloadIndex keeps all effects muted when overload is high.
- CSI and DET cooperate to lengthen safe windows after startle spikes.

**Authoring request pattern**

```json
{
  "schemaVersion": "1.0.0",
  "targetRepo": "HorrorPlace-Neural-Resonance-Lab",
  "targetPath": "examples/bci/styles/Safe-Rot-Saferoom/bci-geometry-bindings.safe-rot-saferoom.lab.sample.json",
  "bindingSchemaId": "hpnrl-bci-geometry-binding-v1",
  "regionHints": {
    "regionClass": "safe-buffer",
    "style": "Safe-Rot-Saferoom"
  },
  "experienceType": "monster-mode",
  "constraints": {
    "allowedTiers": ["lab"],
    "allowedSafetyProfiles": ["monster-mode-soft"],
    "maxCurveComplexity": "low",
    "maxBindings": 2,
    "notes": "Safe-rot bindings must always reduce or flatten intensity as stress rises."
  }
}
```

---

### Hive-Mind-Phase

**Dir:** `styles/Hive-Mind-Phase/`  
**Bindings:** `bci-geometry-bindings.hive-mind-phase.json`  
**Experience:** Collective infection / archive‑network segments.

**Visual intent**

Phase‑shifted geometry, subtle double‑vision, and synchronized material pulses that suggest a shared neural substrate across the space. Visible “phase” heightens when attentionBand is HyperFocused in infected regions.

**Audio intent**

Layered whispers, phased drones, and phase‑aligned “call and response” motifs between different corners of the space.

**BCI hooks**

- Higher **CIC** and **LSG** invariants sharpen phase coherence.
- **AttentionBand** and **stressBand** gate how intense the phasing is.
- VisualOverloadIndex caps extreme phase artifacts to remain readable.

**Authoring request pattern**

```json
{
  "schemaVersion": "1.0.0",
  "targetRepo": "HorrorPlace-Neural-Resonance-Lab",
  "targetPath": "examples/bci/styles/Hive-Mind-Phase/bci-geometry-bindings.hive-mind-phase.lab.sample.json",
  "bindingSchemaId": "hpnrl-bci-geometry-binding-v1",
  "regionHints": {
    "regionClass": "archive",
    "style": "Hive-Mind-Phase"
  },
  "experienceType": "monster-mode",
  "constraints": {
    "allowedTiers": ["lab"],
    "allowedSafetyProfiles": ["monster-mode-standard"],
    "maxCurveComplexity": "medium",
    "maxBindings": 4,
    "notes": "Bindings should emphasize coherence between BciSummary bands and spatial phase, never override safety caps."
  }
}
```

---

### Bone-Static

**Dir:** `styles/Bone-Static/`  
**Bindings:** `bci-geometry-bindings.bone-static.json`  
**Experience:** Narrow corridors with brittle, skeletal ambience.

**Visual intent**

Fine‑grained static that clings to bones, pipes, and skeletal props, especially at the edge of vision. Micro‑jitter and grain intensify as stress rises, but central silhouette remains readable.

**Audio intent**

Dry, bone‑like clicks and micro‑fractures embedded in the ambience. Under stress, subtle “joint popping” textures appear, capped by safety to remain non‑piercing.

**BCI hooks**

- Static intensity maps to **stressScore** and **visualOverloadIndex**, smoothed by CSI.
- High DET triggers slow‑rising static that fades in recovery windows.

**Authoring request pattern**

(as previously defined; kept here for completeness)

```json
{
  "schemaVersion": "1.0.0",
  "targetRepo": "HorrorPlace-Neural-Resonance-Lab",
  "targetPath": "examples/bci/styles/Bone-Static/bci-geometry-bindings.bone-static.lab.sample.json",
  "bindingSchemaId": "hpnrl-bci-geometry-binding-v1",
  "regionHints": {
    "regionClass": "corridor",
    "style": "Bone-Static",
    "personaMode": "brittle-static"
  },
  "experienceType": "monster-mode",
  "constraints": {
    "allowedTiers": ["lab"],
    "allowedSafetyProfiles": ["monster-mode-standard"],
    "maxCurveComplexity": "medium",
    "maxBindings": 3,
    "notes": "Extend Bone-Static with variations on CIC/DET; emphasize brittle micro-stutter without violating safety caps."
  }
}
```

---

### Flooded-Sense

**Dir:** `styles/Flooded-Sense/`  
**Bindings:** `bci-geometry-bindings.flooded-sense.json`  
**Experience:** Thresholds and choke points with sensory flooding.

**Visual intent**

Lens blur, heavy contrast smearing, and depth‑of‑field shifts that increase when stress and overload rise. Visual tunnel effects appear at extreme stress but are bounded to avoid full loss of agency.

**Audio intent**

Muffled ambience, underwater‑style filtering, and low‑band rumble that swell with stressScore and UEC.

**BCI hooks**

- High **stressBand** and **visualOverloadIndex** drive blur and muffling.
- Recovery windows reduce tunnel strength as CSI cools.
- Safe buffers disable the most intense tunnel artifacts.

**Authoring request pattern**

```json
{
  "schemaVersion": "1.0.0",
  "targetRepo": "HorrorPlace-Neural-Resonance-Lab",
  "targetPath": "examples/bci/styles/Flooded-Sense/bci-geometry-bindings.flooded-sense.lab.sample.json",
  "bindingSchemaId": "hpnrl-bci-geometry-binding-v1",
  "regionHints": {
    "regionClass": "threshold",
    "style": "Flooded-Sense",
    "personaMode": "sensory-flood"
  },
  "experienceType": "monster-mode",
  "constraints": {
    "allowedTiers": ["lab"],
    "allowedSafetyProfiles": ["monster-mode-standard"],
    "maxCurveComplexity": "medium",
    "maxBindings": 4,
    "notes": "Design blur/muffle curves that scale with stress/overload while honoring DET/CSI caps."
  }
}
```

---

### Parasite-Hum

**Dir:** `styles/Parasite-Hum/`  
**Bindings:** `bci-geometry-bindings.parasite-hum.json`  
**Experience:** Archive / machine‑adjacent parasitic ambience.

**Visual intent**

Barely perceptible ripples and shimmer around cables, vents, and archive fixtures, as if a parasite signal runs through them. Stronger in peripheral vision; central clarity is preserved.

**Audio intent**

Narrowband hums, subtle detunes, and whispered carrier tones that focus around the player’s head. Localized neck/ear phantom haptics in supported rigs.

**BCI hooks**

- **AttentionBand** and **stressBand** control how “present” the hum feels.
- EMD and ARR modulate the perceived directionality and density of hum nodes.
- Overload and high CSI flatten or gate the most aggressive elements.

**Authoring request pattern**

```json
{
  "schemaVersion": "1.0.0",
  "targetRepo": "HorrorPlace-Neural-Resonance-Lab",
  "targetPath": "examples/bci/styles/Parasite-Hum/bci-geometry-bindings.parasite-hum.lab.sample.json",
  "bindingSchemaId": "hpnrl-bci-geometry-binding-v1",
  "regionHints": {
    "regionClass": "archive",
    "style": "Parasite-Hum",
    "personaMode": "hive-whisper"
  },
  "experienceType": "monster-mode",
  "constraints": {
    "allowedTiers": ["lab"],
    "allowedSafetyProfiles": ["monster-mode-standard"],
    "maxCurveComplexity": "medium",
    "maxBindings": 4,
    "notes": "Explore attention band splits and localized hum, with strict caps via BciSafetyProfile."
  }
}
```

---

## New style packs (10 additional concepts)

The following styles are **not present** in earlier lists and should be registered in `style-index.json` with tier `"lab"` initially. For each, AI‑chat should create and maintain a `style-spec.md` and `bci-geometry-bindings.<style>.json` in the indicated directory, always respecting `bci-geometry-binding-v1.json` and safety profiles.

### Echo-Decay

**Dir:** `styles/Echo-Decay/`  
**Bindings:** `bci-geometry-bindings.echo-decay.json`

**Visual intent**

Delayed “ghost” frames of the player’s own movement that slowly decay, with ghost intensity and trail length tied to stressScore and visualOverloadIndex. Chromatic aberration and slight desync emphasize unease, but central motion remains controllable.

**Audio intent**

Temporal echoes of recent sound events (footsteps, door creaks, monster calls) that repeat with decaying gain and increasing delay, bounded by safety so the mix never becomes a wall of noise.

**BCI hooks**

- Echo lag ≈ \((\text{stressScore} + \text{visualOverloadIndex}) / 2\), clamped by safety.
- startleSpike temporarily zeroes delay and gain; curves ramp back in over CSI‑governed recovery.

---

### Corridor-Breath

**Dir:** `styles/Corridor-Breath/`  
**Bindings:** `bci-geometry-bindings.corridor-breath.json`

**Visual intent**

Subtle “breathing” of corridor perspective and focus: gentle FOV and focus‑pull oscillations that feel like the space is inhaling and exhaling around the player.

**Audio intent**

Low‑frequency exhalation textures layered under the corridor ambience, centered in front of the player. Effects fade in safe buffers and during high overload.

**BCI hooks**

- Breath rate follows a heart‑rate‑like band (e.g., hrBand) mapped into BPM, smoothed.
- Breath depth scales with stressScore but is reduced if visualOverloadIndex is high or CSI is near caps.

---

### Shadow-Mend

**Dir:** `styles/Shadow-Mend/`  
**Bindings:** `bci-geometry-bindings.shadow-mend.json`

**Visual intent**

Shadows that “heal” and cohere when the player is calmer, and fragment into crawling, splintered forms at High or Extreme stressBand. Never fully obscure navigation; safety profiles cap darkness and movement.

**Audio intent**

Soft, restorative chimes and harmonic pads as stress drops; at high stress, comb‑filtered ambient drones create a brittle edge.

**BCI hooks**

- Shadow mend intensity ≈ \(1.0 - \text{stressScore}\), with maxDeltaPerSecond clamps.
- AttentionBand can bias certain shadow behaviors for HyperFocused vs Distracted states.

---

### Verdigris-Tint

**Dir:** `styles/Verdigris-Tint/`  
**Bindings:** `bci-geometry-bindings.verdigris-tint.json`

**Visual intent**

Blue‑green oxidation creeping across metal and stone, more pronounced when the player is disengaged (low attention) and backing off when they focus on threats.

**Audio intent**

Metallic pings, scraping corrosion, and subtle filter sweeps; clarity increases as attentionBand moves toward Focused/HyperFocused.

**BCI hooks**

- Tint opacity increases when attentionBand indicates distraction; curves flatten when stressBand is Extreme to avoid visual overload.
- Safety profile may define a “max corrosion opacity” independent of BCI.

---

### Pupil-Flare

**Dir:** `styles/Pupil-Flare/`  
**Bindings:** `bci-geometry-bindings.pupil-flare.json`

**Visual intent**

Simulated pupil adaptation: halos around bright sources bloom when visualOverloadIndex is elevated and settle toward neutral as overload abates. Extreme states are clamped to soft washes that preserve silhouettes.

**Audio intent**

Subtle, high‑frequency ringing or flanging following sharp intensity changes, particularly after startleSpike events.

**BCI hooks**

- Flare radius and halo softness scale with visualOverloadIndex, under a family curve (e.g., PKLIN/PKSIG).
- Recovery windows follow CSI cooldown, with hard caps from BciSafetyProfile.

---

### Brain-Static

**Dir:** `styles/Brain-Static/`  
**Bindings:** `bci-geometry-bindings.brain-static.json`

**Visual intent**

High‑frequency static and grain at the edges of vision, akin to CRT snow, phase‑modulated by visualOverloadIndex but always leaving central focus clear.

**Audio intent**

Broadband noise layers that grow when the player is Distracted and recede when attentionBand is Focused or HyperFocused.

**BCI hooks**

- Noise opacity ≈ base + visualOverloadIndex × factor, cut entirely when startleSpike plus overload gates engage.
- CSI and DET shape how quickly static ramps up/down to avoid nausea.

---

### Crystal-Shatter

**Dir:** `styles/Crystal-Shatter/`  
**Bindings:** `bci-geometry-bindings.crystal-shatter.json`

**Visual intent**

Crystalline shards and crack patterns overlaying surfaces, spreading during high stressScore and retreating as the player regains composure. Fracture animations respect motion and intensity caps.

**Audio intent**

Glass‑like pings and micro‑shatters, scattered in space; number of events per second is bounded by safety and influenced by heart‑rate‑like bands.

**BCI hooks**

- Crack propagation and density scale with \(\text{stressScore} \times \text{CIC}\), bounded by per‑frame delta caps.
- Recovery aligns with CSI decay to create “healing glass” moments.

---

### Flesh-Meld

**Dir:** `styles/Flesh-Meld/`  
**Bindings:** `bci-geometry-bindings.flesh-meld.json`

**Visual intent**

Organic, flesh‑like displacement of surfaces in infected zones, driven by arousal bands (e.g., edaBand). Surfaces appear to breathe or swell but flatten back as attentionBand becomes Extreme.

**Audio intent**

Wet, gurgling body‑horror textures mixed under ambience; stereo width narrows at high arousal, then widens as stressScore drops.

**BCI hooks**

- Displacement strength follows arousal bands and is shaped by sigmoid curve families; safety caps prevent extreme warping.
- High visualOverloadIndex or overload gates reduce deformation to prevent discomfort.

---

### Time-Stutter

**Dir:** `styles/Time-Stutter/`  
**Bindings:** `bci-geometry-bindings.time-stutter.json`

**Visual intent**

Occasional frame‑freeze stutters and skip‑repeats that feel like the world desynchronizing under stress. Safe‑Rot‑Saferooms suppress these entirely.

**Audio intent**

Micro‑dropouts, tape‑stop glides, and glitch events on ambient layers, tied to stressScore but limited in frequency and depth.

**BCI hooks**

- Stutter probability ∝ stressScore, but forced to zero when overload flags or safety caps deem it unsafe.
- DET and CSI influence the maximum stutter density over time.

---

### Low-Fidelity-Dread

**Dir:** `styles/Low-Fidelity-Dread/`  
**Bindings:** `bci-geometry-bindings.low-fidelity-dread.json`

**Visual intent**

Deliberate resolution degradation, color banding, and scanline artifacts as stress and visualOverloadIndex rise. The image never becomes fully unreadable; BciSafetyProfile enforces a minimum resolution factor.

**Audio intent**

Bit‑crushed and sample‑rate‑reduced ambience, with noise floors rising at High stressBand, but bounded to remain intelligible.

**BCI hooks**

- Resolution factor ≈ \(1.0 - 0.8 \times \text{visualOverloadIndex}\), clamped to ≥ 0.5 by safety.
- Audio bit‑depth and rate follow stressScore within limits defined by the safety profile.

---

## AI-chat authoring contract for styles

When AI‑chat is asked to work with monster‑mode styles:

1. **Always start from schemas and registry**

   - Load `style-registry/style-index.json`.
   - Load the relevant `bci-geometry-binding-v1.json` schema and any spine schemas defining `Range01`/`Range010`, invariants, and metrics.
   - Do not invent new top‑level fields or metric spaces.

2. **Only author bindings and specs**

   - For a given style, edit or extend:
     - `styles/<Style-Name>/bci-geometry-bindings.<style-name>.json`
     - `styles/<Style-Name>/style-spec.md`
   - Keep all numeric values within canonical ranges and respect BciSafetyProfile limits by reference (via `profileId`), not by inlining arbitrary caps.

3. **Use BciSummary and invariants as inputs, never raw EEG**

   - Bindings may filter on:
     - BciSummary: stressBand, attentionBand, visualOverloadIndex, startleSpike, signalQuality.
     - Invariants: CIC, LSG, DET, and related history terms.
     - Metrics: UEC, EMD, STCI, CDL, ARR.
   - No binding may reference raw EEG channels or PII.

4. **Let Rust own curves, safety, and CSI**

   - Curve families (PKLIN, PKSIG, PKHYS, etc.) and their parameters must remain within the documented catalog.
   - CSI update formulas and per‑channel caps are enforced in Rust; AI‑chat must not alter them.
   - Bindings select a `safetyProfile.profileId` and curve assignments only.

5. **Prefer small, focused changes**

   - Each AI‑authored change should add or adjust a small number of bindings per style (e.g., 1–4), with clear `notes` describing intent.
   - Golden patterns from existing styles (e.g., Rotting‑Visuals or Safe‑Rot‑Saferoom) should be cloned and adapted, not re‑invented.

With this catalog, AI‑chat can safely discover all monster‑mode style packs, understand their BCI semantics, and generate new bindings, specs, and code stubs that remain aligned with the schema‑first, safety‑first doctrine of the Horror.Place constellation.
