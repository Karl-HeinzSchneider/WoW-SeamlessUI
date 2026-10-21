---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local media = app.media
local LSM = media.LSM

-- Replaces the tooltips' border and background with LibSharedMedia textures and colors of choice,
-- including the target and focus frames' aura tooltip (through Blizzard's AuraContainerInbound).
local feature = app.features:NewFeature("Backdrop", {
    category = "all",
    name = L["Border and background"],
    desc = L["Draws the tooltips with a border and background of your choice. More textures come with addons that register them with LibSharedMedia (e.g. SharedMedia)."],
    order = 30,
    options = {
        background = {
            type = "select",
            order = 10,
            name = L["Background"],
            values = media.Values(LSM.MediaType.BACKGROUND),
        },
        backgroundColor = {
            type = "color",
            order = 20,
            name = L["Background color"],
            hasAlpha = true,
        },
        border = {
            type = "select",
            order = 30,
            name = L["Border"],
            values = media.Values(LSM.MediaType.BORDER),
        },
        borderColor = {
            type = "color",
            order = 40,
            name = L["Border color"],
            hasAlpha = true,
        },
        edgeSize = {
            type = "range",
            order = 50,
            name = L["Border size"],
            min = 1,
            max = 32,
            step = 1,
        },
        inset = {
            type = "range",
            order = 60,
            name = L["Background inset"],
            desc = L["How far the background stays inside the tooltip's edge."],
            min = 0,
            max = 16,
            step = 1,
        },
    },
})

-- The top-level tooltips that get the backdrop; embedded ones draw none.
local TOOLTIPS = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
}

-- Our backdrop frame per tooltip, created on first enable.
---@type table<GameTooltip, BackdropTemplate|Frame>
local backdrops = {}

-- The game restyles a tooltip's NineSlice whenever it shows one, but never touches its alpha:
-- fading it out hides the game's border and background without hooking any of that.
function feature:OnEnable()
    for _, name in ipairs(TOOLTIPS) do
        local tooltip = _G[name]
        if tooltip and tooltip.NineSlice then
            local backdrop = backdrops[tooltip]
            if not backdrop then
                backdrop = CreateFrame("Frame", nil, tooltip, "BackdropTemplate")
                backdrop:SetAllPoints()
                -- Same level as the tooltip, like its NineSlice: drawn behind the text.
                backdrop:SetUsingParentLevel(true)
                backdrops[tooltip] = backdrop
            end
            tooltip.NineSlice:SetAlpha(0)
            backdrop:Show()
        end
    end
    self:ApplySettings()
    -- A texture registered by an addon that loads after this one.
    LSM.RegisterCallback(self, "LibSharedMedia_Registered", "OnMediaRegistered")
end

function feature:OnDisable()
    LSM.UnregisterCallback(self, "LibSharedMedia_Registered")
    for tooltip, backdrop in pairs(backdrops) do
        app.border.SetFrame(tooltip, nil)
        backdrop:Hide()
        tooltip.NineSlice:SetAlpha(1)
    end
    if AuraContainerInbound then
        AuraContainerInbound.ResetTooltipStyle()
    end
end

---@param mediaType string
---@param key string
function feature:OnMediaRegistered(_, mediaType, key)
    local settings = self:Settings()
    if
        (mediaType == LSM.MediaType.BACKGROUND and key == settings.background)
        or (mediaType == LSM.MediaType.BORDER and key == settings.border)
    then
        self:ApplySettings()
    end
end

function feature:ApplySettings()
    local settings = self:Settings()
    local inset = settings.inset
    local info = {
        bgFile = media.Fetch(LSM.MediaType.BACKGROUND, settings.background),
        edgeFile = media.Fetch(LSM.MediaType.BORDER, settings.border),
        tile = true,
        tileEdge = true,
        tileSize = 16,
        edgeSize = settings.edgeSize,
        insets = { left = inset, right = inset, top = inset, bottom = inset },
    }
    local bg, border = settings.backgroundColor, settings.borderColor
    for tooltip, backdrop in pairs(backdrops) do
        backdrop:SetBackdrop(info)
        backdrop:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
        backdrop:SetBackdropBorderColor(border.r, border.g, border.b, border.a)
        -- Features that color the border by the tooltip's content paint this frame.
        app.border.SetFrame(tooltip, backdrop, border)
    end

    -- The target and focus frames' aura tooltip is forbidden to addons, but Blizzard styles it
    -- through a secure delegate made for this: the same backdrop on it. It wants a background or a
    -- border; with neither ("None" twice) it keeps the game's look.
    if AuraContainerInbound and (info.bgFile or info.edgeFile) then
        AuraContainerInbound.SetTooltipBackdrop({
            backdropInfo = info,
            centerColor = CreateColor(bg.r, bg.g, bg.b, bg.a),
            borderColor = CreateColor(border.r, border.g, border.b, border.a),
        })
    elseif AuraContainerInbound then
        AuraContainerInbound.ResetTooltipStyle()
    end
end
