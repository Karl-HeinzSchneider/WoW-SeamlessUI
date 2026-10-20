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

-- The active layout's position; dragging stores only point, x and y relative to UIParent.
local function CurrentPosition()
    local name = lib:GetActiveLayoutName()
    local position = (name and app.db.profile.fpsDisplay.layouts[name]) or defaults
    return {
        point = position.point,
        relativePoint = position.relativePoint or position.point,
        relativeTo = position.relativeTo or "UIParent",
        x = position.x,
        y = position.y,
    }
end

local function RelativeFrame(name)
    local frame = _G[name]
    if type(frame) == "table" and frame.IsObjectType and frame:IsObjectType("Frame") then
        for _, entry in ipairs(app.blizzardPosition:GetAnchorFrames(anchor)) do
            if entry.value == name then
                return frame
            end
        end
    end
    return UIParent
end

function module:Refresh()
    if not anchor or not self:IsEnabled() then
        return
    end
    local position = CurrentPosition()
    anchor:ClearAllPoints()
    anchor:SetPoint(position.point, RelativeFrame(position.relativeTo), position.relativePoint, position.x, position.y)
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
                -- Reset Position does not refresh the dialog itself; keep the Position values current.
                lib:RefreshFrameSettings(anchor)
            end
        end, defaults, L["FPS display"])
        local settings = {
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
        }
        local position = app.core:GetEditModePositionSettings({
            get = function(key)
                return CurrentPosition()[key]
            end,
            set = function(key, value)
                local name = lib:GetActiveLayoutName()
                if not name or not module:IsEnabled() then
                    return
                end
                local current = CurrentPosition()
                current[key] = value
                app.db.profile.fpsDisplay.layouts[name] = current
                module:Refresh()
            end,
            anchorFrames = function()
                return app.blizzardPosition:GetAnchorFrames(anchor)
            end,
        })
        for _, setting in ipairs(position) do
            settings[#settings + 1] = setting
        end
        lib:AddFrameSettings(anchor, settings)
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
            layouts[name] = {
                point = source.point,
                relativePoint = source.relativePoint,
                relativeTo = source.relativeTo,
                x = source.x,
                y = source.y,
            }
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
