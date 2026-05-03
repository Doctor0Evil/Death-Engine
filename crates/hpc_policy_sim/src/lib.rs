use serde::{Deserialize, Serialize};

/// Net-change corridor thresholds, as loaded from net-change-corridor-v1 JSON.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetChangeThresholds {
    pub max_roh: i32,
    pub min_roh: i32,
    pub max_delta_max_det: f64,
    pub max_delta_max_cic: f64,
    pub max_delta_reach_prob: f64,
    pub max_abs_nef: f64,
}

/// Weights used when computing NEF inside a corridor.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct NetChangeWeights {
    pub w_reach_prob: f64,
    pub w_max_det: f64,
    pub w_roh: f64,
}

/// In-memory representation of a net-change corridor document.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetChangeCorridor {
    pub id: String,
    pub name: String,
    pub tier: String,
    pub thresholds: NetChangeThresholds,
    #[serde(default)]
    pub weights: NetChangeWeights,
}

/// Minimal net-change summary for a single policy modification.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetChangeSnapshot {
    /// Radius of Harm: delta in number of reachable HS nodes (after - before).
    pub roh: i32,
    /// Change in maximum DET along any path from entry to HS zones.
    pub delta_max_det: f64,
    /// Change in maximum CIC along any path from entry to HS zones.
    pub delta_max_cic: f64,
    /// Change in reachability probability to HS zones.
    pub delta_reach_prob: f64,
}

/// Evaluation result for a single policy change against a corridor.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetChangeEvaluation {
    pub corridor_id: String,
    pub within_corridor: bool,
    pub nef: f64,
    pub roh: i32,
    pub delta_max_det: f64,
    pub delta_max_cic: f64,
    pub delta_reach_prob: f64,
    pub violations: Vec<String>,
}

impl NetChangeCorridor {
    /// Compute NEF (Network Exposure Factor) for the given snapshot.
    /// NEF = w_reach_prob * delta_reach_prob
    ///     + w_max_det    * delta_max_det
    ///     + w_roh        * normalized_roh
    ///
    /// normalized_roh is roh normalized by an arbitrary scale (e.g., 10.0)
    /// so that the magnitude is comparable to other terms.
    pub fn compute_nef(&self, snapshot: &NetChangeSnapshot) -> f64 {
        let w = &self.weights;
        let norm_roh = snapshot.roh as f64 / 10.0;
        (w.w_reach_prob * snapshot.delta_reach_prob)
            + (w.w_max_det * snapshot.delta_max_det)
            + (w.w_roh * norm_roh)
    }

    /// Evaluate whether the snapshot falls within this corridor.
    /// Returns a NetChangeEvaluation that can be serialized back into
    /// policyintent.netChange or used directly by Lua/AI agents.
    pub fn evaluate(&self, snapshot: &NetChangeSnapshot) -> NetChangeEvaluation {
        let nef = self.compute_nef(snapshot);
        let mut violations = Vec::new();
        let t = &self.thresholds;

        if snapshot.roh > t.max_roh {
            violations.push(format!(
                "RoH {} exceeds maxRoH {}",
                snapshot.roh, t.max_roh
            ));
        }
        if snapshot.roh < t.min_roh {
            violations.push(format!(
                "RoH {} below minRoH {}",
                snapshot.roh, t.min_roh
            ));
        }
        if snapshot.delta_max_det > t.max_delta_max_det {
            violations.push(format!(
                "deltaMaxDet {:.4} exceeds maxDeltaMaxDet {:.4}",
                snapshot.delta_max_det, t.max_delta_max_det
            ));
        }
        if snapshot.delta_max_cic > t.max_delta_max_cic {
            violations.push(format!(
                "deltaMaxCic {:.4} exceeds maxDeltaMaxCic {:.4}",
                snapshot.delta_max_cic, t.max_delta_max_cic
            ));
        }
        if snapshot.delta_reach_prob > t.max_delta_reach_prob {
            violations.push(format!(
                "deltaReachProb {:.4} exceeds maxDeltaReachProb {:.4}",
                snapshot.delta_reach_prob, t.max_delta_reach_prob
            ));
        }
        if nef.abs() > t.max_abs_nef {
            violations.push(format!(
                "NEF {:.4} exceeds maxAbsNef {:.4}",
                nef, t.max_abs_nef
            ));
        }

        NetChangeEvaluation {
            corridor_id: self.id.clone(),
            within_corridor: violations.is_empty(),
            nef,
            roh: snapshot.roh,
            delta_max_det: snapshot.delta_max_det,
            delta_max_cic: snapshot.delta_max_cic,
            delta_reach_prob: snapshot.delta_reach_prob,
            violations,
        }
    }
}

#[cfg(feature = "ffi")]
pub mod ffi {
    use super::*;
    use std::ffi::{CStr, CString};
    use std::os::raw::{c_char, c_int};

    /// FFI function to evaluate net-change against a corridor.
    ///
    /// Inputs:
    ///   corridor_json: UTF-8 JSON string for NetChangeCorridor.
    ///   snapshot_json: UTF-8 JSON string for NetChangeSnapshot.
    ///
    /// Output:
    ///   out_buf: caller-allocated buffer for UTF-8 JSON NetChangeEvaluation.
    ///   out_cap: capacity of out_buf in bytes.
    ///
    /// Returns:
    ///   >= 0 : number of bytes written (excluding terminator).
    ///   <  0 : error code (e.g., -1 parse error, -2 buffer too small).
    #[no_mangle]
    pub extern "C" fn hpc_policy_eval_netchange(
        corridor_json: *const c_char,
        snapshot_json: *const c_char,
        out_buf: *mut c_char,
        out_cap: c_int,
    ) -> c_int {
        if corridor_json.is_null() || snapshot_json.is_null() || out_buf.is_null() || out_cap <= 0 {
            return -1;
        }

        let corridor_cstr = unsafe { CStr::from_ptr(corridor_json) };
        let snapshot_cstr = unsafe { CStr::from_ptr(snapshot_json) };

        let corridor_str = match corridor_cstr.to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        };
        let snapshot_str = match snapshot_cstr.to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        };

        let corridor: NetChangeCorridor = match serde_json::from_str(corridor_str) {
            Ok(c) => c,
            Err(_) => return -1,
        };
        let snapshot: NetChangeSnapshot = match serde_json::from_str(snapshot_str) {
            Ok(s) => s,
            Err(_) => return -1,
        };

        let eval = corridor.evaluate(&snapshot);
        let json = match serde_json::to_string(&eval) {
            Ok(j) => j,
            Err(_) => return -1,
        };

        let bytes = json.as_bytes();
        if bytes.len() + 1 > out_cap as usize {
            return -2;
        }

        unsafe {
            std::ptr::copy_nonoverlapping(
                bytes.as_ptr(),
                out_buf as *mut u8,
                bytes.len(),
            );
            *out_buf.add(bytes.len()) = 0;
        }

        bytes.len() as c_int
    }
}
