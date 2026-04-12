-- File: scripts/mapf_bci_geometry.lua
--
-- Runtime adapter for bci-geometry-tileset-v1 contracts.
-- Provides MapF.selectTileProfile(regionId, now, context) -> profileId
-- where context bundles invariants, BCI state, and Dead-Ledger decision tokens.

local MapF = {}
local Tilesets = {}

-- Injected dependencies (engine must bind these).
local H = H          -- invariants API: H.getBands(regionId) -> table with CIC, DET, LSG, etc.
local BCI = BCI      -- BCI API: BCI.getIntensityMode(), BCI.getFearIndex(), BCI.getOverloadFlag()
local Policy = Policy -- Dead-Ledger: Policy.DeadLedger.getDecisionToken(sessionId) -> token

-- Utility: band fearIndex into LOW/MID/HIGH.
local function band_fear_index(fear_index)
    if fear_index == nil then
        return nil
    end
    if fear_index < 0.33 then
        return "LOW"
    elseif fear_index < 0.66 then
        return "MID"
    else
        return "HIGH"
    end
end

-- Utility: check if value is within [min, max] band.
local function in_band(v, band)
    if not band or v == nil then
        return true
    end
    local minv = band.min
    local maxv = band.max
    if minv and v < minv then
        return false
    end
    if maxv and v > maxv then
        return false
    end
    return true
end

-- Utility: simple glob-like pattern match for regionIdPattern.
local function region_matches(pattern, region_id)
    if not pattern or pattern == "" then
        return true
    end
    -- Replace "*" with ".*" for a crude glob; engine can swap for a better matcher later.
    local lua_pattern = "^" .. pattern:gsub("([%%%^%$%(%)%%.%[%]%+%-%?])", "%%%1"):gsub("%*", ".*") .. "$"
    return string.match(region_id, lua_pattern) ~= nil
end

-- Public: load a tileset JSON-decoded table for this session/run.
function MapF.registerTileset(tileset)
    if not tileset or not tileset.tilesetId then
        error("MapF.registerTileset: tileset missing tilesetId")
    end
    Tilesets[tileset.tilesetId] = tileset
end

-- Internal: return iterator over all geometryProfiles in all registered tilesets.
local function iter_profiles()
    return coroutine.wrap(function()
        for _, ts in pairs(Tilesets) do
            local profiles = ts.geometryProfiles or {}
            for _, p in ipairs(profiles) do
                coroutine.yield(ts, p)
            end
        end
    end)
end

-- Core selection function.
-- context:
--   sessionId : string
--   tilesetFilter : optional tilesetId to constrain search
--   decisionToken : optional pre-fetched Dead-Ledger token
function MapF.selectTileProfile(regionId, now, context)
    if not regionId then
        error("MapF.selectTileProfile: regionId required")
    end
    context = context or {}

    local mode = BCI.getIntensityMode()
    local fear_index = BCI.getFearIndex()
    local fear_band = band_fear_index(fear_index)
    local overload = BCI.getOverloadFlag()

    local inv_bands = H.getBands(regionId) or {}
    local session_id = context.sessionId
    local decision_token = context.decisionToken

    if not decision_token and Policy and Policy.DeadLedger and session_id then
        decision_token = Policy.DeadLedger.getDecisionToken(session_id)
    end

    local allowed_tiers
    local allowed_profiles_caps = {}

    if decision_token then
        allowed_tiers = decision_token.allowedTiers
        allowed_profiles_caps = decision_token.tilesetCaps or {}
    end

    local best_profile_id = nil
    local best_score = -1.0

    for ts, profile in iter_profiles() do
        if context.tilesetFilter and ts.tilesetId ~= context.tilesetFilter then
            goto continue
        end

        local applies = profile.appliesTo or {}
        local tier = applies.tier
        local profile_mode = applies.mode
        local profile_fear = applies.fearBand
        local region_pattern = applies.regionIdPattern

        if profile_mode ~= mode then
            goto continue
        end

        if profile_fear and fear_band and profile_fear ~= fear_band then
            goto continue
        end

        if not region_matches(region_pattern, regionId) then
            goto continue
        end

        if allowed_tiers and tier then
            local tier_allowed = false
            for _, t in ipairs(allowed_tiers) do
                if t == tier then
                    tier_allowed = true
                    break
                end
            end
            if not tier_allowed then
                goto continue
            end
        end

        local caps = allowed_profiles_caps[profile.profileId]
        if caps and caps.forbidden then
            goto continue
        end

        local det_caps = profile.detCaps or {}
        local det_max = det_caps.DETMax
        local inv_det = inv_bands.DET

        if overload and det_max then
            if inv_det and inv_det > det_max then
                goto continue
            end
        end

        local invariants = profile.invariants or {}
        for key, band in pairs(invariants) do
            local v = inv_bands[key]
            if not in_band(v, band) then
                goto continue
            end
        end

        local score = 0.0
        if profile.metrics and profile.metrics.UEC then
            local uec_band = profile.metrics.UEC
            local uec = inv_bands.UEC
            if uec and uec_band then
                if in_band(uec, uec_band) then
                    score = score + 1.0
                end
            end
        end

        if overload and det_max then
            score = score - 0.5
        end

        if score > best_score then
            best_score = score
            best_profile_id = profile.profileId
        end

        ::continue::
    end

    return best_profile_id
end

return MapF
