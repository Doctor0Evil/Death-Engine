-- scripts/bci/geometry.lua
--
-- Summary-driven horror geometry binding:
--  - Resolves bci-geometry-binding-v1 objects against BciSummary + invariants + metrics.
--  - Maintains a per-player binding cache keyed by (regionId,tileId).
--  - Exposes BciGeometry.sample(...) as the canonical entrypoint.
--  - Exposes BciGeometry.peekBinding(...) for debug overlays.
--  - All mapping math stays in Rust; Lua only selects bindings and marshals data.

local ok_ffi, ffi = pcall(require, "ffi")
local json = require("engine.json")

local BCI = require("scripts.bci")
local H = require("scripts.h") or {}
local Invariants = require("scripts.HInvariants")
local Metrics = require("scripts.HMetrics")
local Timing = require("scripts.HTiming")
local Contract = require("scripts.HContract") or require("scripts.HContract.init")
local BCIDebug = require("scripts.hpc_bci_debug")

local Geometry = {}

----------------------------------------------------------------------
-- FFI to Rust geometry kernel
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

----------------------------------------------------------------------
-- Binding registry loading
----------------------------------------------------------------------

local bindings_registry = {
    by_region = {},
    all = {},
}

local function load_bindings_from_file(path)
    local fh = io.open(path, "r")
    if not fh then
        return {}
    end

    local content = fh:read("*a")
    fh:close()

    local ok, arr = pcall(json.decode, content)
    if not ok or type(arr) ~= "table" then
        return {}
    end

    return arr
end

local function index_bindings(bindings)
    bindings_registry.by_region = {}
    bindings_registry.all = bindings or {}

    for _, binding in ipairs(bindings_registry.all) do
        local region_class = binding.regionClass or "any"
        local bucket = bindings_registry.by_region[region_class]
        if not bucket then
            bucket = {}
            bindings_registry.by_region[region_class] = bucket
        end
        table.insert(bucket, binding)
    end
end

function Geometry.loadBindings(path)
    local bindings = load_bindings_from_file(path)
    index_bindings(bindings)
end

----------------------------------------------------------------------
-- Binding cache (per-player, per-region/tile)
----------------------------------------------------------------------

local BindingCache = {}

local function make_cache_key(region_id, tile_id)
    return tostring(region_id) .. "::" .. tostring(tile_id)
end

local function compute_bands_from_summary(summary)
    return {
        stressBand = summary.stressBand,
        attentionBand = summary.attentionBand,
        signalQuality = summary.signalQuality,
        visualOverloadIndex = summary.visualOverloadIndex or 0.0,
    }
end

local function compute_csi_bucket(csi)
    if csi == nil then
        return "none"
    end
    if csi < 0.4 then
        return "low"
    elseif csi < 0.7 then
        return "medium"
    else
        return "high"
    end
end

local function invariants_band_signature(inv)
    local cic = inv.cicBand or inv.cic or 0.0
    local aos = inv.aosBand or inv.aos or 0.0
    local lsg = inv.lsgBand or inv.lsg or 0.0
    local det = inv.detBand or inv.det or 0.0
    return string.format("c%.2f-a%.2f-l%.2f-d%.2f", cic, aos, lsg, det)
end

local function should_invalidate(entry, new_inv_sig, new_summary_bands, new_csi_bucket)
    if not entry then
        return true
    end

    if entry.inv_sig ~= new_inv_sig then
        return true
    end

    if entry.csi_bucket ~= new_csi_bucket then
        return true
    end

    if entry.summary_bands.stressBand ~= new_summary_bands.stressBand then
        return true
    end

    if entry.summary_bands.attentionBand ~= new_summary_bands.attentionBand then
        return true
    end

    if entry.summary_bands.signalQuality ~= new_summary_bands.signalQuality then
        return true
    end

    return false
end

local function get_cache_entry(player_id, region_id, tile_id)
    local player_cache = BindingCache[player_id]
    if not player_cache then
        player_cache = {}
        BindingCache[player_id] = player_cache
    end

    local key = make_cache_key(region_id, tile_id)
    return player_cache[key], player_cache, key
