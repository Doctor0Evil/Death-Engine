-- examples/bci_scenes.lua
--
-- Scripted BCI scenarios exercising the full pipeline:
-- import -> adapter -> summary -> geometry -> debug.

local json = require("engine.json")
local Time = require("scripts.time")
local BCIImport = require("scripts.hpc_bci_import")
local BCIAdapter = require("scripts.hpc_bci_adapter")
local BCI = require("scripts.bci")
local Geometry = require("scripts.bci.geometry")
local Contract = require("scripts.HContract") or require("scripts.HContract.init")
local BCIDebug = require("scripts.hpc_bci_debug")
local H = require("scripts.h") or {}

local BCIScenes = {}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function load_feature_envelopes_from_file(path, max_count)
    local fh = io.open(path, "r")
    if not fh then
        return {}
    end

    local out = {}
    local count = 0

    while true do
        local line = fh:read("*l")
        if not line then
            break
        end

        if line ~= "" then
            local ok, env = pcall(json.decode, line)
            if ok and env then
                table.insert(out, env)
                count = count + 1
                if max_count and count >= max_count then
                    break
                end
            end
        end
    end

    fh:close()
    return out
end

local function step_pipeline_for_envelope(player_id, feature_env)
    local contract_ctx = Contract.getCurrentPolicy(player_id)
    local metrics_env = BCIAdapter.processFeatureEnvelope(feature_env, contract_ctx)
    return metrics_env
end

----------------------------------------------------------------------
-- Scene 1: Corridor baseline vs BCI-on
----------------------------------------------------------------------

