---@type string, SeamlessCastbar
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Readable addon-owned previews act as movable anchors. The real cast bars keep their
-- casting logic and parent; their potentially secret coordinates are never read.

local lib = app.core:GetEditModeLibrary()

local specs = {
    target = { frame = "TargetFrame", bar = "TargetFrameSpellBar", name = L["Target cast bar"] },
    focus = { frame = "FocusFrame", bar = "FocusFrameSpellBar", name = L["Focus cast bar"] },
}
local order = { "target", "focus" }

-- Size of the client's target and focus bars (TargetSpellBarTemplate).
local WIDTH, HEIGHT = 150, 10

---@type table<string, StatusBar>
local previews = {}
-- The Frames list checkboxes; the previews show by default.
local shown = { target = true, focus = true }
local managed, scriptHooks, clocks = {}, {}, {}
local RESET = { point = "CENTER", x = 0, y = 0 }

local function customPosition(key)
    return app.addon:IsEnabled() and app.db.profile[key].enabled and app.db.profile[key].position
end

local function anchorBar(key)
    local bar = _G[specs[key].bar]
    if bar then
        app.ApplyCastbarScale(key, bar)
    end
    if customPosition(key) and previews[key] and bar then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", previews[key], "TOPLEFT")
        managed[key] = true
    end
end

function app.ResetCastbarPosition(key)
    if InCombatLockdown() then
        return
    end
    app.db.profile[key].position = nil
    app.UpdatePreviews()
    app.core:RefreshOptions(appName)
    if previews[key] then
        lib:RefreshFrameSettings(previews[key])
    end
end

-- A cast, a channel and an interrupted cast demonstrate the current Style settings.
local function paint(key, elapsed)
    local preview, settings = previews[key], app.db.profile[key]
    local hold = settings.enabled and settings.hold.enabled
    local success = hold and settings.hold.success or 0.2
    local interrupt = hold and settings.hold.interrupt or 1
    local phase = elapsed % (8.7 + success * 2 + interrupt)
    local channel = phase >= 2.5 + success and phase < 7.5 + success * 2
    local interrupted = phase >= 7.5 + success * 2
    local total = channel and 5 or 2.5
    local time = channel and phase - 2.5 - success or interrupted and phase - 7.5 - success * 2 or phase
    local spellID = channel and 5143 or 116
    local name = C_Spell.GetSpellName(spellID) or specs[key].name
    local rank = settings.enabled and settings.rank.enabled and C_Spell.GetSpellSubtext(spellID)
    if rank and rank ~= "" then
        name = L["%s (%s)"]:format(name, rank)
    end
    preview.Text:SetText(name)
    preview.Icon:SetTexture(C_Spell.GetSpellTexture(spellID))
    preview:SetMinMaxValues(0, total)
    local failed = interrupted and time >= 1.2
    preview:SetValue(channel and math.max(0, total - time) or math.min(time, failed and 1.2 or total))
    local texture = failed and "ui-castingbar-interrupted"
        or channel and "ui-castingbar-filling-channel"
        or "ui-castingbar-filling-standard"
    preview:SetStatusBarTexture(texture)
    preview:SetStatusBarColor(1, 1, 1)
    preview.Time:SetText(
        settings.enabled
                and settings.castTime.enabled
                and app.FormatCastTime(
                    failed and 1.2 or time,
                    total,
                    settings.castTime.format,
                    settings.castTime.decimals
                )
            or ""
    )
    for _, tick in ipairs(preview.Ticks) do
        tick:SetShown(channel and settings.enabled and settings.ticks.enabled)
    end
end

---@param key string
---@return StatusBar?
function app.PreviewFrame(key)
    return previews[key]
end

