-- scripts/hpc_blast_prob.lua
--
-- Runtime adapter for probabilistic reachability queries.
-- Bridges Lua H.Blast.* calls to the Rust FFI function
--   hpc_compute_reachability_prob(...)
-- which operates on JSON envelopes.

local json = require("json")          -- Engine JSON module (must provide encode/decode)
local ffi  = require("ffi")           -- LuaJIT FFI or engine-provided equivalent

local H    = H or {}
H.Blast    = H.Blast or {}

ffi.cdef[[
    int32_t hpc_compute_reachability_prob(
        const char* tenant_profile_json,
        const char* probabilistic_edges_json,
        const char* query_json,
        char* out_buf,
        int out_cap
    );
]]

-- Adjust the library name/path to match your build (e.g., "libdeath_engine.so").
local lib = ffi.load("death_engine")

-- Internal helper: safe JSON encode that always returns string or nil,err.
local function encode_json(value)
    local ok, result = pcall(json.encode, value)
    if not ok then
        return nil, "json_encode_error: " .. tostring(result)
    end
    return result, nil
end

-- Internal helper: safe JSON decode that always returns table or nil,err.
local function decode_json(text)
    local ok, result = pcall(json.decode, text)
    if not ok then
        return nil, "json_decode_error: " .. tostring(result)
    end
    return result, nil
end

-- High-level entry point:
--   H.Blast.computeReachabilityProb(tenantProfile, query, edges)
--
-- Arguments:
--   tenantProfile : table  -- tenant-profile-v1 JSON shape as Lua table.
--   query         : table  -- query envelope:
--       {
--         tenantId     = "...",
--         snapshotId   = 42,
--         sourceNodeId = 10,
--         targetFilter = { zoneKind = "highSensitivity" } or { nodeIds = { ... } },
--         maxDepth     = 6,      -- optional, overrides tenant defaults
--         maxPaths     = 8       -- optional, overrides tenant defaults
--       }
--   edges         : table|nil -- either:
--       * an array of probabilistic edge rows (hpc-graph-probabilistic-edge-v1),
--       * or an envelope like { snapshotId = 42, tenantId = "...", kind = "sqlite" }
--
-- Returns:
--   ok    : boolean
--   data  : table|nil  -- on success, structured response from Rust kernel
--   error : table|nil  -- on failure, { code = "...", message = "...", detail = ... }
function H.Blast.computeReachabilityProb(tenantProfile, query, edges)
    if tenantProfile == nil or type(tenantProfile) ~= "table" then
        return false, nil, {
            code    = "INVALID_INPUT",
            message = "tenantProfile must be a table"
        }
    end
    if query == nil or type(query) ~= "table" then
        return false, nil, {
            code    = "INVALID_INPUT",
            message = "query must be a table"
        }
    end

    -- Allow edges to be nil for the SQLite-backed mode; Rust will resolve via snapshotId.
    edges = edges or { kind = "sqlite" }

    local tenant_json, err1 = encode_json(tenantProfile)
    if not tenant_json then
        return false, nil, {
            code    = "ENCODE_ERROR",
            message = "Failed to encode tenantProfile JSON",
            detail  = err1
        }
    end

    local edges_json, err2 = encode_json(edges)
    if not edges_json then
        return false, nil, {
            code    = "ENCODE_ERROR",
            message = "Failed to encode edges JSON",
            detail  = err2
        }
    end

    local query_json, err3 = encode_json(query)
    if not query_json then
        return false, nil, {
            code    = "ENCODE_ERROR",
            message = "Failed to encode query JSON",
            detail  = err3
        }
    end

    -- Prepare C strings.
    local tenant_c = ffi.new("char[?]", #tenant_json + 1)
    ffi.copy(tenant_c, tenant_json)

    local edges_c = ffi.new("char[?]", #edges_json + 1)
    ffi.copy(edges_c, edges_json)

    local query_c = ffi.new("char[?]", #query_json + 1)
    ffi.copy(query_c, query_json)

    -- Output buffer (size tuned for typical payloads; can be made configurable).
    local OUT_CAP = 64 * 1024
    local out_buf = ffi.new("char[?]", OUT_CAP)

    local rc = lib.hpc_compute_reachability_prob(
        tenant_c,
        edges_c,
        query_c,
        out_buf,
        OUT_CAP
    )

    if rc ~= 0 then
        return false, nil, {
            code    = "FFI_ERROR",
            message = "hpc_compute_reachability_prob returned non-zero",
            detail  = rc
        }
    end

    -- Read null-terminated string from out_buf.
    local resp_str = ffi.string(out_buf)
    local resp, err4 = decode_json(resp_str)
    if not resp then
        return false, nil, {
            code    = "DECODE_ERROR",
            message = "Failed to decode reachability response JSON",
            detail  = err4
        }
    end

    -- Normalize into ok/data/error envelope.
    if resp.ok == true then
        return true, resp.data, nil
    else
        return false, nil, resp.error or {
            code    = "UNKNOWN_ERROR",
            message = "Kernel returned ok=false without error payload"
        }
    end
end

return H
