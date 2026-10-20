---@type string, SeamlessUI
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessUI.FPSDisplay : AceModule
local module = app.addon:NewModule("FPSDisplay") --[[@as SeamlessUI.FPSDisplay]]
app.fpsDisplay = module

local lib = app.core:GetEditModeLibrary()
local anchor
local originalPoints
local showAnchor = true
local visibilityBeforeEditMode
local defaults = { point = "BOTTOMRIGHT", x = -2, y = 2 }

function module:Refresh()
    if not anchor or not self:IsEnabled() then
        return
    end
    local name = lib:GetActiveLayoutName()
    local position = (name and app.db.profile.fpsDisplay.layouts[name]) or defaults
    anchor:ClearAllPoints()
    anchor:SetPoint(position.point, UIParent, position.point, position.x, position.y)
    anchor:SetShown(lib:IsInEditMode() and showAnchor)
    if lib:IsInEditMode() then
        if visibilityBeforeEditMode == nil then
            visibilityBeforeEditMode = FramerateFrame:IsShown()
        end
        FramerateFrame:SetShown(showAnchor or visibilityBeforeEditMode)
    elseif visibilityBeforeEditMode ~= nil then
        FramerateFrame:SetShown(visibilityBeforeEditMode)
        visibilityBeforeEditMode = nil
    end
    app.core:RefreshEditModeOptions()
end

function module:OnEnable()
    if not FramerateFrame then
        return
    end
    originalPoints = {}
    for index = 1, FramerateFrame:GetNumPoints() do
        originalPoints[index] = { FramerateFrame:GetPoint(index) }
    end
    if not anchor then
        anchor = CreateFrame("Frame", nil, UIParent)
        anchor:SetSize(120, 24)
        anchor:SetClampedToScreen(true)
        lib:AddFrame(anchor, function(_, layoutName, point, x, y)
            if module:IsEnabled() and layoutName then
                app.db.profile.fpsDisplay.layouts[layoutName] = { point = point, x = x, y = y }
            end
        end, defaults, L["FPS display"])
        lib:AddFrameSettings(anchor, {
            {
                name = L["Show FPS on startup"],
                kind = lib.SettingType.Checkbox,
                default = false,
                get = function()
                    return app.core.db.profile.tweaks.showFramerateOnStartup
                end,
                set = function(_, value)
                    app.core.db.profile.tweaks.showFramerateOnStartup = value
                    visibilityBeforeEditMode = value
                    module:Refresh()
                end,
            },
        })
    end
    FramerateFrame:ClearAllPoints()
    FramerateFrame:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT")
    self:Refresh()
end

function module:OnDisable()
    if visibilityBeforeEditMode ~= nil then
        FramerateFrame:SetShown(visibilityBeforeEditMode)
        visibilityBeforeEditMode = nil
    end
    if anchor then
        anchor:Hide()
    end
    if originalPoints then
        FramerateFrame:ClearAllPoints()
        for _, point in ipairs(originalPoints) do
            FramerateFrame:SetPoint(unpack(point))
        end
        originalPoints = nil
    end
    app.core:RefreshEditModeOptions()
end

function module:OnProfileRefresh()
    self:Refresh()
end

app.core:RegisterEditModeOptions("SeamlessUI.FPSDisplay", {
    section = "frames",
    enabled = function()
        return app.db and app.addon:IsEnabled() and module:IsEnabled() and anchor ~= nil
    end,
    options = {
        {
            key = "fpsDisplay",
            type = "toggle",
            name = L["FPS display"],
            get = function()
                return showAnchor
            end,
            set = function(value)
                showAnchor = value
                EventRegistry:TriggerEvent("EditModeExternal.hideDialog")
                module:Refresh()
            end,
        },
    },
})

lib:RegisterCallback("enter", function()
    module:Refresh()
end)
lib:RegisterCallback("exit", function()
    module:Refresh()
end)
lib:RegisterCallback("layout", function()
    module:Refresh()
end)

local function ForEachLayout(callback)
    if app.db then
        for _, profile in pairs(app.db.profiles) do
            if profile.fpsDisplay and profile.fpsDisplay.layouts then
                callback(profile.fpsDisplay.layouts)
            end
        end
    end
end

lib:RegisterCallback("create", function(name, _, sourceName)
    ForEachLayout(function(layouts)
        local source = sourceName and layouts[sourceName]
        if source then
            layouts[name] = { point = source.point, x = source.x, y = source.y }
        end
    end)
end)
lib:RegisterCallback("rename", function(oldName, newName)
    ForEachLayout(function(layouts)
        layouts[newName], layouts[oldName] = layouts[oldName], nil
    end)
end)
lib:RegisterCallback("delete", function(name)
    ForEachLayout(function(layouts)
        layouts[name] = nil
    end)
end)
