-- target-repo: Death-Engine
-- file: scripts/bci/geometry.lua
-- DO NOT implement math here; all mapping stays in Rust

local ffi = require("ffi")
local json = require("dkjson")

-- C ABI for geometry kernel (defined in crates/bci_geometry)
ffi.cdef[[
  // Simplified; actual signature uses POD structs for request/response
  int32_t hpcbci_evaluate_mapping(
    const char* request_json,
    char* response_json,
    size_t response_cap
  );
]]

local lib = ffi.load("libhpc_bci_geometry")

-- Sample BCI geometry outputs for a player at a location
-- @param player_id: string
-- @param region_id: string
-- @param tile_id: string
-- @return: BciMappingOutputs table { visual=..., audio=..., haptics=... }
local function sample(player_id, region_id, tile_id)
  -- Assemble context from engine state
  local summary = BCI.getSummary(player_id)  -- bci-summary-v1
  local invariants = H.Invariants.getSlice(region_id, tile_id)
  local metrics = H.Metrics.getBands(player_id, region_id)
  local csi = H.Timing.getCSI(player_id)
  local contract = H.Contract.getCurrentPolicy(player_id)
  
  -- Build request object (matches BciMappingRequest Rust struct)
  local request = {
    player_id = player_id,
    region_id = region_id,
    tile_id = tile_id,
    summary = summary,
    invariants = invariants,
    metrics = metrics,
    csi = csi,
    contract_ctx = contract
  }
  
  -- Encode request to JSON
  local request_json = json.encode(request)
  
  -- Prepare response buffer
  local response_cap = 131072  -- 128KB for outputs + telemetry
  local response_buf = ffi.new("char[?]", response_cap)
  
  -- Call Rust kernel
  local ret = lib.hpcbci_evaluate_mapping(
    request_json,
    response_buf,
    response_cap
  )
  
  if ret ~= 0 then
    H.Log.error("Geometry evaluation failed: code=" .. tostring(ret))
    -- Fallback to non-BCI defaults
    return H.Visual.defaultMask(), H.Audio.defaultRtpcs(), H.Haptics.defaultPattern()
  end
  
  -- Decode response
  local response_json = ffi.string(response_buf)
  local response = json.decode(response_json)
  
  -- Extract outputs
  local outputs = response.outputs  -- BciMappingOutputs
  
  -- Route to engine systems via helpers (defined in H.Visual, H.Audio, H.Haptics)
  H.Visual.applyBciMask(player_id, outputs.visual)
  H.Audio.applyBciRtpcs(player_id, outputs.audio)
  H.Haptics.routeHaptics(player_id, outputs.haptics)
  
  -- Optional: log telemetry for Neural-Resonance-Lab analysis
  if H.Config.log_bci_telemetry then
    BCIDebug.logMappingActivation(player_id, region_id, tile_id, response)
  end
  
  return outputs
end

-- Module export
return {
  sample = sample
}
