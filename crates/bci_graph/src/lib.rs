// crates/bci_graph/src/lib.rs

use std::os::raw::{c_char, c_int};
use std::ffi::{CStr, CString};

/// High-level Rust entry point used internally. This does the actual work.
///
/// Arguments:
/// - tenant_profile_json: tenant-profile-v1 document as JSON string.
/// - probabilistic_edges_json: JSON array of hpc-graph-probabilistic-edge-v1 objects, or
///   an envelope pointing at a SQLite snapshot / table.
/// - query_json: JSON request with fields:
///     {
///       "tenantId": "...",
///       "snapshotId": 42,
///       "sourceNodeId": 10,
///       "targetFilter": { "zoneKind": "highSensitivity" } | { "nodeIds": [ ... ] },
///       "maxDepth": 6,
///       "maxPaths": 8
///     }
/// Returns:
///   JSON string with shape:
///     {
///       "ok": true,
///       "error": null,
///       "data": {
///         "tenantId": "...",
///         "snapshotId": 42,
///         "sourceNodeId": 10,
///         "maxDepthUsed": 5,
///         "pathsConsidered": 24,
///         "truncated": false,
///         "targets": [
///           { "nodeId": 101, "reachabilityProb": 0.18 },
///           { "nodeId": 205, "reachabilityProb": 0.25 }
///         ],
///         "aggregate": {
///           "targetKind": "highSensitivityZone",
///           "reachabilityProb": 0.31
///         }
///       }
///     }
pub fn compute_reachability_prob(
    tenant_profile_json: &str,
    probabilistic_edges_json: &str,
    query_json: &str,
) -> Result<String, String> {
    // Implementation sketch:
    // 1. Parse tenant-profile-v1 to get probReachability defaults (maxPaths, maxDepth, etc.).
    // 2. Parse probabilistic edge records or resolve them via snapshotId from SQLite.
    // 3. Parse query_json to get source node and target filter.
    // 4. Run a bounded search (e.g., recursive CTE or in-memory graph) that:
    //    - enumerates paths up to maxDepth,
    //    - accumulates log-success probabilities (sum of -log(successProb)),
    //    - keeps the best K paths per target,
    //    - approximates combined reachability using 1 - ∏(1 - p_path).
    // 5. Return the envelope described above.
    //
    // Here we only define the signature and JSON envelope; the full implementation
    // should live in an internal module and be thoroughly tested.
    let _ = tenant_profile_json;
    let _ = probabilistic_edges_json;
    let _ = query_json;

    Err("compute_reachability_prob not yet implemented".to_string())
}

/// C ABI wrapper suitable for calling from C++ or Lua FFI.
///
/// The caller passes three UTF-8, null-terminated JSON strings and a writable
/// output buffer. On success, the function writes a null-terminated JSON
/// response into out_buf and returns 0. On failure, it writes an error envelope
/// and returns a non-zero error code.
///
/// Signature:
///   int32_t hpc_compute_reachability_prob(
///       const char* tenant_profile_json,
///       const char* probabilistic_edges_json,
///       const char* query_json,
///       char* out_buf,
///       int out_cap);
#[no_mangle]
pub extern "C" fn hpc_compute_reachability_prob(
    tenant_profile_json: *const c_char,
    probabilistic_edges_json: *const c_char,
    query_json: *const c_char,
    out_buf: *mut c_char,
    out_cap: c_int,
) -> c_int {
    // Safety: assume caller provides valid pointers and capacity.
    let tenant_profile = unsafe {
        match CStr::from_ptr(tenant_profile_json).to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        }
    };
    let edges = unsafe {
        match CStr::from_ptr(probabilistic_edges_json).to_str() {
            Ok(s) => s,
            Err(_) => return -2,
        }
    };
    let query = unsafe {
        match CStr::from_ptr(query_json).to_str() {
            Ok(s) => s,
            Err(_) => return -3,
        }
    };

    let response_json = match compute_reachability_prob(tenant_profile, edges, query) {
        Ok(s) => s,
        Err(msg) => {
            // Minimal error envelope; callers should parse and surface details.
            let err = format!(
                "{{\"ok\":false,\"error\":{{\"code\":\"INTERNAL\",\"message\":\"{}\"}},\"data\":null}}",
                msg.replace('"', "\\\"")
            );
            err
        }
    };

    let c_str = match CString::new(response_json) {
        Ok(s) => s,
        Err(_) => return -4,
    };

    let bytes = c_str.as_bytes_with_nul();
    if bytes.len() as c_int > out_cap {
        return -5;
    }

    unsafe {
        std::ptr::copy_nonoverlapping(bytes.as_ptr(), out_buf as *mut u8, bytes.len());
    }

    0
}
