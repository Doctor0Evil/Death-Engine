// crates/bci_ema_smoothing/src/lib.rs

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};

use once_cell::sync::Lazy;
use parking_lot::Mutex;
use serde::{Deserialize, Serialize};

static CONFIG: Lazy<Mutex<EmaConfig>> = Lazy::new(|| {
    Mutex::new(EmaConfig {
        smoothing_alpha: 0.4,
        calibration_profile_id: "default".to_string(),
    })
});

#[derive(Debug, Clone)]
struct EmaConfig {
    smoothing_alpha: f32,
    calibration_profile_id: String,
}

#[derive(Debug, Deserialize)]
struct FeatureEnvelope {
    schemaVersion: String,
    windowId: String,
    sessionId: String,
    timestamp: f64,
    #[serde(default)]
    features: Vec<Feature>,
}

#[derive(Debug, Deserialize)]
struct Feature {
    featureId: String,
    #[serde(default)]
    arousalScore: Option<f32>,
    #[serde(default)]
    valenceScore: Option<f32>,
}

#[derive(Debug, Serialize)]
struct MetricsEnvelope {
    schemaVersion: String,
    windowId: String,
    sessionId: String,
    timestamp: f64,
    source: MetricsSource,
    metrics: Metrics,
    #[serde(skip_serializing_if = "Option::is_none")]
    transform: Option<MetricsTransform>,
}

#[derive(Debug, Serialize)]
struct MetricsSource {
    #[serde(skip_serializing_if = "Option::is_none")]
    featureEnvelopeId: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    calibrationProfileId: Option<String>,
}

#[derive(Debug, Serialize, Clone)]
struct Metrics {
    uecBand: f32,
    emdBand: f32,
    stciBand: f32,
    cdlBand: f32,
    arrBand: f32,
}

#[derive(Debug, Serialize)]
struct MetricsTransform {
    method: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    smoothingAlpha: Option<f32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    modelId: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    featureMappingVersion: Option<String>,
}

fn map_features_to_metrics(raw_arousal: f32, raw_valence: f32) -> Metrics {
    let a = raw_arousal.clamp(-1.0, 1.0);
    let v = raw_valence.clamp(-1.0, 1.0);

    let norm = |x: f32| 0.5 * (x + 1.0);

    let arousal_01 = norm(a);
    let valence_01 = norm(v);

    Metrics {
        uecBand: (0.7 * arousal_01 + 0.3 * (1.0 - valence_01)).clamp(0.0, 1.0),
        emdBand: (0.6 * arousal_01).clamp(0.0, 1.0),
        stciBand: (1.0 - (arousal_01 - 0.5).abs() * 2.0).clamp(0.0, 1.0),
        cdlBand: (arousal_01 - valence_01).abs().clamp(0.0, 1.0),
        arrBand: (1.0 - (arousal_01 - valence_01).abs()).clamp(0.0, 1.0),
    }
}

fn apply_ema(prev: &Metrics, current: &Metrics, alpha: f32) -> Metrics {
    let a = alpha.clamp(0.0, 1.0);
    let lerp = |p: f32, c: f32| p + a * (c - p);

    Metrics {
        uecBand: lerp(prev.uecBand, current.uecBand).clamp(0.0, 1.0),
        emdBand: lerp(prev.emdBand, current.emdBand).clamp(0.0, 1.0),
        stciBand: lerp(prev.stciBand, current.stciBand).clamp(0.0, 1.0),
        cdlBand: lerp(prev.cdlBand, current.cdlBand).clamp(0.0, 1.0),
        arrBand: lerp(prev.arrBand, current.arrBand).clamp(0.0, 1.0),
    }
}

fn process_feature_env_json(
    feature_env_json: &str,
    contract_ctx_json: &str,
) -> Result<String, String> {
    let _contract_ctx = contract_ctx_json;

    let env: FeatureEnvelope =
        serde_json::from_str(feature_env_json).map_err(|e| format!("feature JSON parse error: {e}"))?;

    let mut raw_arousal = 0.0_f32;
    let mut raw_valence = 0.0_f32;

    for f in &env.features {
        if let (Some(a), Some(v)) = (f.arousalScore, f.valenceScore) {
            raw_arousal = a;
            raw_valence = v;
            break;
        }
    }

    let base_metrics = map_features_to_metrics(raw_arousal, raw_valence);

    let cfg = CONFIG.lock();
    let prev = base_metrics.clone();
    let smoothed = apply_ema(&prev, &base_metrics, cfg.smoothing_alpha);

    let metrics_env = MetricsEnvelope {
        schemaVersion: "1.0.0".to_string(),
        windowId: env.windowId,
        sessionId: env.sessionId,
        timestamp: env.timestamp,
        source: MetricsSource {
            featureEnvelopeId: None,
            calibrationProfileId: Some(cfg.calibration_profile_id.clone()),
        },
        metrics: smoothed,
        transform: Some(MetricsTransform {
            method: "ema".to_string(),
            smoothingAlpha: Some(cfg.smoothing_alpha),
            modelId: None,
            featureMappingVersion: None,
        }),
    };

    serde_json::to_string(&metrics_env).map_err(|e| format!("metrics JSON encode error: {e}"))
}

#[no_mangle]
pub unsafe extern "C" fn hpc_bci_process(
    feature_env_json: *const c_char,
    contract_ctx_json: *const c_char,
    out_metrics_json: *mut c_char,
    out_cap: usize,
) -> c_int {
    if feature_env_json.is_null() || contract_ctx_json.is_null() || out_metrics_json.is_null() {
        return -1;
    }
    if out_cap == 0 {
        return -2;
    }

    let feature_str = match CStr::from_ptr(feature_env_json).to_str() {
        Ok(s) => s,
        Err(_) => return -3,
    };

    let contract_str = match CStr::from_ptr(contract_ctx_json).to_str() {
        Ok(s) => s,
        Err(_) => return -4,
    };

    let result = match process_feature_env_json(feature_str, contract_str) {
        Ok(json) => json,
        Err(_) => return -5,
    };

    let cstring = match CString::new(result) {
        Ok(s) => s,
        Err(_) => return -5,
    };

    let bytes = cstring.as_bytes();
    if bytes.len() + 1 > out_cap {
        return -6;
    }

    std::ptr::copy_nonoverlapping(bytes.as_ptr(), out_metrics_json as *mut u8, bytes.len());
    *out_metrics_json.add(bytes.len()) = 0;

    bytes.len() as c_int
}
