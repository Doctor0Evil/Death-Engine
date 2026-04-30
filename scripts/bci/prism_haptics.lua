-- target-repo: Death-Engine
-- file: scripts/bci/prism_haptics.lua

local ffi = require("ffi")
local json = require("dkjson")

ffi.cdef[[
  int32_t hpnrl_eval_haptics_prism(
    const char* inputs_json,
    char* outputs_json,
    size_t out_cap
  );
]]

local lib = ffi.load("libhpnrl_prisms")

-- Sample haptics prism outputs for routing to hardware
-- @param player_id: string
-- @param region_id: string
-- @return: table matching haptics-prism-v1 schema
local function sample(player_id, region_id)
  local inv = H.Invariants.getSlice(region_id) or {}
  local metrics = H.Metrics.getBands(player_id, region_id) or {}
  local summary = BCI.getSummary(player_id)
  
  local inputs = {
    invariants = inv,
    metrics = metrics,
    summary = summary
  }
  
  local inputs_json = json.encode(inputs)
  local out_cap = 2048
  local out_buf = ffi.new("char[?]", out_cap)
  
  local ret = lib.hpnrl_eval_haptics_prism(
    inputs_json,
    out_buf,
    out_cap
  )
  
  if ret ~= 0 then
    H.Log.warn("Haptics prism evaluation failed: code=" .. tostring(ret))
    return {
      schemaVersion = "1.0.0",
      timestamp = H.Time.now(),
      hapticDrive = 0.3,
      hapticRoutingBias = 0.0
    }
  end
  
  local outputs_json = ffi.string(out_buf)
  return json.decode(outputs_json)
end

return { sample = sample }
