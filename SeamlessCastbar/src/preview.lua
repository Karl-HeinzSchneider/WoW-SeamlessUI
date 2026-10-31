---@type string, SeamlessCastbar
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- The target and focus cast bars have no Edit Mode system of their own. In Edit Mode a preview of
-- each, built from the game's cast bar art, stands in for the bar: an addon-owned UIParent child
-- at the bar's position (app.position) and effective scale, registered with LibEditMode. Dragging
-- it, its Position section or Reset Position store a position through app.position, which then
-- moves the real bar. Selecting it also shows its Style options. The bar itself is never dragged
-- or read (its geometry can be secret).

local lib = app.core:GetEditModeLibrary()

local specs = {
    target = { frame = "TargetFrame", bar = "TargetFrameSpellBar", name = L["Target cast bar"] },
    focus = { frame = "FocusFrame", bar = "FocusFrameSpellBar", name = L["Focus cast bar"] },
}
local order = { "target", "focus" }

-- Size of the client's target and focus bars (TargetSpellBarTemplate).
local WIDTH, HEIGHT = 150, 10

-- LibEditMode's Reset Position reports the registered default through the same callback as a
-- drag. No drag ends exactly on this point, so it means "back to the client's anchor".
local RESET = { point = "CENTER", x = 0, y = 0 }

---@type table<string, StatusBar>
local previews = {}
-- The Frames list checkboxes; the previews show by default.
local shown = { target = true, focus = true }

function app.PreviewVisibility(key, value)
    if value ~= nil then
        shown[key] = value
        EventRegistry:TriggerEvent("EditModeExternal.hideDialog")
        app.UpdatePreviews()
    end
    return shown[key]
end

---@param key string
---@return StatusBar?
function app.PreviewFrame(key)
    return previews[key]
end

-- Like Blizzard's Edit Mode, a moved bar leaves its anchor frame: it is stored where LibEditMode
-- placed the preview on UIParent.
local function onMoved(key, point, x, y)
    local position = app.position
    if point == RESET.point and x == RESET.x and y == RESET.y then
        position:Reset(key)
        return
    end
    local current = position:Get(key)
    current.point, current.relativeTo, current.relativePoint, current.x, current.y = point, "UIParent", point, x, y
    position:SetPosition(key, current)
end

local function createPreview(key)
    local spec = specs[key]
    local preview = CreateFrame("StatusBar", nil, UIParent)
    preview:Hide()
    preview:SetSize(WIDTH, HEIGHT)
    preview:SetClampedToScreen(true)
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
    lib:AddFrame(preview, function(_, _, point, x, y)
        onMoved(key, point, x, y)
    end, RESET, spec.name)
    local position = app.position
    local settings = {
        app.core:GetEditModePositionSetting({
            get = function(field)
                return position:Get(key)[field]
            end,
            set = function(field, value)
                position:Set(key, field, value)
            end,
            anchorFrames = function()
                return app.core:GetFramePositionService():GetAnchorFrames((position:Frames(key)))
            end,
            disabled = function()
                return not position.active
            end,
            scale = position:ScaleOption(key),
        }),
    }
    for _, setting in ipairs(app.LibEditModeSettings(key)) do
        settings[#settings + 1] = setting
    end
    settings[#settings + 1] = app.optionPages[key].config.buttonSection
    lib:AddFrameSettings(preview, settings)
    previews[key] = preview
end

-- The bar's effective scale relative to UIParent: its unit frame's times our scale (the bar's own
-- can be secret).
local function barScale(key, spec)
    local scale, parentScale = _G[spec.frame]:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not (app.Known(scale) and app.Known(parentScale)) then
        return app.position:GetScale(key)
    end
    return scale * app.position:GetScale(key) / parentScale
end

---Show the previews in Edit Mode at their bar's position with the current Style options, or hide them.
function app.UpdatePreviews()
    for key, preview in pairs(previews) do
        local spec = specs[key]
        local visible = app.addon:IsEnabled() and lib:IsInEditMode() and shown[key]
        if visible then
            local settings = app.db.profile[key]
            preview:SetScale(barScale(key, spec))
            local position = app.position:Get(key)
            preview:ClearAllPoints()
            preview:SetPoint(
                position.point,
                app.position:RelativeFrame(key, position.relativeTo),
                position.relativePoint,
                position.x,
                position.y
            )
            preview.Text:SetText(spec.name)
            local castTime = settings.castTime.enabled
            preview.Time:SetText(
                castTime and app.FormatCastTime(1.2, 2.5, settings.castTime.format, settings.castTime.decimals) or ""
            )
            lib:RefreshFrameSettings(preview)
        end
        preview:SetShown(visible)
    end
end

local registered = false

-- Called once from OnEnable; the unit frames create their bars at load.
function app.RegisterPreviews()
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
                    return app.PreviewVisibility(key)
                end,
                set = function(value)
                    app.PreviewVisibility(key, value)
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
