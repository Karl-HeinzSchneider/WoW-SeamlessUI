---@type string, SeamlessUI
local _, app = ...

---@class SeamlessUI.Minimap : AceModule, AceEvent-3.0, AceHook-3.0
local module = app.addon:NewModule("Minimap", "AceEvent-3.0", "AceHook-3.0") --[[@as SeamlessUI.Minimap]]
app.minimap = module

-- Public compatibility API used by minimap button addons to choose their anchor geometry.
local function useSquareMinimap()
    return app.db.profile.minimap.square and not CVarCallbackRegistry:GetCVarValueBool("rotateMinimap")
end

local function getMinimapShape()
    return useSquareMinimap() and "SQUARE" or "ROUND"
end

function module:RefreshButtons()
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if self.buttonShape == shape then
        return
    end
    self.buttonShape = shape
    local icons = LibStub("LibDBIcon-1.0", true)
    if icons then
        for _, name in ipairs(icons:GetButtonList()) do
            icons:Refresh(name)
        end
    end
end

function module:OnInitialize()
    if not Enum.EditModeSystem or not Enum.EditModeSystem.Minimap then
        return
    end
    local style = app.optionPages.minimap.config.args.style
    local options = {}
    for key, option in pairs(style.args) do
        options[#options + 1] = {
            key = key,
            type = option.type,
            name = option.name,
            default = option.default,
            blizzard = option.blizzard,
            order = option.order,
            get = option.get,
            set = function(value)
                option.set(nil, value)
            end,
        }
    end
    table.sort(options, function(a, b)
        return a.order < b.order
    end)
    app.core:RegisterEditModeSystemOptions("SeamlessUI:minimap", {
        system = Enum.EditModeSystem.Minimap,
        name = style.name,
        key = "SeamlessUI:minimap:style",
        enabled = function()
            return self:IsEnabled() and app.addon:IsEnabled()
        end,
        options = options,
    })
end

function module:SetHidden(frame, hidden)
    if not frame then
        return
    end
    if not self:IsHooked(frame, "OnShow") then
        self:SecureHookScript(frame, "OnShow", "Apply")
    end
    if hidden then
        if frame:IsShown() then
            self.hiddenFrames[frame] = true
            frame:Hide()
        end
    elseif self.hiddenFrames[frame] then
        self.hiddenFrames[frame] = nil
        frame:Show()
    end
end

function module:RestoreHeaderLayout()
    local layout = self.headerLayout
    if not layout then
        return
    end
    self.headerLayout = nil
    local cluster = layout.cluster
    cluster:SetFixedSize(layout.width, layout.height)
    cluster:SetHeaderUnderneath(cluster:GetSettingValueBool(Enum.EditModeMinimapSetting.HeaderUnderneath))
    cluster:Layout()
end

function module:ApplyHeaderLayout(cluster, hidden)
    local container = cluster.MinimapContainer
    if not container then
        return
    end
    if not hidden then
        self:RestoreHeaderLayout()
        return
    end
    if not self.headerLayout then
        local width, height = cluster:GetFixedSize()
        self.headerLayout = { cluster = cluster, width = width, height = height }
    end
    -- ResizeLayoutFrame normally includes the header's extents. Fit the visible map instead,
    -- and remove the native 30-unit gap for either header placement and every map scale.
    local scale = container:GetScale()
    container:ClearAllPoints()
    container:SetPoint("TOP", cluster, "TOP", 10 / scale, 0)
    cluster:SetFixedSize(
        container:GetWidth() * scale + cluster:GetWidthPadding(),
        container:GetHeight() * scale + cluster:GetHeightPadding()
    )
    cluster:Layout()
end

