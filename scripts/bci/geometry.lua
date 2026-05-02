-- scripts/bci/geometry.lua
--
-- Runtime BCI geometry orchestration:
-- - binding cache per (player, region, tile)
-- - binding resolution via registry
-- - sampling via Rust geometry kernel
-- - debug peekBinding for overlays

local ok_ffi, ffi = pcall(require, "ffi")
local json = require("engine.json")

local BCI = require("scripts.bci")
local H = require("scripts.h") or {}
local Invariants = require("scripts.HInvariants")
local Metrics = require("scripts.HMetrics")
local Timing = require("scripts.HTiming")
local Contract = require("scripts.HContract") or require("scripts.HContract.init")
local BindingsRegistry = require("scripts.bci.geometryregistry")
local BCIDebug = require("scripts.hpcbcidebug")
local HKernels = require("scripts.HBciKernel")

local Geometry = {}

----------------------------------------------------------------------
-- Basic gating
----------------------------------------------------------------------

local function should_use_bci(summary)
    return summary
        and summary.signalQuality == "Good"
        and summary.stressScore ~= nil
end

----------------------------------------------------------------------
-- Binding cache
----------------------------------------------------------------------

local BindingCache = {}

local function make_cache_key(player_id, region_id, tile_id)
    return tostring(player_id) .. ":" .. tostring(region_id) .. ":" .. tostring(tile_id)
end

local function summarize_bands(summary)
    if not summary then
        return {
            stressBand = "Low",
            attentionBand = "Neutral",
            signalQuality = "Unavailable"
        }
    end

    return {
        stressBand = summary.stressBand,
        attentionBand = summary.attentionBand,
        signalQuality = summary.signalQuality
    }
end

local function summarize_invariants(inv)
    if not inv then
        return nil
    end

    return {
        cicBand = inv.cicBand,
        lsgBand = inv.lsgBand,
        detBand = inv.detBand
    }
end

local function summarize_csi(csi)
    if not csi then
        return nil
    end

    if csi < 0.4 then
        return "low"
    elseif csi < 0.7 then
        return "mid"
    else
        return "high"
    end
end

local function should_invalidate(entry, new_inv_bands, new_bci_bands, new_csi_bucket)
    if not entry then
        return true
    end

    local old_inv = entry.invBands or {}
    local old_bci = entry.bciBands or {}

    if old_inv.cicBand ~= new_inv_bands.cicBand
        or old_inv.lsgBand ~= new_inv_bands.lsgBand
        or old_inv.detBand ~= new_inv_bands.detBand then
        return true
    end

    if old_bci.stressBand ~= new_bci_bands.stressBand
        or old_bci.attentionBand ~= new_bci_bands.attentionBand
        or old_bci.signalQuality ~= new_bci_bands.signalQuality then
        return true
    end

    if entry.csiBucket ~= new_csi_bucket then
        return true
    end

    return false
end

local function store_cache_entry(key, binding, inv_bands, bci_bands, csi_bucket, caps)
    BindingCache[key] = {
        binding = binding,
        invBands = inv_bands,
        bciBands = bci_bands,
        csiBucket = csi_bucket,
        caps = caps
    }
end

----------------------------------------------------------------------
-- Binding scoring (kept from older BciGeometry.resolveBinding)
----------------------------------------------------------------------

