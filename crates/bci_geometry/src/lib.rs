// target-repo: Death-Engine
// file: crates/bci_geometry/src/lib.rs

use crate::binding::BciGeometryBinding;
use crate::inputs::BciMappingInputs;
use crate::outputs::BciMappingOutputs;
use crate::safety::{BciSafetyProfile, BciKernelState, apply_safety_caps};

/// Main entrypoint for BCI geometry evaluation.
/// 
/// This function implements the full mapping pipeline:
/// 1. Resolve binding from registry using request context (in Rust kernel)
/// 2. Build weighted input vector using binding.inputWeights
/// 3. Evaluate curve families per binding.curves
/// 4. Apply CSI/DET global caps from safety.timingCaps
/// 5. Apply per-channel intensity/rate caps and recovery windows
/// 6. Return clamped BciMappingOutputs
/// 
/// # Safety Enforcement
/// All neurorights constraints from BciSafetyProfile are enforced here.
/// Lua must not implement safety logic; this is the single source of truth.
pub fn evaluate_mapping(
    binding: &BciGeometryBinding,
    inputs: &BciMappingInputs,
    safety: &BciSafetyProfile,
    state: &mut BciKernelState,
    dt: f32,
) -> BciMappingOutputs {
    // 1. Build weighted input vector
    let weighted_input = build_weighted_input(binding, inputs);
    
    // 2. Evaluate curves per channel
    let mut outputs = evaluate_curves(binding, &weighted_input);
    
    // 3. Apply safety caps (CSI/DET ceilings, intensity/rate limits, recovery)
    apply_safety_caps(&mut outputs, inputs, safety, state, dt);
    
    outputs
}

// Internal: compute weighted scalar from invariants + BciSummary + metrics
fn build_weighted_input(
    binding: &BciGeometryBinding,
    inputs: &BciMappingInputs,
) -> f32 {
    let weights = &binding.inputWeights;
    let mut sum = 0.0;
    
    // BciSummary contributions
    sum += weights.stressScore.unwrap_or(0.4) * inputs.summary.stress_score;
    sum += weights.visual_overload_index.unwrap_or(0.2) * inputs.summary.visual_overload_index;
    
    // Invariant contributions
    sum += weights.cic.unwrap_or(0.05) * inputs.invariants.cic;
    sum += weights.lsg.unwrap_or(0.05) * inputs.invariants.lsg;
    
    // Optional metric gating (extra observation channel)
    if let Some(metrics) = &inputs.metrics {
        sum += weights.uec.unwrap_or(0.1) * metrics.uec_band;
        sum += weights.arr.unwrap_or(0.1) * metrics.arr_band;
    }
    
    sum.clamp(0.0, 1.0)
}

// Internal: evaluate curve families for each output channel
fn evaluate_curves(
    binding: &BciGeometryBinding,
    weighted_input: &f32,
) -> BciMappingOutputs {
    let curves = &binding.curves;
    
    BciMappingOutputs {
        visual: eval_curve_assignment(&curves.visual, *weighted_input),
        audio: AudioOutputs {
            pressure_lf: eval_curve_assignment(&curves.audio.pressure_lf, *weighted_input),
            whisper_send: curves.audio.whisper_send.as_ref()
                .map(|c| eval_curve_assignment(c, *weighted_input)),
            // ... other audio params
        },
        haptics: HapticOutputs {
            intensity: eval_curve_assignment(&curves.haptics.intensity, *weighted_input),
            pulse_hz: curves.haptics.pulse_hz.as_ref()
                .map(|c| eval_curve_assignment(c, *weighted_input)),
        },
    }
}

// Internal: evaluate a single curve assignment
fn eval_curve_assignment(assignment: &CurveAssignment, input: f32) -> f32 {
    match assignment.family_code.as_str() {
        "PKLIN" => eval_linear(assignment.params, input),
        "PKSIG" => eval_sigmoid(assignment.params, input),
        "PKHYS" => eval_hysteresis(assignment.params, input),
        "PKRHY" => eval_oscillatory(assignment.params, input),
        "PKAMB" => eval_ambient(assignment.params, input),
        "PKSTC" => eval_step(assignment.params, input),
        _ => 0.0, // Unknown family -> zero output
    }
}
