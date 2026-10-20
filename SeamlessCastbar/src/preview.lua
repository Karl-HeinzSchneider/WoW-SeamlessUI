---@type string, SeamlessCastbar
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- The target and focus cast bars have no Edit Mode system of their own, and their unit frames
-- place them, so they are never moved. In Edit Mode a preview of each, built from the game's cast
-- bar art, sits where the client shows the bar under its unit frame. Selecting it opens its Style
-- options in LibEditMode's dialog. The preview is a child of the unit frame, so it follows that
-- frame's position, scale and visibility; the bar itself is never touched or read (its geometry
-- can be secret).

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

---@param key string
---@return StatusBar?
function app.PreviewFrame(key)
    return previews[key]
end

-- The client's spot for the bar under its unit frame, without aura rows (TargetSpellBarMixin).
local function place(preview, parent)
    local x, y = parent.smallSize and 38 or 43, parent.smallSize and 3 or 5
    if parent.haveToT then
        y = parent.smallSize and -48 or -46
    end
    preview:ClearAllPoints()
    preview:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", x, y)
end

local function createPreview(key)
    local spec = specs[key]
    local parent = _G[spec.frame]
    local preview = CreateFrame("StatusBar", nil, parent)
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
    lib:AddFrame(preview, function() end, { point = "CENTER", x = 0, y = 0 }, spec.name)
    app.core:SetEditModeFrameFixed(preview)
    lib:AddFrameSettings(preview, app.LibEditModeSettings(key))
    previews[key] = preview
end

---Show the previews in Edit Mode with the current Style options, or hide them.
function app.UpdatePreviews()
    for key, preview in pairs(previews) do
        local spec = specs[key]
        local visible = app.addon:IsEnabled() and lib:IsInEditMode() and shown[key]
        if visible then
            local settings = app.db.profile[key]
            local bar = _G[spec.bar]
            local scale = bar and bar:GetScale()
            preview:SetScale(app.Known(scale) and scale or 1)
            place(preview, preview:GetParent())
            preview.Text:SetText(spec.name)
            local castTime = settings.enabled and settings.castTime.enabled
            preview.Time:SetText(
                castTime and app.FormatCastTime(1.2, 2.5, settings.castTime.format, settings.castTime.decimals) or ""
            )
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