--- Run a corridor test over a sample NDJSON file of feature envelopes.
--  This assumes you have exported a session trace to:
--  "examples/bci/corridor-session-001.bci-features.ndjson".
function BCIScenes.runCorridorTest(player_id, region_id, tile_id)
    player_id = player_id or 1
    region_id = region_id or "corridor-test-region"
    tile_id = tile_id or "tile-001"

    BCIDebug.setOverlayEnabled(true)

    local path = "examples/bci/corridor-session-001.bci-features.ndjson"
    local envelopes = load_feature_envelopes_from_file(path, 256)

    if #envelopes == 0 then
        print("[BCI Scenes] no feature envelopes found at " .. path)
        return
    end

    print(string.format("[BCI Scenes] running corridor test with %d windows", #envelopes))

    for idx, env in ipairs(envelopes) do
        step_pipeline_for_envelope(player_id, env)

        local summary = BCI.getSummary(player_id)
        local outputs = Geometry.sample(player_id, region_id, tile_id)

        if idx % 16 == 1 then
            print(string.format(
                "[BCI Scenes] win %d stress=%.2f (%s) att=%s overload=%.2f startle=%s",
                idx,
                summary.stressScore or 0.0,
                summary.stressBand or "?",
                summary.attentionBand or "?",
                summary.visualOverloadIndex or 0.0,
                summary.startleSpike and "true" or "false"
            ))
        end

        if H.Visual and H.Visual.applyBciMask and outputs and outputs.visual then
            H.Visual.applyBciMask(player_id, outputs.visual)
        end
        if H.Audio and H.Audio.applyBciRtpcs and outputs and outputs.audio then
            H.Audio.applyBciRtpcs(player_id, outputs.audio)
        end
        if H.Haptics and H.Haptics.routeHaptics and outputs and outputs.haptics then
            H.Haptics.routeHaptics(player_id, outputs.haptics)
        end

        if H.Frame and H.Frame.waitSeconds then
            H.Frame.waitSeconds(0.1)
        end
    end

    print("[BCI Scenes] corridor test finished")
end

----------------------------------------------------------------------
-- Scene 2: Startle + cooldown walkthrough
----------------------------------------------------------------------

--- Synthetic scene that injects a startle-like spike and watches cooldown behavior.
--  This does not rely on specific NDJSON content; it manipulates summaries via
--  normal pipeline steps and logs the resulting state.
function BCIScenes.runStartleCooldownDemo(player_id, region_id, tile_id)
    player_id = player_id or 1
    region_id = region_id or "corridor-test-region"
    tile_id = tile_id or "tile-001"

    BCIDebug.setOverlayEnabled(true)

    local path = "examples/bci/startle-demo-session.bci-features.ndjson"
    local envelopes = load_feature_envelopes_from_file(path, 128)

    if #envelopes == 0 then
        print("[BCI Scenes] no feature envelopes found at " .. path)
        return
    end

    print(string.format("[BCI Scenes] running startle cooldown demo with %d windows", #envelopes))

    for idx, env in ipairs(envelopes) do
        step_pipeline_for_envelope(player_id, env)

        local summary = BCI.getSummary(player_id)
        local cooldown_state = nil
        if BCI.Cooldown and BCI.Cooldown.getState then
            cooldown_state = BCI.Cooldown.getState(player_id)
        end

        local outputs = Geometry.sample(player_id, region_id, tile_id)

        local mode = cooldown_state and cooldown_state.mode or "UNKNOWN"
        local remaining = cooldown_state and cooldown_state.secondsRemaining or 0.0

        print(string.format(
            "[BCI Scenes] win %03d stress=%.2f (%s) startle=%s mode=%s remaining=%.1fs overload=%.2f",
            idx,
            summary.stressScore or 0.0,
            summary.stressBand or "?",
            summary.startleSpike and "true" or "false",
            tostring(mode),
            remaining,
            summary.visualOverloadIndex or 0.0
        ))

        BCIDebug.logSignalQuality(player_id, summary)

        if H.Visual and H.Visual.applyBciMask and outputs and outputs.visual then
            H.Visual.applyBciMask(player_id, outputs.visual)
        end
        if H.Audio and H.Audio.applyBciRtpcs and outputs and outputs.audio then
            H.Audio.applyBciRtpcs(player_id, outputs.audio)
        end
        if H.Haptics and H.Haptics.routeHaptics and outputs and outputs.haptics then
            H.Haptics.routeHaptics(player_id, outputs.haptics)
        end

        if H.Frame and H.Frame.waitSeconds then
            H.Frame.waitSeconds(0.1)
        end
    end

    print("[BCI Scenes] startle cooldown demo finished")
end

----------------------------------------------------------------------
-- Scene 3: Signal quality degradation
----------------------------------------------------------------------

--- Scene that demonstrates behavior when signal quality degrades and recovers.
--  Expects a trace file where some windows lack usable BCI data.
function BCIScenes.runSignalQualityDemo(player_id, region_id, tile_id)
    player_id = player_id or 1
    region_id = region_id or "corridor-test-region"
    tile_id = tile_id or "tile-001"

    BCIDebug.setOverlayEnabled(true)

    local path = "examples/bci/signal-quality-demo.bci-features.ndjson"
    local envelopes = load_feature_envelopes_from_file(path, 128)

    if #envelopes == 0 then
        print("[BCI Scenes] no feature envelopes found at " .. path)
        return
    end

    print(string.format("[BCI Scenes] running signal quality demo with %d windows", #envelopes))

    local last_quality = nil

    for idx, env in ipairs(envelopes) do
        step_pipeline_for_envelope(player_id, env)

        local summary = BCI.getSummary(player_id)
        local outputs = Geometry.sample(player_id, region_id, tile_id)

        if summary.signalQuality ~= last_quality then
            print(string.format(
                "[BCI Scenes] win %03d signal=%s stress=%.2f (%s) overload=%.2f",
                idx,
                tostring(summary.signalQuality or "?"),
                summary.stressScore or 0.0,
                summary.stressBand or "?",
                summary.visualOverloadIndex or 0.0
            ))
            BCIDebug.logSignalQuality(player_id, summary)
            last_quality = summary.signalQuality
        end

        if H.Visual and H.Visual.applyBciMask and outputs and outputs.visual then
            H.Visual.applyBciMask(player_id, outputs.visual)
        end
        if H.Audio and H.Audio.applyBciRtpcs and outputs and outputs.audio then
            H.Audio.applyBciRtpcs(player_id, outputs.audio)
        end
        if H.Haptics and H.Haptics.routeHaptics and outputs and outputs.haptics then
            H.Haptics.routeHaptics(player_id, outputs.haptics)
        end

        if H.Frame and H.Frame.waitSeconds then
            H.Frame.waitSeconds(0.1)
        end
    end

    print("[BCI Scenes] signal quality demo finished")
end

return BCIScenes
