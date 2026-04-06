// crates/bci_ema_smoothing/src/lib.rs
//
// FFI skeleton for BCI feature → metrics processing.
// This exposes a single C ABI function `hpc_bci_process` that Lua or other
// engine layers can call via FFI. It is intentionally free of business logic;
// future work will add:
//   - JSON parsing of bci-feature-envelope-v1
//   - contract-card context parsing and cap enforcement
//   - EMA smoothing and calibration
//   - construction of bci-metrics-envelope-v1

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};

/// C ABI entrypoint for BCI processing.
///
/// # Safety
/// All pointers must be valid and point to NUL-terminated UTF-8 strings.
/// `out_buf` must be valid for writes up to `out_cap` bytes.
#[no_mangle]
pub unsafe extern "C" fn hpc_bci_process(
    feature_env_json: *const c_char,
    contract_ctx_json: *const c_char,
    out_buf: *mut c_char,
    out_cap: c_int,
) -> c_int {
    // Basic parameter validation.
    if feature_env_json.is_null() || contract_ctx_json.is_null() || out_buf.is_null() {
        return -1; // invalid pointers
    }
    if out_cap <= 0 {
        return -2; // invalid buffer capacity
    }

    // Convert input C strings to Rust &str.
    let feature_str = match CStr::from_ptr(feature_env_json).to_str() {
        Ok(s) => s,
        Err(_) => return -3, // invalid UTF-8 in feature_env_json
    };

    let contract_str = match CStr::from_ptr(contract_ctx_json).to_str() {
        Ok(s) => s,
        Err(_) => return -4, // invalid UTF-8 in contract_ctx_json
    };

    // TODO: Parse feature_str as bci-feature-envelope-v1 JSON.
    // TODO: Parse contract_str as contract context JSON.
    // TODO: Apply EMA smoothing, calibration, and contract caps.
    // TODO: Construct bci-metrics-envelope-v1 JSON.

    // For now, echo a minimal placeholder metrics envelope.
    let placeholder = format!(
        r#"{{
  "schemaVersion": "bci-metrics-envelope-v1",
  "sourceEnvelope": "placeholder",
  "metrics": {{
    "UEC": 0.0,
    "EMD": 0.0,
    "STCI": 0.0,
    "CDL": 0.0,
    "ARR": 0.0
  }},
  "debug": {{
    "feature_len": {},
    "contract_len": {}
  }}
}}"#,
        feature_str.len(),
        contract_str.len()
    );

    let cstring = match CString::new(placeholder) {
        Ok(s) => s,
        Err(_) => return -5, // internal NUL in placeholder
    };

    let bytes = cstring.as_bytes();
    if bytes.len() >= out_cap as usize {
        return -6; // output buffer too small
    }

    std::ptr::copy_nonoverlapping(
        bytes.as_ptr() as *const c_char,
        out_buf,
        bytes.len(),
    );
    // Add terminating NUL.
    *out_buf.add(bytes.len()) = 0;

    bytes.len() as c_int
}
