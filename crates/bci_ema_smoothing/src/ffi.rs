// target-repo: Death-Engine
// file: crates/bci_ema_smoothing/src/ffi.rs

use std::ffi::{c_char, CStr};
use std::ptr;

/// C ABI entrypoint for Lua FFI.
/// 
/// # Safety
/// - `feature_json` and `contract_json` must be valid null-terminated UTF-8 C strings.
/// - `out_metrics_json` must point to a buffer of at least `out_cap` bytes.
/// - Output JSON MUST validate against bci-metrics-envelope-v1.json.
/// - All metric bands (UEC/EMD/STCI/CDL/ARR) MUST be clamped to [0,1].
/// - DET estimate MUST be clamped to [0,10].
/// 
/// # Returns
/// - `0` on success
/// - `-1` on input parse error
/// - `-2` on schema validation error
/// - `-3` on processing error (EMA/calibration)
#[no_mangle]
pub extern "C" fn hpc_bci_process(
    feature_json: *const c_char,
    contract_json: *const c_char,
    out_metrics_json: *mut c_char,
    out_cap: usize,
) -> i32 {
    // Null checks
    if feature_json.is_null() || contract_json.is_null() || out_metrics_json.is_null() {
        return -1;
    }

    // Safe CStr conversion
    let feature_str = match unsafe { CStr::from_ptr(feature_json).to_str() } {
        Ok(s) => s,
        Err(_) => return -1,
    };
    let contract_str = match unsafe { CStr::from_ptr(contract_json).to_str() } {
        Ok(s) => s,
        Err(_) => return -1,
    };

    // Parse and validate feature envelope (schema: bci-feature-envelope-v1)
    let feature_env: BciFeatureEnvelopeV1 = match serde_json::from_str(feature_str) {
        Ok(env) => env,
        Err(_) => return -1,
    };

    // Parse contract
    let contract: ConverterContract = match serde_json::from_str(contract_str) {
        Ok(c) => c,
        Err(_) => return -1,
    };

    // Apply EMA + calibration per transform.method
    let metrics_env = match apply_ema_and_calibration(&feature_env, &contract) {
        Ok(env) => env,
        Err(_) => return -3,
    };

    // Serialize output (schema: bci-metrics-envelope-v1)
    let output_json = match serde_json::to_string(&metrics_env) {
        Ok(json) => json,
        Err(_) => return -3,
    };

    // Copy to output buffer with null termination
    if output_json.len() + 1 > out_cap {
        return -3; // Buffer too small
    }
    unsafe {
        ptr::copy_nonoverlapping(
            output_json.as_ptr(),
            out_metrics_json as *mut u8,
            output_json.len(),
        );
        *out_metrics_json.add(output_json.len()) = 0; // Null terminator
    }

    0 // Success
}

// Internal helper (not FFI-exposed)
fn apply_ema_and_calibration(
    feature: &BciFeatureEnvelopeV1,
    contract: &ConverterContract,
) -> Result<BciMetricsEnvelopeV1, ProcessingError> {
    // 1. Extract band powers / scalar features from feature.features[]
    // 2. Apply EMA per metric: m_t = alpha * f_t + (1-alpha) * m_{t-1}
    // 3. Apply calibration profile from contract.calibrationProfileId
    // 4. Clamp all bands to [0,1]; DET to [0,10]
    // 5. Populate transform block with method, alpha, profile ID
    // 6. Return validated BciMetricsEnvelopeV1
    unimplemented!()
}