end

local function set_cache_entry(player_cache, key, binding, inv_sig, summary_bands, csi_bucket)
    player_cache[key] = {
        binding = binding,
        inv_sig = inv_sig,
        summary_bands = summary_bands,
        csi_bucket = csi_bucket,
    }
end

----------------------------------------------------------------------
-- Filter helpers
----------------------------------------------------------------------

local function matches_invariant_filter(binding, inv)
    local f = binding.invariantFilter
    if not f then
        return true
    end

    if f.cicMin and inv.cic and inv.cic < f.cicMin then
        return false
    end
    if f.cicMax and inv.cic and inv.cic > f.cicMax then
        return false
    end

    if f.detMax and inv.det and inv.det > f.detMax then
        return false
    end

    if f.lsgMin and inv.lsg and inv.lsg < f.lsgMin then
        return false
    end

    return true
end

local function matches_bci_filter(binding, summary)
    local f = binding.bciFilter
    if not f then
        return true
    end

    if f.stressScoreMin and summary.stressScore and summary.stressScore < f.stressScoreMin then
        return false
    end
    if f.stressScoreMax and summary.stressScore and summary.stressScore > f.stressScoreMax then
        return false
    end

    if f.visualOverloadMax and summary.visualOverloadIndex and summary.visualOverloadIndex > f.visualOverloadMax then
        return false
    end

    if f.stressBandAllowed and summary.stressBand then
        local ok = false
        for _, name in ipairs(f.stressBandAllowed) do
            if name == summary.stressBand then
                ok = true
                break
            end
        end
        if not ok then
            return false
        end
    end

    if f.attentionBandAllowed and summary.attentionBand then
        local ok = false
        for _, name in ipairs(f.attentionBandAllowed) do
            if name == summary.attentionBand then
                ok = true
                break
            end
        end
        if not ok then
            return false
        end
    end

    if f.requireGoodSignal and summary.signalQuality ~= "Good" then
        return false
    end

    return true
end

local function matches_metrics_filter(binding, metrics_slice)
    local f = binding.metricsFilter
    if not f then
        return true
    end

    local m = metrics_slice or {}

    if f.uecMin and m.uecBand and m.uecBand < f.uecMin then
        return false
    end
    if f.uecMax and m.uecBand and m.uecBand > f.uecMax then
        return false
    end

    if f.arrMin and m.arrBand and m.arrBand < f.arrMin then
        return false
    end

    return true
end

----------------------------------------------------------------------
-- Binding scoring and selection
----------------------------------------------------------------------

local function binding_specificity(binding)
    local spec = 0
    local iflt = binding.invariantFilter
    if iflt then
        for _, v in pairs(iflt) do
            if v ~= nil then
                spec = spec + 1
            end
        end
    end
    local bf = binding.bciFilter
    if bf then
        for _, v in pairs(bf) do
            if v ~= nil then
                spec = spec + 1
            end
        end
    end
    local mf = binding.metricsFilter
    if mf then
        for _, v in pairs(mf) do
            if v ~= nil then
                spec = spec + 1
            end
        end
    end
    return spec
end

