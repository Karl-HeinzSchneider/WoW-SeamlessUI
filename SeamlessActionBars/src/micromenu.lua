---@type string, SeamlessActionBars
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local module = app.addon:NewModule("MicroMenu", "AceEvent-3.0")
local originalAlpha = {}

function module:OnInitialize()
    if not Enum.EditModeSystem or not Enum.EditModeSystem.MicroMenu then
        return
    end
    -- Adapt the settings panel's declarations so both surfaces share every accessor.
    local args = app.MicroMenuOptions().args
    local rows = {}
    for _, key in ipairs({ "orientation", "order", "hideArtwork", "hidden" }) do
        local option = args[key]
        if option then
            local row = {
                key = key,
                type = option.type,
                name = option.name,
                default = option.default,
                disabled = option.disabled,
                get = option.get,
                set = function(value)
                    option.set(nil, value)
                    app.core:RefreshOptions("SeamlessActionBars")
                end,
            }
            if option.type == "select" then
                row.values = {}
                for _, value in ipairs(option.sorting) do
                    row.values[#row.values + 1] = { text = option.values[value], value = value }
                end
            end
            rows[#rows + 1] = row
        end
    end
    app.core:RegisterEditModeSystemOptions("SeamlessActionBars:microMenu", {
        system = Enum.EditModeSystem.MicroMenu,
        name = L["Style"],
        key = "SeamlessActionBars:microMenu:style",
        enabled = function()
            return module:IsEnabled() and app.addon:IsEnabled()
        end,
        options = rows,
    })
end

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
        module:Refresh()
    end
end

function module:Refresh()
    applyArtwork()
    app.core:RefreshEditModeSystemOptions()
end

function module:OnDisable()
    self:UnregisterAllEvents()
    applyArtwork(true)
    app.core:RefreshEditModeSystemOptions()
end

-- Native settings go through the same layout service as Position: Save/Revert owns the
-- draft inside Edit Mode, and changes outside Edit Mode save the active custom layout.
function app.MicroMenuOptions()
    local service = app.core:GetFramePositionService()
    local args = {}
    args.hidden = app.BarHiddenOption("microMenu", L["Hide micro menu"], 50)
    local settings = Enum.EditModeMicroMenuSetting or {}
    local function nativeOption(key, name, values, sorting, order)
        local setting = settings[key]
        return {
            type = "select",
            name = name,
            order = order,
            layoutStored = true,
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
    return { type = "group", inline = true, name = L["Style"], order = 20, args = args }
end
