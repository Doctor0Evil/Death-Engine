-- hpc_bci_adapter.lua
-- Lua orchestrator for BCI geometry binding selection.
-- Tier-2 artifact: consumes Tier-1 contracts, performs zero numerical safety logic.
-- All math and caps enforcement happens in Rust kernel.

local BCI = require("bci.init")
local H = require("horror.invariants")
local Director = require("director.core")
local Story = require("story.engine")

local M = {}

-- Construct a BciMappingRequest table from current game state.
-- This is the only interface Lua uses to communicate with the Rust kernel.
function M.build_mapping_request(session_id, player_id, region_id, tile_id)
    local invariants = H.get_region_invariants(region_id)
    local metrics = BCI.get_current_metrics()
    local summary = BCI.get_summary()
    local csi = BCI.get_consent_safety_index()

    local contract_context = {
        preset_id = Director.get_current_preset(),
        tier = Director.get_content_tier(),
        safety_profile_id = BCI.get_active_safety_profile()
    }

    local request = {
        schemaId = "bci-mapping-request-v1",
        schemaVersion = "1.0.0",
        sessionId = session_id,
        playerId = player_id,
        tickIndex = BCI.get_tick_index(),
        regionId = region_id,
        tileId = tile_id,
        invariants = {
            cic = invariants.cic or 0,
            mdi = invariants.mdi or 0,
            aos = invariants.aos or 0,
            lsg = invariants.lsg or 0,
            spr = invariants.spr or 0,
            rrm = invariants.rrm or 0,
            fcf = invariants.fcf or 0,
            rwf = invariants.rwf or 0,
            hvf = invariants.hvf or 0,
            shci = invariants.shci or 0
        },
        metrics = {
            uec = metrics.uec or 0,
            emd = metrics.emd or 0,
            stci = metrics.stci or 0,
            cdl = metrics.cdl or 0,
            arr = metrics.arr or 0,
            det = metrics.det or 0
        },
        bciSummary = {
            stressScore = summary.stressScore or 0,
            stressBand = summary.stressBand or "OPTIMALSTRESS",
            attentionBand = summary.attentionBand or "Neutral",
            visualOverloadIndex = summary.visualOverloadIndex or 0,
            startleSpike = summary.startleSpike or 0,
            signalQuality = summary.signalQuality or "Good",
            csi = csi or 1.0,
            modeTransitionCooldown = summary.modeTransitionCooldown or 0
        },
        csi = csi or 1.0,
        contractContext = contract_context
    }

    return request
end

-- Evaluate mapping request through Rust kernel and dispatch outputs.
function M.evaluate_and_dispatch(request)
    local response = BCI.evaluate_mapping(request)

    if not response then
        Director.log_warning("BCI mapping evaluation returned nil response")
        return false
    end

    -- Apply visual outputs (via Director, not direct engine calls).
    if response.outputs and response.outputs.visual then
        Director.apply_visual_profile(response.outputs.visual)
    end

    -- Apply audio outputs.
    if response.outputs and response.outputs.audio then
        Director.apply_audio_profile(response.outputs.audio)
    end

    -- Apply haptic outputs.
    if response.outputs and response.outputs.haptic then
        Director.apply_haptic_profile(response.outputs.haptic)
    end

    -- Emit telemetry event for mapping activation.
    M.emit_activation_telemetry(request, response)

    -- Check for clamp events and log appropriately.
    if response.telemetry and response.telemetry.capsApplied then
        for _, cap in ipairs(response.telemetry.capsApplied) do
            Director.log_info("Safety cap applied: " .. cap)
        end
    end

    return true
end

-- Emit telemetry event for mapping activation (NDJSON format).
function M.emit_activation_telemetry(request, response)
    local telemetry_event = {
        schemaId = "bci-mapping-activation-v1",
        schemaVersion = "1.0.0",
        eventId = Director.generate_uuid(),
        sessionId = request.sessionId,
        playerId = request.playerId,
        tickIndex = request.tickIndex,
        tickTimestamp = os.time(),
        bindingId = response.outputs.visual.bindingId,
        profileId = Director.get_current_profile(),
        regionId = request.regionId,
        tileId = request.tileId,
        preState = {
            stressBand = request.bciSummary.stressBand,
            uec = request.metrics.uec,
            cdl = request.metrics.cdl,
            det = request.metrics.det,
            csi = request.csi
        },
        postState = {
            stressBand = response.updatedSummary.stressBand,
            uec = response.updatedMetrics.uec,
            cdl = response.updatedMetrics.cdl,
            det = response.updatedMetrics.det,
            csi = response.updatedSummary.csi
        },
        selectionMetrics = response.telemetry,
        kernelPerf = response.telemetry.perfData,
        capsApplied = response.telemetry.capsApplied or {}
    }

    Director.emit_telemetry(telemetry_event)
end

-- Main adapter tick function, called by Director loop.
function M.adapter_tick(session_id, player_id, region_id, tile_id)
    local request = M.build_mapping_request(session_id, player_id, region_id, tile_id)
    local success = M.evaluate_and_dispatch(request)

    if not success then
        Director.log_error("BCI adapter tick failed")
    end

    return success
end

return M
