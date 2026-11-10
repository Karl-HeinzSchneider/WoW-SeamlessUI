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
-- Keep the registered default table current for the active layout and user scale.
-- LibEditMode retains this table; no internal library state needs changing.
local DEFAULT = { point = "BOTTOM", relativePoint = "BOTTOM", relativeTo = "UIParent", x = 0, y = 0 }
local defaultHeights = {}

local function defaultPosition()
    local layout = lib:GetActiveLayoutName() or ""
    local height = defaultHeights[layout]
    if not height then
        -- UIParentPanelManager.lua:FramePositionDelegate:ManageBottomFrameContainer.
        height = EditModeUtil:GetBottomActionBarHeight()
            + C_GameRules.GetGameRuleAsFloat(Enum.GameRule.CustomActionbarOverlayHeightOffset)
        height = height > 0 and height + BOTTOM_FRAME_CONTAINER_MARGIN or MAIN_ACTION_BAR_OFFSET_Y
        -- PlayerCastingBarFrameTemplate: layoutIndex=2, bottomPadding=8.
        -- LayoutFrame.lua:VerticalLayoutMixin:LayoutChildren places later children
        -- underneath it. Evaluate the same shared layout inputs without reading the
        -- native castbar, and snapshot the result so ours remains independent.
        local container = GetBottomManagedFrameContainer()
        local _, _, _, bottom = container:GetPadding()
        height = height + bottom + 8
        for _, child in ipairs(container:GetLayoutChildren()) do
            if child.layoutIndex > 2 then
                local _, childHeight = container:GetChildSize(child)
                if container.respectChildScale then
                    childHeight = childHeight * child:GetScale()
                end
                local _, _, topPadding, bottomPadding = container:GetChildPadding(child)
                height = height + childHeight + topPadding + bottomPadding + (container.spacing or 0)
            end
        end
        defaultHeights[layout] = height
    end
    DEFAULT.y = height / app.db.profile.player.scale
    return DEFAULT
end

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
            if
                system.system == Enum.EditModeSystem.CastBar
                and system.isInDefaultPosition == false
                and anchor
                and anchor.relativeTo == "UIParent"
            then
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
    return stored and not stored.default and stored or defaultPosition()
end

function app.ApplyPlayerPosition()
    local bar = app.GetPlayerBar()
    if not bar then
        return
    end
    defaultPosition() -- Also updates the registered Reset Position target after layout/scale changes.
    local position = app.GetPlayerPosition()
    bar:ClearAllPoints()
    bar:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

-- The first addon enable can precede action-bar layout initialization. Re-evaluate
-- once the client has finished its entering-world layout work; moved bars stay put.
function app.RefreshPlayerDefault()
    if not app.addon:IsEnabled() then
        return
    end
    defaultHeights[lib:GetActiveLayoutName() or ""] = nil
    app.ApplyPlayerPosition()
    app.UpdatePlayerPreview()
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
            return defaultPosition()[key]
        end,
        reset = function()
            store({ default = true })
        end,
        isDefault = function()
            local layout = lib:GetActiveLayoutName()
            local position = app.GetPlayerPosition()
            local DEFAULT = defaultPosition()
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
        local default = defaultPosition()
        if point == default.point and x == default.x and y == default.y then
            store({ default = true })
            return
        end
        store({ point = point, relativePoint = point, relativeTo = "UIParent", x = x, y = y })
    end, defaultPosition(), L["Player cast bar"])
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
