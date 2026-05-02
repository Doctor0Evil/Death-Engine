-- scripts/bci/geometryregistry.lua
--
-- Registry of bci-geometry-binding-v1 objects and resolver:
--  - Loads bindings from JSON (array, bci-geometry-bindings-collection-v1).
--  - Indexes by regionClass for fast lookup.
--  - Filters on invariants, BciSummary fields, and metrics.
--  - Scores by priority, tier, and specificity.

local json = require("engine.json")
local H = require("scripts.h") or {}

local Registry = {}

local bindings = {}
local bindings_by_region = {}

----------------------------------------------------------------------
-- Registry loading
----------------------------------------------------------------------

local function index_bindings(list)
    bindings = list or {}
    bindings_by_region = {}

    for _, b in ipairs(bindings) do
        local rc = b.regionClass or "any"
        local bucket = bindings_by_region[rc]
        if not bucket then
            bucket = {}
            bindings_by_region[rc] = bucket
        end
        table.insert(bucket, b)
    end
end

local function load_bindings_from_file(path)
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

    index_bindings(arr)
    return true
end

function Registry.loadFromFile(path)
    return load_bindings_from_file(path)
end

function Registry.setBindings(arr)
    index_bindings(arr or {})
end

function Registry.getBindings()
    return bindings
end

----------------------------------------------------------------------
-- Filter helpers
----------------------------------------------------------------------

local function matches_range(value, range)
    if not range or value == nil then
        return true
    end
    if range.min ~= nil and value < range.min then
        return false
    end
    if range.max ~= nil and value > range.max then
        return false
    end
    return true
end

local function matches_enum(value, allowed_list)
    if not allowed_list or #allowed_list == 0 then
        return true
    end
    if value == nil then
        return false
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

    if filter.stressBandAllowed
        and not matches_enum(summary.stressBand, filter.stressBandAllowed) then
        return false
    end

    if filter.attentionBandAllowed
        and not matches_enum(summary.attentionBand, filter.attentionBandAllowed) then
        return false
    end

    if filter.visualOverloadMax
        and summary.visualOverloadIndex
        and summary.visualOverloadIndex > filter.visualOverloadMax then
        return false
    end

    if filter.requireGoodSignal
        and summary.signalQuality ~= "Good" then
        return false
    end

    if filter.startleCompatible == false and summary.startleSpike then
        return false
    end

    if filter.stressScore and summary.stressScore
        and not matches_range(summary.stressScore, filter.stressScore) then
        return false
    end

    return true
end

local function matches_metrics_filter(filter, metrics)
    if not filter or not metrics then
        return true
    end

    if filter.uecBand and metrics.uecBand
        and not matches_range(metrics.uecBand, filter.uecBand) then
        return false
    end
    if filter.emdBand and metrics.emdBand
        and not matches_range(metrics.emdBand, filter.emdBand) then
        return false
    end
    if filter.cdlBand and metrics.cdlBand
        and not matches_range(metrics.cdlBand, filter.cdlBand) then
        return false
    end
    if filter.arrBand and metrics.arrBand
        and not matches_range(metrics.arrBand, filter.arrBand) then
        return false
    end
    if filter.detEstimate and metrics.detEstimate
        and not matches_range(metrics.detEstimate, filter.detEstimate) then
        return false
    end

    return true
end

----------------------------------------------------------------------
-- Scoring
----------------------------------------------------------------------

local function specificity_score(binding)
    local score = 0
    local f = binding.invariantFilter or {}
    local b = binding.bciFilter or {}
    local m = binding.metricsFilter or {}

    for _, v in pairs(f) do
        if v ~= nil then
            score = score + 1
        end
    end
    for _, v in pairs(b) do
        if v ~= nil then
            score = score + 1
        end
    end
    for _, v in pairs(m) do
        if v ~= nil then
            score = score + 1
        end
    end

    return score
end

local function base_priority(binding)
    if binding.priority ~= nil then
        return binding.priority
    end

    local tier = binding.tier or "lab"
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

local function score_binding(binding, summary)
    local score = base_priority(binding)
    local reasons = {}

    if binding.priority ~= nil then
        reasons[#reasons + 1] = "priority=" .. tostring(binding.priority)
    end

    local tier = binding.tier or "lab"
    if tier == "standard" then
        score = score + 5.0
        reasons[#reasons + 1] = "tier=standard"
    elseif tier == "mature" then
        score = score + 3.0
        reasons[#reasons + 1] = "tier=mature"
    elseif tier == "lab" then
        score = score + 1.0
        reasons[#reasons + 1] = "tier=lab"
    end

    local spec = specificity_score(binding)
    if spec > 0 then
        score = score + spec
        reasons[#reasons + 1] = "specificity=" .. tostring(spec)
    end

    if binding.bciFilter and summary and summary.stressScore then
        local r = binding.bciFilter.stressScore
        if r and (r.min or r.max) then
            local min_v = r.min or 0.0
            local max_v = r.max or 1.0
            local mid = (min_v + max_v) * 0.5
            local d = math.abs(summary.stressScore - mid)
            local bonus = math.max(0.0, 1.0 - d)
            score = score + bonus
            reasons[#reasons + 1] = string.format("stressProximity=%.3f", bonus)
        end
    end

    return score, reasons
end

----------------------------------------------------------------------
-- Public resolver API
----------------------------------------------------------------------

-- ctx:
--   playerId, regionId, tileId
--   summary (BciSummary)
--   invariants
--   metrics
--   csi
--   contractCtx
function Registry.resolve(ctx)
    local region_class = (ctx.invariants and ctx.invariants.regionClass) or "any"
    local candidates = bindings_by_region[region_class] or bindings_by_region["any"] or {}

    local scored = {}
    for _, b in ipairs(candidates) do
        if matches_invariant_filter(b.invariantFilter, ctx.invariants)
            and matches_bci_filter(b.bciFilter, ctx.summary)
            and matches_metrics_filter(b.metricsFilter, ctx.metrics) then

            local s, reasons = score_binding(b, ctx.summary)
            scored[#scored + 1] = {
                binding = b,
                score = s,
                reasons = reasons
            }
        end
    end

    if #scored == 0 then
        return nil, nil, { "no binding matched filters" }
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
            elseif bt == "mature" and at ~= "mature" then
                return false
            end
        end

        local aid = a.binding.bindingId or ""
        local bid = b.binding.bindingId or ""
        return aid < bid
    end)

    local best = scored[1]
    local reasons = best.reasons or {}
    reasons[#reasons + 1] = "selected bindingId=" .. tostring(best.binding.bindingId)
    reasons[#reasons + 1] = "score=" .. tostring(best.score)

    return best.binding, best.score, reasons
end

return Registry
