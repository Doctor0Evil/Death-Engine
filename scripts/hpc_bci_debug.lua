-- scripts/hpc_bci_debug.lua
--
-- Debug overlays and NDJSON logging for BCI state and geometry bindings.

local ffi_ok, ffi = pcall(require, "ffi")
local json = require("engine.json")        -- replace with your engine JSON module
local Time = require("scripts.time")       -- expected to provide Time.now()
local BCI = require("scripts.bci")         -- BCI.getSummary(playerId)
local Geometry = require("scripts.bci.geometry") -- BciGeometry.peekBinding / sample
local H = require("scripts.h") or {}       -- engine helpers (debug draw, files, etc.)

local BCIDebug = {}

local overlay_enabled = false
local last_log_file_path = nil
local log_file_handle = nil

----------------------------------------------------------------------
-- Internal helpers
----------------------------------------------------------------------

local function ensure_log_file()
    if log_file_handle then
        return log_file_handle
    end

    local session_id = Time.getSessionId and Time.getSessionId() or "unknown"
    local ts = tostring(Time.now() or 0)
    local path = "logs/bci-debug-session-" .. session_id .. "-" .. ts .. ".ndjson"

    if H.Files and H.Files.openAppend then
        log_file_handle = H.Files.openAppend(path)
        last_log_file_path = path
    end

    return log_file_handle
end

local function write_ndjson(event_type, payload)
    local fh = ensure_log_file()
    if not fh then
        return
    end

    local line = json.encode({
        ts = Time.now(),
        type = event_type,
        payload = payload,
    }) .. "\n"

    fh:write(line)
end

local function fmt_bool(v)
    if v then
        return "true"
    else
        return "false"
    end
end

local function color_for_stress_band(band)
    if band == "Low" then
        return 0.4, 1.0, 0.4
    elseif band == "Medium" then
        return 1.0, 1.0, 0.4
    elseif band == "High" then
        return 1.0, 0.6, 0.2
    elseif band == "Extreme" then
        return 1.0, 0.2, 0.2
    else
        return 0.8, 0.8, 0.8
    end
end

local function color_for_signal_quality(q)
    if q == "Good" then
        return 0.4, 1.0, 0.4
    elseif q == "Degraded" then
        return 1.0, 0.8, 0.3
    elseif q == "Unavailable" then
        return 0.8, 0.2, 0.2
    else
        return 0.8, 0.8, 0.8
    end
end

----------------------------------------------------------------------
-- Overlay drawing
----------------------------------------------------------------------

local function draw_text(x, y, text, r, g, b)
    if H.Debug and H.Debug.drawText2D then
        H.Debug.drawText2D(x, y, text, r, g, b, 1.0)
    end
end

local function draw_bar(x, y, w, h, value, r, g, b)
    if not (H.Debug and H.Debug.drawRect2D) then
        return
    end

    if value < 0.0 then
        value = 0.0
    elseif value > 1.0 then
        value = 1.0
    end

    local filled_w = w * value
    H.Debug.drawRect2D(x, y, w, h, 0.1, 0.1, 0.1, 0.8)
    H.Debug.drawRect2D(x, y, filled_w, h, r, g, b, 0.9)
end

--- Draw a compact overlay of current BCI summary and binding state.
--  Intended for developer builds only.
function BCIDebug.drawOverlay(player_id, region_id, tile_id)
    if not overlay_enabled then
        return
    end

    local summary = BCI.getSummary(player_id)
    local binding_info = Geometry.peekBinding and Geometry.peekBinding(player_id, region_id, tile_id) or nil

    local x = 0.02
    local y = 0.85
    local dy = 0.02

    draw_text(x, y, "BCI Summary", 1.0, 1.0, 1.0)
    y = y + dy

    local sr, sg, sb = color_for_stress_band(summary.stressBand or "Low")
    draw_text(x, y, string.format("Stress: %.2f (%s)", summary.stressScore or 0.0, summary.stressBand or "?"), sr, sg, sb)
    y = y + dy

    local ar, ag, ab = 0.6, 0.8, 1.0
    draw_text(x, y, "Attention: " .. tostring(summary.attentionBand or "?"), ar, ag, ab)
    y = y + dy

    local or_, og, ob = 1.0, 0.5, 0.2
    draw_text(x, y, string.format("Visual overload: %.2f", summary.visualOverloadIndex or 0.0), or_, og, ob)
    draw_bar(x, y + dy * 0.25, 0.15, dy * 0.4, summary.visualOverloadIndex or 0.0, or_, og, ob)
    y = y + dy

    local qr, qg, qb = color_for_signal_quality(summary.signalQuality or "Unavailable")
    draw_text(x, y, "Signal: " .. tostring(summary.signalQuality or "?"), qr, qg, qb)
    y = y + dy

    local sr2, sg2, sb2 = 1.0, 0.7, 0.3
    draw_text(x, y, "Startle spike: " .. fmt_bool(summary.startleSpike), sr2, sg2, sb2)
    y = y + dy

    if binding_info then
        draw_text(x, y, "Binding: " .. tostring(binding_info.bindingId or "none"), 0.7, 0.9, 1.0)
        y = y + dy
        draw_text(x, y, "Tier: " .. tostring(binding_info.tier or "n/a"), 0.7, 0.9, 1.0)
        y = y + dy
        if binding_info.caps then
            local caps = binding_info.caps
            draw_text(
                x,
                y,
                string.format("Caps: CSI<=%.2f DET<=%.2f", caps.maxCsi or 0.0, caps.maxDet or 0.0),
                0.8,
                0.8,
                1.0
            )
            y = y + dy
        end
    else
        draw_text(x, y, "Binding: (none)", 0.6, 0.6, 0.6)
        y = y + dy
    end
end

----------------------------------------------------------------------
-- NDJSON logging helpers
----------------------------------------------------------------------

--- Log a binding selection event for offline analysis.
--  ctx: table with summary, invariants, metrics, csi, regionId, tileId, playerId.
--  binding: table or nil.
--  score: number or nil.
--  reasons: table of strings or nil.
function BCIDebug.logBindingSelection(ctx, binding, score, reasons)
    write_ndjson("bci_binding_selection", {
        ctx = ctx,
        bindingId = binding and binding.bindingId or nil,
        tier = binding and binding.tier or nil,
        score = score,
        reasons = reasons,
    })
end

--- Log a signal quality snapshot.
function BCIDebug.logSignalQuality(player_id, summary)
    write_ndjson("bci_signal_quality", {
        playerId = player_id,
        signalQuality = summary.signalQuality,
        stressScore = summary.stressScore,
        stressBand = summary.stressBand,
        attentionBand = summary.attentionBand,
        visualOverloadIndex = summary.visualOverloadIndex,
        startleSpike = summary.startleSpike,
    })
end

----------------------------------------------------------------------
-- Console / control API
----------------------------------------------------------------------

function BCIDebug.toggleOverlay()
    overlay_enabled = not overlay_enabled
    return overlay_enabled
end

function BCIDebug.setOverlayEnabled(enabled)
    overlay_enabled = not not enabled
end

function BCIDebug.printSummary(player_id)
    local summary = BCI.getSummary(player_id)
    print("[BCI] summary for player " .. tostring(player_id) .. ":")
    for k, v in pairs(summary) do
        print("  " .. tostring(k) .. " = " .. tostring(v))
    end
end

function BCIDebug.getLastLogFilePath()
    return last_log_file_path
end

return BCIDebug