local function score_binding(binding, summary)
    local score = 0.0
    local reasons = {}

    local p = binding.priority or 0
    score = score + (p * 10.0)
    if p ~= 0 then
        reasons[#reasons + 1] = "priority:" .. tostring(p)
    end

    local tier = binding.tier or "lab"
    if tier == "standard" then
        score = score + 5.0
        reasons[#reasons + 1] = "tier:standard"
    elseif tier == "mature" then
        score = score + 3.0
        reasons[#reasons + 1] = "tier:mature"
    elseif tier == "lab" then
        score = score + 1.0
        reasons[#reasons + 1] = "tier:lab"
    end

    local spec = binding_specificity(binding)
    score = score + spec
    if spec > 0 then
        reasons[#reasons + 1] = "specificity:" .. tostring(spec)
    end

    if binding.bciFilter and summary.stressScore then
        local mid = ((binding.bciFilter.stressScoreMin or 0.0) + (binding.bciFilter.stressScoreMax or 1.0)) * 0.5
        local d = math.abs(summary.stressScore - mid)
        local bonus = math.max(0.0, 1.0 - d)
        score = score + bonus
        reasons[#reasons + 1] = string.format("stressProximity:%.3f", bonus)
    end

    return score, reasons
end

local function select_binding(region_class, summary, inv_slice, metrics_slice, csi)
    local region_bindings = bindings_registry.by_region[region_class] or {}

    local ctx = {
        summary = summary,
        invariants = inv_slice,
        metrics = metrics_slice,
        csi = csi,
        regionClass = region_class,
    }

    local best
    local best_score = -math.huge
    local best_reasons = nil

    for _, binding in ipairs(region_bindings) do
        if matches_invariant_filter(binding, inv_slice)
            and matches_bci_filter(binding, summary)
            and matches_metrics_filter(binding, metrics_slice) then

            local score, reasons = score_binding(binding, summary)
            if score > best_score then
                best_score = score
                best = binding
                best_reasons = reasons
            end
        end
    end

    if best then
        BCIDebug.logBindingSelection(ctx, best, best_score, best_reasons)
    end

    return best
end

----------------------------------------------------------------------
-- Mapping request to Rust and outputs
----------------------------------------------------------------------

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
        bindingId = binding and binding.bindingId or nil,
    }
end

local function call_rust_mapping_kernel(request_tbl)
    if not Geometry._lib then
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
-- Public API: BciGeometry.sample and peekBinding
----------------------------------------------------------------------

function Geometry.sample(player_id, region_id, tile_id)
    player_id = player_id or 1

    local summary = BCI.getSummary(player_id)
    local inv_slice = Invariants.getRegionSlice(region_id, tile_id)
    local metrics_slice = Metrics.getSessionSlice(player_id)
    local csi = Timing.getCSI(player_id)
    local contract_ctx = Contract.getCurrentPolicy(player_id)

    local region_class = inv_slice.regionClass or "any"
    local inv_sig = invariants_band_signature(inv_slice)
    local summary_bands = compute_bands_from_summary(summary)
    local csi_bucket = compute_csi_bucket(csi)

    local cache_entry, player_cache, key = get_cache_entry(player_id, region_id, tile_id)

    local binding
    if should_invalidate(cache_entry, inv_sig, summary_bands, csi_bucket) then
        binding = select_binding(region_class, summary, inv_slice, metrics_slice, csi)
        set_cache_entry(player_cache, key, binding, inv_sig, summary_bands, csi_bucket)
    else
        binding = cache_entry.binding
    end

    if not binding then
        if H.BciKernel and H.BciKernel.evaluateFallback then
            return H.BciKernel.evaluateFallback(region_id, tile_id)
        end
        return nil
    end

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
        if H.BciKernel and H.BciKernel.evaluateFallback then
            return H.BciKernel.evaluateFallback(region_id, tile_id)
        end
        return nil
    end

    return outputs
end

function Geometry.peekBinding(player_id, region_id, tile_id)
    local player_cache = BindingCache[player_id]
    if not player_cache then
        return nil
    end

    local entry = player_cache[make_cache_key(region_id, tile_id)]
    if not entry or not entry.binding then
        return nil
    end

    local binding = entry.binding
    local caps
    if binding.safetyProfile then
        local sp = binding.safetyProfile
        caps = {
            maxCsi = sp.maxCsi or (sp.timingCaps and sp.timingCaps.maxCsi) or nil,
            maxDet = sp.maxDet or (sp.timingCaps and sp.timingCaps.maxDet) or nil,
        }
    end

    return {
        bindingId = binding.bindingId,
        tier = binding.tier,
        regionClass = binding.regionClass,
        caps = caps,
        inv_sig = entry.inv_sig,
        summary_bands = entry.summary_bands,
        csi_bucket = entry.csi_bucket,
    }
end

return Geometry
