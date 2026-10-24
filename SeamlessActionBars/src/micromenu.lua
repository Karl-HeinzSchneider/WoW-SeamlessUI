---@type string, SeamlessActionBars
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local module = app.addon:NewModule("MicroMenu", "AceEvent-3.0")
local originalAlpha = {}

-- Only the surrounding Camelot artwork; the buttons and their hit areas stay intact.
local function applyArtwork(restore)
    for _, key in ipairs({ "BorderArt", "BackgroundArt" }) do
        local texture = MicroMenu and MicroMenu[key]
        if texture then
            if not restore and app.db.profile.microMenu.hideArtwork then
                if originalAlpha[texture] == nil then
                    originalAlpha[texture] = texture:GetAlpha()
                end
                texture:SetAlpha(0)
            elseif originalAlpha[texture] ~= nil then
                texture:SetAlpha(originalAlpha[texture])
                originalAlpha[texture] = nil
            end
        end
    end
end

function module:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "Refresh")
    self:Refresh()
end

function app.RefreshMicroMenu()
    if module:IsEnabled() then
        applyArtwork()
    end
end

function module:Refresh()
    applyArtwork()
end

function module:OnDisable()
    self:UnregisterAllEvents()
    applyArtwork(true)
end

-- Native settings go through the same layout service as Position: Save/Revert owns the
-- draft inside Edit Mode, and changes outside Edit Mode save the active custom layout.
function app.MicroMenuOptions()
    local service = app.core:GetFramePositionService()
    local args = {}
    local settings = Enum.EditModeMicroMenuSetting or {}
    local function nativeOption(key, name, values, sorting, order)
        local setting = settings[key]
        return {
            type = "select",
            name = name,
            order = order,
            editMode = true,
            values = values,
            sorting = sorting,
            default = function()
                return setting and service:GetDefaultSetting(MicroMenuContainer, setting)
            end,
            disabled = function()
                return not setting
                    or not service:CanEdit(MicroMenuContainer)
                    or service:ReadSetting(MicroMenuContainer, setting) == nil
            end,
            get = function()
                return setting and service:ReadSetting(MicroMenuContainer, setting)
            end,
            set = function(_, value)
                local ok, err = service:ApplySetting(MicroMenuContainer, setting, value)
                if not ok and err then
                    app.core.logger:warn("%s", err)
                end
            end,
        }
    end
    local orientation = Enum.MicroMenuOrientation or {}
    local order = Enum.MicroMenuOrder or {}
    if orientation.Horizontal and orientation.Vertical then
        args.orientation = nativeOption("Orientation", L["Orientation"], {
            [orientation.Horizontal] = L["Horizontal"],
            [orientation.Vertical] = L["Vertical"],
        }, { orientation.Horizontal, orientation.Vertical }, 10)
    end
    if order.Default and order.Reverse then
        args.order = nativeOption("Order", L["Menu order"], {
            [order.Default] = L["Default order"],
            [order.Reverse] = L["Reverse order"],
        }, { order.Default, order.Reverse }, 20)
    end
    if settings.Size then
        local scale = app.core:GetNativeSettingScale(function()
            return MicroMenuContainer
        end, settings.Size)
        args.size = {
            type = "range",
            name = L["Menu size"],
            order = 30,
            editMode = true,
            min = (scale.min or 0.7) * 100,
            max = (scale.max or 2) * 100,
            step = (scale.step or 0.05) * 100,
            default = function()
                local value = scale.default()
                return value and value * 100
            end,
            disabled = function()
                return not service:CanEdit(MicroMenuContainer) or scale.disabled()
            end,
            get = function()
                return scale.get() * 100
            end,
            set = function(_, value)
                scale.set(value / 100)
            end,
        }
    end
    args.hideArtwork = {
        type = "toggle",
        name = L["Hide menu border and background"],
        order = 40,
        width = "full",
        default = false,
        get = function()
            return app.db.profile.microMenu.hideArtwork
        end,
        set = function(_, value)
            app.db.profile.microMenu.hideArtwork = value
            if module:IsEnabled() then
                applyArtwork()
            end
        end,
    }
    return { type = "group", inline = true, name = L["Micro menu"], order = 20, args = args }
end
