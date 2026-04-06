-- scripts/hpc_bci_adapter.lua
--
-- Public API for BCI → entertainment metrics adaptation in Death-Engine.
-- This module orchestrates:
--   - Validation of incoming BCI feature envelopes (already schema-checked upstream).
--   - FFI calls into the Rust library (libhpc_bci_ema).
--   - ContractCard-based clamping using the active policy/region/seed contract context.
--
-- NOTE: This stub defines structure and signatures only; it does not implement
-- any numerical mapping logic. That logic lives in the Rust crate.

local hpc_bci_adapter = {}

-- FFI binding (via LuaJIT FFI or a similar bridge).
-- In your actual engine, replace this with the correct FFI loader.
local ffi_ok, ffi = pcall(require, "ffi")
local rust = nil

if ffi_ok then
    ffi.cdef[[
        // FFI signature for the Rust processing function.
        // It receives:
        //   - feature_env_json: UTF-8 JSON string for bci-feature-envelope-v1
        //   - contract_ctx_json: UTF-8 JSON string capturing the active contract context
        //   - out_buf: caller-allocated buffer for the metrics envelope JSON
        //   - out_cap: capacity of out_buf in bytes
        //
        // It returns:
        //   - >= 0: number of bytes written into out_buf (excluding terminating 0)
        //   - <  0: error code
        int hpc_bci_process(
            const char* feature_env_json,
            const char* contract_ctx_json,
            char* out_buf,
            int out_cap
        );
    ]]

    -- Replace "libhpc_bci_ema" with the actual shared library name per platform.
    local ok_lib, lib = pcall(ffi.load, "hpc_bci_ema")
    if ok_lib then
        rust = lib
    end
end

--- Serialize a Lua table to JSON.
-- In production, this should delegate to your engine's JSON library.
local function encode_json(tbl)
    -- Stub: replace with a proper JSON encoder (e.g., cjson or engine builtin).
    error("encode_json not implemented in hpc_bci_adapter.lua stub")
end

--- Parse a JSON string into a Lua table.
-- In production, this should delegate to your engine's JSON library.
local function decode_json(json_str)
    -- Stub: replace with a proper JSON decoder.
    error("decode_json not implemented in hpc_bci_adapter.lua stub")
end

--- Apply contract-card enforcement to a metrics envelope.
-- This function is responsible for clamping or rejecting metrics updates
-- that fall outside the active policy/region/seed contract ranges.
--
-- @param metrics_env Lua table representing bci-metrics-envelope-v1.
-- @param contract_ctx Lua table capturing policyEnvelope, regionContractCard, seedContractCard.
-- @return Lua table representing the clamped metrics envelope.
local function enforce_contract_caps(metrics_env, contract_ctx)
    -- Stub: no-op pass-through for now.
    -- In future work, implement:
    --   - Look up allowed bands for UEC, EMD, STCI, CDL, ARR from contract_ctx.
    --   - Clamp metrics_env values into those bands.
    --   - Optionally mark metrics_env with flags if clamping occurred.
    return metrics_env
end

--- Public API: process a BCI feature envelope under a given contract context.
--
-- @param feature_env Lua table representing a validated bci-feature-envelope-v1.
-- @param contract_ctx Lua table with the active policyEnvelope / regionContractCard / seedContractCard.
-- @return Lua table representing a validated, contract-clamped bci-metrics-envelope-v1.
function hpc_bci_adapter.process_feature_envelope(feature_env, contract_ctx)
    if not rust then
        error("hpc_bci_adapter: Rust library libhpc_bci_ema not loaded")
    end

    -- Encode inputs to JSON for the Rust FFI.
    local feature_json = encode_json(feature_env)
    local contract_json = encode_json(contract_ctx)

    local feature_c = ffi.new("const char[?]", #feature_json + 1, feature_json)
    local contract_c = ffi.new("const char[?]", #contract_json + 1, contract_json)

    local out_cap = 16384  -- adjust as needed
    local out_buf = ffi.new("char[?]", out_cap)

    local written = rust.hpc_bci_process(feature_c, contract_c, out_buf, out_cap)
    if written < 0 then
        error("hpc_bci_adapter: hpc_bci_process returned error code " .. tostring(written))
    end

    local metrics_json = ffi.string(out_buf, written)
    local metrics_env = decode_json(metrics_json)

    -- Apply contract-card enforcement in Lua (in addition to Rust-side caps).
    local clamped_metrics = enforce_contract_caps(metrics_env, contract_ctx)

    return clamped_metrics
end

return hpc_bci_adapter
