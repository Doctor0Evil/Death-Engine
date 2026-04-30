-- target-repo: Death-Engine
-- file: scripts/bci/prism_pacing.lua

local ffi = require("ffi")
local json = require("dkjson")

-- C ABI for pacing prism kernel (defined in crates/hpnrl_prisms)
ffi.cdef[[
  int32_t hpnrl_eval_horror_pacing(
    const char* inputs_json,
    const char* state_json,
    char* outputs_json,
    size_t out_cap
  );
]]

local lib = ffi.load("libhpnrl_prisms")

-- Sample pacing prism outputs for a player
-- @param player_id: string
-- @param region_id: string (optional, for context)
-- @return: table matching horror-pacing-prism-v1 schema
local function sample(player_id, region_id)
  -- Assemble inputs from engine state
  local inv = H.Invariants.getSlice(region_id) or {}
  local metrics = H.Metrics.getBands(player_id, region_id) or {}
  local summary = BCI.getSummary(player_id)
  local csi = H.Timing.getCSI(player_id)
  
  local inputs = {
    invariants = inv,
    metrics = metrics,
    summary = summary,
    csi = csi
  }
  
  -- Get/update pacing state (novelty budget, etc.)
  local state = PacingState.get(player_id) or {
    novelty_budget = 1.0,
    last_pressure = 0.0
  }
  
  -- Encode to JSON
  local inputs_json = json.encode(inputs)
  local state_json = json.encode(state)
  
  -- Prepare output buffer
  local out_cap = 4096
  local out_buf = ffi.new("char[?]", out_cap)
  
  -- Call Rust prism kernel
  local ret = lib.hpnrl_eval_horror_pacing(
    inputs_json,
    state_json,
    out_buf,
    out_cap
  )
  
  if ret ~= 0 then
    H.Log.warn("Pacing prism evaluation failed: code=" .. tostring(ret))
    -- Return safe defaults
    return {
      schemaVersion = "1.0.0",
      timestamp = H.Time.now(),
      pressure = 0.5,
      noveltyBudget = state.novelty_budget,
      escalationGate = 0.5
    }
  end
  
  -- Decode and return
  local outputs_json = ffi.string(out_buf)
  local outputs = json.decode(outputs_json)
  
  -- Update state for next tick (novelty budget decay/recharge)
  PacingState.update(player_id, outputs.noveltyBudget, outputs.pressure)
  
  return outputs
end

-- Module export
return {
  sample = sample
}
