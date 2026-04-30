-- scripts/bci/geometry_registry.lua
--
-- Registry of bci-geometry-binding objects and a resolver that
-- filters and scores them to choose the best binding for a context.

local json = require("engine.json")
local H = require("scripts.h") or {}

local Registry = {}

local bindings = {}
local bindings_by_region_class = {}

----------------------------------------------------------------------
-- Registry loading
----------------------------------------------------------------------

local function index_bindings()
    bindings_by_region_class = {}

    for _, b in ipairs(bindings) do
        local rc = b.regionClass or "any"
        local bucket = bindings_by_region_class[rc]
        if not bucket then
            bucket = {}
            bindings_by_region_class[rc] = bucket
        end
        table.insert(bucket, b)
    end
end

--- Load bindings from a JSON file containing an array of binding objects.
--  This should be called at startup or when reloading BCI config.
function Registry.loadFromFile(path)
    local fh = io.open(path, "r")
    if not fh then
        return false, "unable to open " .. tostring(path)
    end

    local data = fh:read("*a")
    fh:close()

    local ok, arr = pcall(json.decode, data)
    if not ok or type(arr) ~= "table" then
        return false, "invalid JSON in " .. tostring(path)
    end

    bindings = arr
    index_bindings()
    return true
end

--- Directly set the bindings array (e.g., from engine config).
function Registry.setBindings(arr)
    bindings = arr or {}
    index_bindings()
end

function Registry.getBindings()
    return bindings
end

----------------------------------------------------------------------
-- Filter helpers: invariants, BCI summary, metrics
----------------------------------------------------------------------

local function matches_range(value, range)
    if not range then
        return true
    end

    if range.min and value < range.min then
        return false
    end

    if range.max and value > range.max then
        return false
    end

    return true
end

local function matches_enum(value, allowed_list)
    if not allowed_list or #allowed_list == 0 then
        return true
    end

    for _, name in ipairs(allowed_list) do
        if value == name then
            return true
        end
    end

    return false
end

local function matches_invariant_filter(filter, inv)
    if not filter or not inv then
        return true
    end

    if filter.cicBand and not matches_enum(inv.cicBand, filter.cicBand) then
        return false
    end

    if filter.lsgBand and not matches_enum(inv.lsgBand, filter.lsgBand) then
        return false
    end

    if filter.detBand and not matches_enum(inv.detBand, filter.detBand) then
        return false
    end

    if filter.cic and inv.cic and not matches_range(inv.cic, filter.cic) then
        return false
    end

    if filter.det and inv.det and not matches_range(inv.det, filter.det) then
        return false
    end

    return true
end

local function matches_bci_filter(filter, summary)
    if not filter or not summary then
        return true
    end

    if filter.stressBandAllowed and not matches_enum(summary.stressBand, filter.stressBandAllowed) then
        return false
    end

    if filter.attentionBandAllowed and not matches_enum(summary.attentionBand, filter.attentionBandAllowed) then
        return false
    end

    if filter.visualOverloadMax and summary.visualOverloadIndex
        and summary.visualOverloadIndex > filter.visualOverloadMax
    then
        return false
    end

    if filter.requireGoodSignal and summary.signalQuality ~= "Good" then
        return false
    end

    if filter.startleCompatible == false and summary.startleSpike then
        return false
    end

    if filter.stressScore and summary.stressScore
        and not matches_range(summary.stressScore, filter.stressScore)
    then
        return false
    end

    return true
end

local function matches_metrics_filter(filter, metrics)
    if not filter or not metrics then
        return true
    end

    if filter.uecBand and metrics.uecBand
        and not matches_range(metrics.uecBand, filter.uecBand)
    then
        return false
    end

    if filter.emdBand and metrics.emdBand
        and not matches_range(metrics.emdBand, filter.emdBand)
    then
        return false
    end

    if filter.cdlBand and metrics.cdlBand
        and not matches_range(metrics.cdlBand, filter.cdlBand)
    then
        return false
    end

    if filter.arrBand and metrics.arrBand
        and not matches_range(metrics.arrBand, filter.arrBand)
    then
        return false
    end

    if filter.detEstimate and metrics.detEstimate
        and not matches_range(metrics.detEstimate, filter.detEstimate)
    then
        return false
    end

    return true
end

----------------------------------------------------------------------
-- Scoring and resolution
----------------------------------------------------------------------

local function specificity_score(binding)
    local score = 0
    local f = binding.invariantFilter or {}
    local b = binding.bciFilter or {}
    local m = binding.metricsFilter or {}

    if f.cicBand or f.lsgBand or f.detBand or f.cic or f.det then
        score = score + 1
    end

    if b.stressBandAllowed or b.attentionBandAllowed or b.visualOverloadMax or b.stressScore then
        score = score + 1
    end

    if m.uecBand or m.emdBand or m.cdlBand or m.arrBand or m.detEstimate then
        score = score + 1
    end

    return score
end

local function base_priority(binding)
    if binding.priority ~= nil then
        return binding.priority
    end

    local tier = binding.tier or "standard"
    if tier == "lab" then
        return -10
    elseif tier == "standard" then
        return 0
    elseif tier == "mature" then
        return 5
    else
        return 0
    end
end

local function score_binding(binding)
    local score = base_priority(binding)
    score = score + specificity_score(binding)
    return score
end

--- Resolve the best binding for a given context.
--  ctx: { playerId, regionId, tileId, summary, invariants, metrics, csi, contractCtx }
--  Returns (binding or nil, score or nil, reasons: table of strings).
function Registry.resolve(ctx)
    local region_class = ctx.invariants and ctx.invariants.regionClass or "any"

    local candidate_list = bindings_by_region_class[region_class]
    if not candidate_list then
        candidate_list = bindings_by_region_class["any"] or {}
    end

    local reasons = {}
    local scored = {}

    for _, b in ipairs(candidate_list) do
        local ok_inv = matches_invariant_filter(b.invariantFilter, ctx.invariants)
        local ok_bci = ok_inv and matches_bci_filter(b.bciFilter, ctx.summary)
        local ok_metrics = ok_bci and matches_metrics_filter(b.metricsFilter, ctx.metrics)

        if ok_inv and ok_bci and ok_metrics then
            local s = score_binding(b)
            table.insert(scored, { binding = b, score = s })
        end
    end

    if #scored == 0 then
        table.insert(reasons, "no binding matched filters")
        return nil, nil, reasons
    end

    table.sort(scored, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end

        local at = a.binding.tier or "standard"
        local bt = b.binding.tier or "standard"
        if at ~= bt then
            if at == "mature" and bt ~= "mature" then
                return true
            end
            if bt == "mature" and at ~= "mature" then
                return false
            end
        end

        local aid = a.binding.bindingId or ""
        local bid = b.binding.bindingId or ""
        return aid < bid
    end)

    local best = scored[1]
    table.insert(reasons, "selected bindingId=" .. tostring(best.binding.bindingId) .. " score=" .. tostring(best.score))

    return best.binding, best.score, reasons
end

return Registry