local function createPreview(key)
    local spec = specs[key]
    local parent = _G[spec.frame]
    local preview = CreateFrame("StatusBar", nil, UIParent)
    preview:Hide()
    preview:SetSize(WIDTH, HEIGHT)
    preview:SetFrameLevel(parent:GetFrameLevel() + 10)
    preview:SetStatusBarTexture("ui-castingbar-filling-standard")
    preview:SetMinMaxValues(0, 1)
    preview:SetValue(0.5)
    -- The same art and anchors as the client's small cast bar.
    local textBorder = preview:CreateTexture(nil, "BACKGROUND")
    textBorder:SetAtlas("ui-castingbar-textbox")
    textBorder:SetPoint("TOPLEFT")
    textBorder:SetPoint("BOTTOMRIGHT", 0, -12)
    local background = preview:CreateTexture(nil, "BACKGROUND", nil, 1)
    background:SetAtlas("ui-castingbar-background")
    background:SetAllPoints()
    local border = preview:CreateTexture(nil, "OVERLAY")
    border:SetAtlas("ui-castingbar-frame")
    border:SetPoint("TOPLEFT", -1, 2)
    border:SetPoint("BOTTOMRIGHT", 1, -2)
    preview.Text = preview:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Small")
    preview.Text:SetHeight(16)
    preview.Text:SetPoint("TOPLEFT", 0, -8)
    preview.Text:SetPoint("TOPRIGHT", 0, -8)
    -- Where text.lua puts the cast time of these bars.
    preview.Time = preview:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Small")
    preview.Time:SetPoint("LEFT", preview, "RIGHT", 4, 0)
    preview.Icon = preview:CreateTexture(nil, "ARTWORK")
    preview.Icon:SetSize(20, 20)
    preview.Icon:SetPoint("RIGHT", preview, "LEFT", -2, -5)
    preview.Ticks = {}
    for i = 1, 4 do
        local tick = preview:CreateTexture(nil, "OVERLAY")
        tick:SetAtlas("ui-castingbar-empower-pip")
        tick:SetWidth(2)
        tick:SetPoint("TOP", preview, "TOPLEFT", WIDTH * i / 5, -1)
        tick:SetPoint("BOTTOM", preview, "BOTTOMLEFT", WIDTH * i / 5, 1)
        preview.Ticks[i] = tick
    end
    preview:SetScript("OnUpdate", function(_, elapsed)
        clocks[key] = (clocks[key] or 1.2) + elapsed
        paint(key, clocks[key])
    end)
    lib:AddFrame(preview, function(_, _, point, x, y)
        if point == RESET.point and x == RESET.x and y == RESET.y then
            app.ResetCastbarPosition(key)
        else
            app.SaveCastbarDrag(key, point, x, y)
        end
    end, RESET, spec.name)
    lib:AddFrameSettings(preview, app.LibEditModeSettings(key))
    previews[key] = preview
end

---Show the previews in Edit Mode with the current Style options, or hide them.
function app.UpdatePreviews()
    for key, preview in pairs(previews) do
        local spec = specs[key]
        local visible = app.addon:IsEnabled() and lib:IsInEditMode() and shown[key]
        -- Keep the anchor positioned even when the preview artwork is hidden.
        local parent = _G[spec.frame]
        local bar = _G[spec.bar]
        if bar then
            app.ApplyCastbarScale(key, bar)
        end
        local scale = bar and bar:GetScale()
        local parentScale, uiScale = parent:GetEffectiveScale(), UIParent:GetEffectiveScale()
        preview:SetScale(
            app.Known(scale) and app.Known(parentScale) and app.Known(uiScale) and scale * parentScale / uiScale or 1
        )
        local position = customPosition(key)
        if position then
            preview:ClearAllPoints()
            local current = app.CastbarPosition(key)
            preview:SetPoint(
                current.point,
                _G[current.relativeTo] or UIParent,
                current.relativePoint,
                current.x,
                current.y
            )
            anchorBar(key)
        else
            local current = app.CastbarPosition(key, true)
            preview:ClearAllPoints()
            preview:SetPoint(
                current.point,
                _G[current.relativeTo] or UIParent,
                current.relativePoint,
                current.x,
                current.y
            )
            if managed[key] then
                managed[key] = nil
                -- Recompute the client's aura/ToT-dependent anchor after reset or disable.
                if bar and bar.AdjustPosition then
                    bar:AdjustPosition()
                end
            end
        end
        if visible then
            paint(key, clocks[key] or 1.2)
        end
        preview:SetShown(visible)
    end
end

local registered = false

-- Called once from OnEnable; the unit frames create their bars at load.
function app.RegisterPreviews()
    -- Ace hooks are removed on disable; permanent script hooks check the current profile.
    for _, key in ipairs(order) do
        local bar = _G[specs[key].bar]
        if bar and bar.AdjustPosition then
            app.addon:SecureHook(bar, "AdjustPosition", function()
                anchorBar(key)
            end)
            if not scriptHooks[key] then
                bar:HookScript("OnShow", function()
                    anchorBar(key)
                end)
                scriptHooks[key] = true
            end
        end
    end
    if registered then
        return
    end
    registered = true
    local options = {}
    for _, key in ipairs(order) do
        if _G[specs[key].frame] then
            createPreview(key)
            options[#options + 1] = {
                key = key,
                type = "toggle",
                name = specs[key].name,
                get = function()
                    return shown[key]
                end,
                set = function(value)
                    shown[key] = value
                    EventRegistry:TriggerEvent("EditModeExternal.hideDialog")
                    app.UpdatePreviews()
                end,
            }
        end
    end
    app.core:RegisterEditModeOptions(appName .. ".Previews", {
        section = "frames",
        enabled = function()
            return app.addon:IsEnabled()
        end,
        options = options,
    })
    lib:RegisterCallback("enter", app.UpdatePreviews)
    lib:RegisterCallback("exit", app.UpdatePreviews)
end
