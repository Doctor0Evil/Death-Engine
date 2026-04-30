-- target-repo: Death-Engine
-- file: scripts/bci/prism_visual.lua

local ffi = require("ffi")
local json = require("dkjson")

ffi.cdef[[
  int32_t hpnrl_eval_visual_prism(
    const char* inputs_json,
    char* outputs_json,
    size_t out_cap
  );
]]

local lib = ffi.load("libhpnrl_prisms")

-- Sample visual prism outputs for DeadLantern/VFX systems
-- @param player_id: string
-- @param region_id: string
-- @return: table matching visual-prism-v1 schema
local function sample(player_id, region_id)
  local inv = H.Invariants.getSlice(region_id) or {}
  local summary = BCI.getSummary(player_id)
  
  local inputs = {
    invariants = inv,
    summary = summary
    -- metrics not needed for visual prism per design
  }
  
  local inputs_json = json.encode(inputs)
  local out_cap = 2048
  local out_buf = ffi.new("char[?]", out_cap)
  
  local ret = lib.hpnrl_eval_visual_prism(
    inputs_json,
    out_buf,
    out_cap
  )
  
  if ret ~= 0 then
    H.Log.warn("Visual prism evaluation failed: code=" .. tostring(ret))
    return {
      schemaVersion = "1.0.0",
      timestamp = H.Time.now(),
      visualPressure = 0.5,
      visualCap = 0.5,
      visualInstability = 0.0
    }
  end
  
  local outputs_json = ffi.string(out_buf)
  return json.decode(outputs_json)
end

return { sample = sample }
