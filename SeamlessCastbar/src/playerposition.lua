---@type string, SeamlessCastbar
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local lib = app.core:GetEditModeLibrary()
local preview
local shown = true
function app.GetPlayerPreview()
    return preview
end
function app.IsPlayerEditMode()
    return lib:IsInEditMode()
end
-- Client EditModePresetLayouts.lua: the cast bar's declared free-position anchor.
-- Unlike the native managed bar, ours deliberately stays fixed on UIParent.
local DEFAULT = { point = "CENTER", relativePoint = "CENTER", relativeTo = "UIParent", x = 0, y = 0 }

function app.InitializePlayerSettings()
    local profile = app.db.profile
    if profile.standalonePlayer then
        return
    end
    local info = EditModeManagerFrame:GetActiveLayoutInfo()
    if not info then
        return
    end
    for _, system in ipairs(info.systems) do
        if system.system == Enum.EditModeSystem.CastBar then
            for _, setting in ipairs(system.settings) do
                if setting.setting == Enum.EditModeCastBarSetting.ShowCastTime then
                    profile.player.showCastTime = setting.value == 1
                end
            end
        end
    end
    profile.standalonePlayer = true
end

function app.GetPlayerPosition()
    local layout = lib:GetActiveLayoutName()
    local stored = layout and app.db.profile.positions.player[layout]
    -- Import a saved free-position layout once, using data only. Never inspect the
    -- native bar or retain an anchor to any other frame.
    if layout and not stored then
        local info = EditModeManagerFrame:GetActiveLayoutInfo()
        for _, system in ipairs(info and info.systems or {}) do
            local anchor = system.anchorInfo
            if system.system == Enum.EditModeSystem.CastBar and anchor and anchor.relativeTo == "UIParent" then
                stored = {
                    point = anchor.point,
                    relativePoint = anchor.relativePoint,
                    relativeTo = "UIParent",
                    x = anchor.offsetX / app.db.profile.player.scale,
                    y = anchor.offsetY / app.db.profile.player.scale,
                }
                app.db.profile.positions.player[layout] = stored
                break
            end
        end
    end
    return stored or DEFAULT
end

function app.ApplyPlayerPosition()
    local bar = app.GetPlayerBar()
    if not bar then
        return
    end
    local position = app.GetPlayerPosition()
    bar:ClearAllPoints()
    bar:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

local function changed()
    app.ApplyPlayerPosition()
    app.UpdatePlayerPreview()
    app.core:RefreshOptions(appName)
end

local function store(position)
    local layout = lib:GetActiveLayoutName()
    if not layout then
        return
    end
    app.db.profile.positions.player[layout] = position
    changed()
end

function app.PlayerCastbarPosition()
    local position, size = app.core:GetPositionOptions({
        get = function(key)
            return app.GetPlayerPosition()[key]
        end,
        set = function(key, value)
            if key == "relativeTo" then
                return
            end
            local position = CopyTable(app.GetPlayerPosition())
            position[key] = value
            store(position)
        end,
        default = function(key)
            return DEFAULT[key]
        end,
        reset = function()
            store(CopyTable(DEFAULT))
        end,
        isDefault = function()
            local layout = lib:GetActiveLayoutName()
            local position = app.GetPlayerPosition()
            return position.point == DEFAULT.point
                and position.relativePoint == DEFAULT.relativePoint
                and position.x == DEFAULT.x
                and position.y == DEFAULT.y
        end,
        disabled = function()
            return not app.addon:IsEnabled() or not lib:GetActiveLayoutName()
        end,
        anchorFrames = { { text = "UIParent", value = "UIParent" } },
    })
    position.layoutStored = true
    return position, size
end

function app.UpdatePlayerPreview()
    if not preview then
        return
    end
    local visible = app.addon:IsEnabled() and lib:IsInEditMode() and shown
    if visible then
        local settings = app.db.profile.player
        preview:SetLook("CLASSIC")
        preview:SetSize(settings.width, settings.height)
        preview.Text:ClearAllPoints()
        preview.Text:SetPoint("TOP", preview, "BOTTOM", 0, 1)
        preview:SetScale(settings.scale)
        local position = app.GetPlayerPosition()
        preview:ClearAllPoints()
        preview:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
        preview:SetMinMaxValues(0, 10)
        preview:SetValue(5)
        preview.Text:SetText(L["Player cast bar"])
        preview.CastTimeText:SetText(app.FormatCastTime(5, 10, settings.castTime.format, settings.castTime.decimals))
        preview.CastTimeText:SetShown(settings.showCastTime)
        preview.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        preview.Icon:SetSize(settings.iconSize, settings.iconSize)
        preview.Icon:SetShown(settings.icon.enabled)
        lib:RefreshFrameSettings(preview)
    end
    preview:SetShown(visible)
end

function app.RegisterPlayerEditMode()
    if preview then
        return
    end
    preview = CreateFrame("StatusBar", nil, UIParent, "CastingBarFrameTemplate")
    preview:Hide()
    preview:SetClampedToScreen(true)
    lib:AddFrame(preview, function(_, _, point, x, y)
        store({ point = point, relativePoint = point, relativeTo = "UIParent", x = x, y = y })
    end, DEFAULT, L["Player cast bar"])
    lib:AddFrameSettings(preview, app.core:GetEditModePageSettings(appName, "player"))
    app.core:RegisterEditModeOptions(appName .. ".Player", {
        section = "frames",
        enabled = function()
            return app.addon:IsEnabled()
        end,
        options = {
            {
                key = "player",
                type = "toggle",
                name = L["Player cast bar"],
                get = function()
                    return shown
                end,
                set = function(value)
                    shown = value
                    app.UpdatePlayerPreview()
                end,
            },
        },
    })
    for _, event in ipairs({ "enter", "exit", "layout" }) do
        lib:RegisterCallback(event, function()
            app.ApplyPlayerPosition()
            app.UpdatePlayerPreview()
            local bar = app.GetPlayerBar()
            if bar then
                bar:UpdateShownState(
                    not lib:IsInEditMode() and (bar.casting or bar.channeling) and bar:ShouldShowCastBar()
                )
            end
        end)
    end
end
