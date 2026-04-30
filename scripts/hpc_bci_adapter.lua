-- target-repo: Death-Engine
-- file: scripts/hpc_bci_adapter.lua
-- DO NOT add numerics here; only orchestration and contract cap enforcement.

local hpc_bci_adapter = {}

local ffi = require("ffi")
local json = require("dkjson")

ffi.cdef[[
  int32_t hpc_bci_process(
    const char* feature_json,
    const char* contract_json,
    char* out_metrics_json,
    size_t out_cap
  );
]]

local ok_lib, lib = pcall(ffi.load, "hpc_bci_ema_smoothing")
if not ok_lib then
  error("hpc_bci_adapter: failed to load Rust library 'hpc_bci_ema_smoothing'")
end

local function encode_json(tbl)
  local encoded, pos, err = json.encode(tbl)
  if not encoded then
    error("hpc_bci_adapter: JSON encode failed: " .. tostring(err))
  end
  return encoded
end

local function decode_json(str)
  local decoded, pos, err = json.decode(str)
  if not decoded then
    error("hpc_bci_adapter: JSON decode failed: " .. tostring(err))
  end
  return decoded
end

local function enforce_contract_caps(metrics_env, contract_ctx)
  if not MetricsState or not MetricsState.clamp_to_contract then
    return metrics_env
  end
  return MetricsState.clamp_to_contract(metrics_env, contract_ctx)
end

--- Process a single feature envelope through the Rust kernel and apply contract caps.
-- @param feature_env Lua table matching bci-feature-envelope-v1 (already schema-validated upstream).
-- @param contract_ctx Lua table containing policyEnvelope, regionContractCard, seedContractCard.
-- @return Lua table matching bci-metrics-envelope-v1, or nil on error (caller must handle fallback).
function hpc_bci_adapter.process_feature_envelope(feature_env, contract_ctx)
  if not feature_env or type(feature_env) ~= "table" then
    error("hpc_bci_adapter.process_feature_envelope: feature_env must be a table")
  end
  if not contract_ctx or type(contract_ctx) ~= "table" then
    error("hpc_bci_adapter.process_feature_envelope: contract_ctx must be a table")
  end

  local feature_json = encode_json(feature_env)
  local contract_json = encode_json(contract_ctx)

  local out_cap = 65536
  local out_buf = ffi.new("char[?]", out_cap)

  local ret = lib.hpc_bci_process(
    feature_json,
    contract_json,
    out_buf,
    out_cap
  )

  if ret ~= 0 then
    if H and H.Log and H.Log.error then
      H.Log.error("BCI processing failed in hpc_bci_process; code=" .. tostring(ret))
    end
    return nil
  end

  local metrics_json = ffi.string(out_buf)
  local metrics_env = decode_json(metrics_json)

  if H and H.Config and H.Config.debug and H.Schema and H.Schema.validate then
    local valid, err = H.Schema.validate(metrics_env, "bci-metrics-envelope-v1")
    if not valid and H.Log and H.Log.warn then
      H.Log.warn("BCI metrics envelope schema violation: " .. tostring(err))
    end
  end

  local clamped_metrics = enforce_contract_caps(metrics_env, contract_ctx)
  return clamped_metrics
end

return hpc_bci_adapter
