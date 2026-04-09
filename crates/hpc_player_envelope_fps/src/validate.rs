// crates/hpc_player_envelope_fps/src/validate.rs

use crate::{PlayerEnvelopeCfg, simulate_worst_case};
use crate::State;

pub struct SafetyReport {
    pub ok: bool,
    pub violations: Vec<String>,
}

fn check_bounds(cfg: &PlayerEnvelopeCfg, state: &State) -> Vec<String> {
    let mut v = Vec::new();
    if state.v < cfg.stateBounds.v.min || state.v > cfg.stateBounds.v.max {
        v.push("v_out_of_bounds".to_string());
    }
    if state.stamina < cfg.stateBounds.stamina.min || state.stamina > cfg.stateBounds.stamina.max {
        v.push("stamina_out_of_bounds".to_string());
    }
    if state.sanity < cfg.stateBounds.sanity.min || state.sanity > cfg.stateBounds.sanity.max {
        v.push("sanity_out_of_bounds".to_string());
    }
    if state.R < cfg.stateBounds.R.min || state.R > cfg.stateBounds.R.max {
        v.push("R_out_of_bounds".to_string());
    }
    if state.O < cfg.stateBounds.O.min || state.O > cfg.stateBounds.O.max {
        v.push("O_out_of_bounds".to_string());
    }
    if state.battery < cfg.stateBounds.battery.min || state.battery > cfg.stateBounds.battery.max {
        v.push("battery_out_of_bounds".to_string());
    }
    v
}

pub fn validate_cfg(cfg: &PlayerEnvelopeCfg, horizon_seconds: f32) -> SafetyReport {
    let states = simulate_worst_case(cfg, horizon_seconds);
    let mut violations = Vec::new();

    for (i, st) in states.iter().enumerate() {
        let step_violations = check_bounds(cfg, st);
        if !step_violations.is_empty() {
            for code in step_violations {
                violations.push(format!("step {}: {}", i, code));
            }
            break;
        }
    }

    SafetyReport {
        ok: violations.is_empty(),
        violations,
    }
}