local function score_binding(binding, ctx)
    local score = 0.0
    local reasons = {}

    if binding.priority then
        score = score + binding.priority * 10.0
        reasons[#reasons + 1] = "priority=" .. tostring(binding.priority)
    end

    if binding.tier == "standard" then
        score = score + 5.0
        reasons[#reasons + 1] = "tier=standard"
    elseif binding.tier == "mature" then
        score = score + 3.0
        reasons[#reasons + 1] = "tier=mature"
    elseif binding.tier == "lab" then
        score = score + 1.0
        reasons[#reasons + 1] = "tier=lab"
    end

    local spec = binding._specificity or 0
    score = score + spec
    reasons[#reasons + 1] = "specificity=" .. tostring(spec)

    if binding.bciFilter and ctx.summary and ctx.summary.stressScore then
        local min_v = binding.bciFilter.stressScoreMin or 0.0
        local max_v = binding.bciFilter.stressScoreMax or 1.0
        local mid = (min_v + max_v) * 0.5
        local d = math.abs(ctx.summary.stressScore - mid)
        local bonus = math.max(0.0, 1.0 - d)
        score = score + bonus
        reasons[#reasons + 1] = string.format("stressProximity=%.3f", bonus)
    end

    return score, reasons
end

----------------------------------------------------------------------
-- Safety caps extraction
----------------------------------------------------------------------

local function extract_caps_from_binding(binding)
    if not binding then
        return nil
    end

    local s = binding.safetyProfile
    if not s then
        return nil
    end

    return {
        maxCsi = s.maxCsi or (s.timingCaps and s.timingCaps.maxCsi) or nil,
        maxDet = s.maxDet or (s.timingCaps and s.timingCaps.maxDet) or nil
    }
end

----------------------------------------------------------------------
-- Binding resolution wrapper (via registry)
----------------------------------------------------------------------

local function resolve_binding(player_id, region_id, tile_id, summary, inv_slice, metrics_slice, csi, contract_ctx)
    local ctx = {
        playerId = player_id,
        regionId = region_id,
        tileId = tile_id,
        summary = summary,
        invariants = inv_slice,
        metrics = metrics_slice,
        csi = csi,
        contractCtx = contract_ctx
    }

    -- Registry is responsible for filter semantics and scoring; we keep
    -- the older score_binding here for compatibility if registry wants it.
    local binding, score, reasons = BindingsRegistry.resolve(ctx)
    if not binding then
        -- Fallback to local scoring if registry only returns a candidate list.
        local candidates = BindingsRegistry.getForRegion and BindingsRegistry.getForRegion(ctx.regionId) or {}
        local best, best_score, best_reasons = nil, -math.huge, nil

        for _, b in ipairs(candidates) do
            if BindingsRegistry.matches and BindingsRegistry.matches(b, ctx) then
                local s, r = score_binding(b, ctx)
                if s > best_score then
                    best, best_score, best_reasons = b, s, r
                end
            end
        end

        binding, score, reasons = best, best_score, best_reasons
    end

    BCIDebug.logBindingSelection(ctx, binding, score, reasons)
    return binding, score, reasons
end

----------------------------------------------------------------------
-- Call into Rust geometry kernel via JSON FFI (optional path)
----------------------------------------------------------------------

if ok_ffi then
    ffi.cdef([[
        typedef struct {
            float maskRadius;
            float maskOpacity;
            float vignetteStrength;
            float colorShift;
        } HpcBciVisualParams;

        typedef struct {
            float pressureLf;
            float whisperSend;
            float reverbDensity;
        } HpcBciAudioParams;

        typedef struct {
            float chestIntensity;
            float spineIntensity;
            float pulseRate;
            int   patternId;
        } HpcBciHapticParams;

        typedef struct {
            float maxCsi;
            float maxDet;
        } HpcBciCaps;

        typedef struct {
            HpcBciVisualParams visual;
            HpcBciAudioParams  audio;
            HpcBciHapticParams haptics;
            HpcBciCaps         caps;
        } HpcBciMappingOutputs;

        int32_t hpcbci_evaluate_mapping(
            const char *request_json,
            char *out_buf,
            size_t out_cap
        );
    ]])

    Geometry._lib = ffi.load("hpc_bci_geometry")
end

local function build_mapping_request(player_id, region_id, tile_id, summary, inv_slice, metrics_slice, csi, contract_ctx, binding)
    return {
        schemaVersion = "1.0.0",
        playerId = player_id,
        regionId = region_id,
        tileId = tile_id,
        summary = summary,
        invariants = inv_slice,
        metrics = metrics_slice,
        csi = csi,
        contract = contract_ctx,
        bindingId = binding and binding.bindingId or nil
    }
end

local function call_rust_mapping_kernel(request_tbl)
    if not Geometry._lib or not ok_ffi then
        return nil
    end

    local req_json = json.encode(request_tbl)
    local out_cap = 4096
    local out_buf = ffi.new("char[?]", out_cap)

    local rc = Geometry._lib.hpcbci_evaluate_mapping(req_json, out_buf, out_cap)
    if rc <= 0 then
        return nil
    end

    local out_str = ffi.string(out_buf, rc)
    local ok, decoded = pcall(json.decode, out_str)
    if not ok then
        return nil
    end

    return decoded
end

----------------------------------------------------------------------
-- Public API: sampling
----------------------------------------------------------------------

function Geometry.sample(player_id, region_id, tile_id)
    player_id = player_id or 1

    local summary = BCI.getSummary(player_id)
    if not should_use_bci(summary) then
        if HKernels.evaluateFallback then
            return HKernels.evaluateFallback(region_id, tile_id)
        end
        return nil
    end

    local inv_slice = Invariants.getRegionSlice(region_id, tile_id)
    local metrics_slice = Metrics.getSessionSlice(player_id)
    local csi = Timing.getCSI(player_id)
    local contract_ctx = Contract.getCurrentPolicy(player_id)

    local key = make_cache_key(player_id, region_id, tile_id)
    local entry = BindingCache[key]

    local inv_bands = summarize_invariants(inv_slice) or { cicBand = nil, lsgBand = nil, detBand = nil }
    local bci_bands = summarize_bands(summary)
    local csi_bucket = summarize_csi(csi)

    if should_invalidate(entry, inv_bands, bci_bands, csi_bucket) then
        local binding = nil
        local _score, _reasons = nil, nil

        binding, _score, _reasons = resolve_binding(
            player_id,
            region_id,
            tile_id,
            summary,
            inv_slice,
            metrics_slice,
            csi,
            contract_ctx
        )

        if not binding then
            if HKernels.evaluateFallback then
                return HKernels.evaluateFallback(region_id, tile_id)
            end
            return nil
        end

        local caps = extract_caps_from_binding(binding)
        store_cache_entry(key, binding, inv_bands, bci_bands, csi_bucket, caps)
        entry = BindingCache[key]
    end

    local binding = entry.binding

    -- Preferred path: direct struct-based FFI via HKernels.
    if HKernels.evaluateBinding then
        local request = {
            summary = summary,
            invariants = inv_slice,
            metrics = metrics_slice,
            csi = csi,
            contractCtx = contract_ctx,
            bindingId = binding.bindingId
        }

        local outputs = HKernels.evaluateBinding(binding, request)

        if outputs and H.Visual and H.Visual.applyBciMask and outputs.visual then
            H.Visual.applyBciMask(player_id, outputs.visual)
        end

        if outputs and H.Audio and H.Audio.applyBciRtpcs and outputs.audio then
            H.Audio.applyBciRtpcs(player_id, outputs.audio)
        end

        if outputs and H.Haptics and H.Haptics.routeHaptics and outputs.haptics then
            H.Haptics.routeHaptics(player_id, outputs.haptics)
        end

        return outputs
    end

    -- Fallback path: JSON FFI hpcbci_evaluate_mapping.
    local request_tbl = build_mapping_request(
        player_id,
        region_id,
        tile_id,
        summary,
        inv_slice,
        metrics_slice,
        csi,
        contract_ctx,
        binding
    )

    local outputs = call_rust_mapping_kernel(request_tbl)
    if not outputs then
        if HKernels.evaluateFallback then
            return HKernels.evaluateFallback(region_id, tile_id)
        end
        return nil
    end

    if H.Visual and H.Visual.applyBciMask and outputs.visual then
        H.Visual.applyBciMask(player_id, outputs.visual)
    end

    if H.Audio and H.Audio.applyBciRtpcs and outputs.audio then
        H.Audio.applyBciRtpcs(player_id, outputs.audio)
    end

    if H.Haptics and H.Haptics.routeHaptics and outputs.haptics then
        H.Haptics.routeHaptics(player_id, outputs.haptics)
    end

    return outputs
end

----------------------------------------------------------------------
-- Public API: debug / cache control
----------------------------------------------------------------------

function Geometry.peekBinding(player_id, region_id, tile_id)
    local key = make_cache_key(player_id, region_id, tile_id)
    local entry = BindingCache[key]

    if not entry or not entry.binding then
        return nil
    end

    local binding = entry.binding
    local caps = entry.caps or extract_caps_from_binding(binding)

    return {
        bindingId = binding.bindingId,
        tier = binding.tier,
        regionClass = binding.regionClass,
        cached = true,
        caps = caps
    }
end

function Geometry.clearCache()
    BindingCache = {}
end

function Geometry.clearCacheForPlayer(player_id)
    local prefix = tostring(player_id) .. ":"
    for key, _ in pairs(BindingCache) do
        if key:sub(1, #prefix) == prefix then
            BindingCache[key] = nil
        end
    end
end

return Geometry
