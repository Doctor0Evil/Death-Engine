-- scripts/hpc_blast_prob_tool.lua
--
-- Tool-facing wrapper for probabilistic reachability queries.

local json = require("json")
local H    = require("hpc_blast_prob")  -- ensures H.Blast.computeReachabilityProb is loaded

local M = {}

-- Envelope:
-- {
--   tenantProfile = { ... },   -- tenant-profile-v1
--   query         = { ... },   -- see H.Blast.computeReachabilityProb
--   edges         = { ... }    -- optional, may be an array or sqlite envelope
-- }
--
-- Returns JSON string:
--   {
--     "ok": true,
--     "error": null,
--     "data": {
--       "tenantId": "...",
--       "snapshotId": 42,
--       "sourceNodeId": 10,
--       "maxDepthUsed": 5,
--       "pathsConsidered": 24,
--       "truncated": false,
--       "targets": [
--         { "nodeId": 101, "reachabilityProb": 0.18 },
--         { "nodeId": 205, "reachabilityProb": 0.25 }
--       ],
--       "aggregate": {
--         "targetKind": "highSensitivityZone",
--         "reachabilityProb": 0.31
--       }
--     }
--   }
function M.run(envelope_json)
    local ok, envelope = pcall(json.decode, envelope_json)
    if not ok or type(envelope) ~= "table" then
        return json.encode({
            ok    = false,
            error = {
                code    = "INVALID_INPUT",
                message = "Failed to decode request envelope"
            },
            data  = nil
        })
    end

    local tenantProfile = envelope.tenantProfile
    local query         = envelope.query
    local edges         = envelope.edges

    local rok, data, err = H.Blast.computeReachabilityProb(
        tenantProfile,
        query,
        edges
    )

    if not rok then
        return json.encode({
            ok    = false,
            error = err or {
                code    = "UNKNOWN_ERROR",
                message = "computeReachabilityProb failed"
            },
            data  = nil
        })
    end

    return json.encode({
        ok    = true,
        error = nil,
        data  = data
    })
end

return M