function module:Apply()
    if self.applying then
        return
    end
    local cluster = MinimapCluster
    if not cluster then
        return
    end
    self.applying = true
    self.hiddenFrames = self.hiddenFrames or {}
    -- Native layout, rotation and scale updates can reset the map's offsets and dimensions.
    for _, method in ipairs({ "SetHeaderUnderneath", "SetEditModeScale", "UpdateMinimapConfig" }) do
        if cluster[method] and not self:IsHooked(cluster, method) then
            self:SecureHook(cluster, method, "Apply")
        end
    end
    local settings = app.db.profile.minimap
    self:ApplyShape(cluster, useSquareMinimap())
    self:RefreshButtons()
    local header = settings.hideHeader
    self:SetHidden(cluster.DielFrame, app.db.profile.hideMinimapDayNight)
    self:SetHidden(AddonCompartmentFrame, header or settings.hideAddonCompartment)
    self:SetHidden(cluster.Tracking, header or settings.hideTracking)
    self:SetHidden(GameTimeFrame, header or settings.hideCalendar)
    self:SetHidden(TimeManagerClockButton, header or settings.hideClock)
    self:SetHidden(cluster.ZoneTextButton, header or settings.hideZoneText)
    self:SetHidden(cluster.IndicatorFrame, header)
    self:ApplyHeaderLayout(cluster, header)
    if cluster.MarkDirty then
        cluster:MarkDirty()
    end
    self.applying = nil
end

function module:ApplyShape(cluster, square)
    local map = cluster.MinimapContainer and cluster.MinimapContainer.Minimap
    if not map then
        return
    end
    if square then
        if not self.squareBorder then
            -- The engine rotates this named texture together with the minimap mask.
            self.squareBorder = MinimapCompassTexture
        end
        if not self.squareApplied then
            self.compassTexCoords = { self.squareBorder:GetTexCoord() }
            self.compassPoints = {}
            for index = 1, self.squareBorder:GetNumPoints() do
                self.compassPoints[index] = { self.squareBorder:GetPoint(index) }
            end
        end
        self.squareBorder:SetTexture("Interface\\AddOns\\SeamlessUI\\media\\minimap_square_arrow")
        -- The supplied 512px art has its opening at x=52.5..458.5, y=64.5..458.5.
        -- Fit that opening, rather than the full canvas, to the live map dimensions.
        local xScale, yScale = map:GetWidth() / 406, map:GetHeight() / 394
        -- Center the opening in UV space, so the engine rotates about the map center.
        self.squareBorder:SetTexCoord(-0.5 / 512, 511.5 / 512, 5.5 / 512, 517.5 / 512)
        self.squareBorder:ClearAllPoints()
        self.squareBorder:SetPoint("CENTER", map, "CENTER", 0, 0)
        self.squareBorder:SetSize(512 * xScale, 512 * yScale)
        self.squareBorder:Show()
        map:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
        self.squareApplied = true
        self:SetHidden(MinimapCompassTextureUnderlay, true)
    elseif self.squareApplied then
        self.squareApplied = nil
        self.squareBorder:SetTexCoord(unpack(self.compassTexCoords))
        self.compassTexCoords = nil
        self.squareBorder:ClearAllPoints()
        for _, point in ipairs(self.compassPoints) do
            self.squareBorder:SetPoint(unpack(point))
        end
        self.compassPoints = nil
        self:SetHidden(MinimapCompassTextureUnderlay, false)
        -- Let the client restore the correct mask and art for the current rotation mode.
        cluster:UpdateMinimapConfig()
    end
end

function module:OnEnable()
    self.previousGetMinimapShape = GetMinimapShape
    GetMinimapShape = getMinimapShape
    app.core:RefreshEditModeSystemOptions()
    self:RegisterEvent("ADDON_LOADED", "Apply")
    self:Apply()
end

function module:OnDisable()
    if GetMinimapShape == getMinimapShape then
        GetMinimapShape = self.previousGetMinimapShape
    end
    self.previousGetMinimapShape = nil
    app.core:RefreshEditModeSystemOptions()
    self.applying = true
    self:UnregisterAllEvents()
    if MinimapCluster then
        self:ApplyShape(MinimapCluster, false)
    end
    for frame in pairs(self.hiddenFrames or {}) do
        frame:Show()
    end
    self.hiddenFrames = nil
    self:RestoreHeaderLayout()
    self:UnhookAll()
    self.applying = nil
    self:RefreshButtons()
    self.buttonShape = nil
end

function module:OnProfileRefresh()
    if self:IsEnabled() and IsLoggedIn() then
        self:Apply()
    end
end
