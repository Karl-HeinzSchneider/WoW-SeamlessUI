---@type string, SeamlessDarkmode
local _, app = ...

-- One function per Blizzard frame. Each names the exact textures of that frame (and its
-- subframes) that are decoration, and passes them to `paint`. `paint` either tints a texture or
-- restores the color it had before it was first tinted, so the same function applies and undoes
-- darkmode. Portraits, icons, bar fills, text and flash/status/highlight textures are never
-- named here.
--
-- Frame names that may be missing in this client are looked up through _G and skipped when nil.

---@alias SeamlessDarkmode.Paint fun(texture: Texture?)

---@param paint SeamlessDarkmode.Paint
local function PlayerFrame(paint)
    local frame = _G.PlayerFrame
    if not frame then
        return
    end
    local container = frame.PlayerFrameContainer
    paint(container.FrameTexture)
    paint(container.AlternatePowerFrameTexture)
    paint(container.VehicleFrameTexture)
    paint(frame.PlayerFrameContent.PlayerFrameContentMain.LevelBackgroundCircle)
end

-- TargetFrame, FocusFrame and the boss frames share the target frame template.
---@param paint SeamlessDarkmode.Paint
---@param frame Frame?
local function TargetFrameTemplate(paint, frame)
    if not frame then
        return
    end
    paint(frame.TargetFrameContainer.FrameTexture)
    paint(frame.TargetFrameContent.TargetFrameContentMain.LevelBackgroundCircle)
end

---@param paint SeamlessDarkmode.Paint
local function TargetFrame(paint)
    TargetFrameTemplate(paint, _G.TargetFrame)
    paint(_G.TargetFrameToT and _G.TargetFrameToT.FrameTexture)
end

---@param paint SeamlessDarkmode.Paint
local function FocusFrame(paint)
    TargetFrameTemplate(paint, _G.FocusFrame)
    paint(_G.FocusFrameToT and _G.FocusFrameToT.FrameTexture)
end

---@param paint SeamlessDarkmode.Paint
local function PetFrame(paint)
    paint(_G.PetFrameTexture)
end

---@param paint SeamlessDarkmode.Paint
local function PartyFrame(paint)
    local party = _G.PartyFrame
    if not party then
        return
    end
    for i = 1, 4 do
        local member = party["MemberFrame" .. i]
        if member then
            paint(member.Texture)
            paint(member.VehicleTexture)
            paint(member.PetFrame and member.PetFrame.Texture)
        end
    end
end

---@param paint SeamlessDarkmode.Paint
local function BossFrames(paint)
    for i = 1, 5 do
        TargetFrameTemplate(paint, _G["Boss" .. i .. "TargetFrame"])
    end
end

-- Minimap ------------------------------------------------------------------------------------

-- The ring around the map (and the circle behind it while the map rotates) and the zone header.
---@param paint SeamlessDarkmode.Paint
local function Minimap(paint)
    paint(_G.MinimapCompassTexture)
    paint(_G.MinimapCompassTextureUnderlay)
    local cluster = _G.MinimapCluster
    paint(cluster and cluster.ZoneTextButton.StateTexture)
end

-- These 23x23 button atlases combine the border and icon. Render disjoint sections of the
-- existing artwork so only the three-pixel perimeter is tinted. No replacement art is shipped.
local buttonSections = {}

---@param button Button?
---@param paint SeamlessDarkmode.Paint
---@param active boolean
local function SquareButtonBorder(button, paint, active)
    local source = button and button.StateTexture
    if not source then
        return
    end
    local sections = buttonSections[source]
    if not active then
        if sections then
            source:SetAlpha(sections.alpha)
            for _, section in ipairs(sections) do
                paint(section.texture)
                section.texture:Hide()
            end
        end
        return
    end
    if not sections then
        local file = source:GetTexture()
        if not file then
            return
        end
        local layer, sublevel = source:GetDrawLayer()
        sections = { alpha = source:GetAlpha() }
        local r, g, b, a = source:GetVertexColor()
        local cuts = { 0, 3 / 23, 20 / 23, 1 }
        local left, top, _, bottom, right = source:GetTexCoord()
        for row = 1, 3 do
            for column = 1, 3 do
                local x1, x2 = cuts[column], cuts[column + 1]
                local y1, y2 = cuts[row], cuts[row + 1]
                -- Below AddTexture's additive hover/pressed artwork and calendar notifications.
                local section = button:CreateTexture(nil, layer, nil, (sublevel or 0) - 1)
                section:SetTexture(file)
                section:SetTexCoord(
                    left + (right - left) * x1,
                    left + (right - left) * x2,
                    top + (bottom - top) * y1,
                    top + (bottom - top) * y2
                )
                section:SetVertexColor(r, g, b, a)
                section:SetAlpha(sections.alpha)
                sections[#sections + 1] =
                    { texture = section, border = row ~= 2 or column ~= 2, x1 = x1, x2 = x2, y1 = y1, y2 = y2 }
            end
        end
        buttonSections[source] = sections
    end
    local width, height = source:GetSize()
    for _, section in ipairs(sections) do
        section.texture:ClearAllPoints()
        section.texture:SetPoint("TOPLEFT", source, "TOPLEFT", width * section.x1, -height * section.y1)
        section.texture:SetPoint("BOTTOMRIGHT", source, "TOPLEFT", width * section.x2, -height * section.y2)
        if section.border then
            paint(section.texture)
        end
        section.texture:Show()
    end
    source:SetAlpha(0)
end

---@param paint SeamlessDarkmode.Paint
---@param active boolean
function app.MinimapButtonBorders(paint, active)
    SquareButtonBorder(_G.GameTimeFrame, paint, active)
    local cluster = _G.MinimapCluster
    local tracking = cluster and cluster.Tracking
    SquareButtonBorder(tracking and tracking.Button, paint, active)
end

---@param paint SeamlessDarkmode.Paint
local function AddonCompartmentButton(paint)
    local button = _G.AddonCompartmentFrame
    paint(button and button.StateTexture)
end

-- The round border of every LibDBIcon minimap button. Buttons created later are painted from
-- the library's LibDBIcon_IconCreated callback (core.lua).
---@param paint SeamlessDarkmode.Paint
local function MinimapButtons(paint)
    local icons = LibStub("LibDBIcon-1.0", true)
    if not icons then
        return
    end
    for _, name in ipairs(icons:GetButtonList()) do
        paint(icons:GetMinimapButton(name).border)
    end
end

-- Action bars --------------------------------------------------------------------------------

---@param paint SeamlessDarkmode.Paint
local function ActionBars(paint)
    for _, name in ipairs({
        "MainActionBar",
        "MultiBarBottomLeft",
        "MultiBarBottomRight",
        "MultiBarRight",
        "MultiBarLeft",
        "MultiBar5",
        "MultiBar6",
        "MultiBar7",
        "PetActionBar",
        "StanceBar",
        "PossessActionBar",
    }) do
        local bar = _G[name]
        for _, button in ipairs(bar and bar.actionButtons or {}) do
            paint(button.NormalTexture)
        end
    end
end

---@param paint SeamlessDarkmode.Paint
local function EndCaps(paint)
    local bar = _G.MainActionBar
    local caps = bar and bar.EndCaps
    paint(caps and caps.LeftEndCap and caps.LeftEndCap.Texture)
    paint(caps and caps.RightEndCap and caps.RightEndCap.Texture)
end

-- XP and reputation share each container's border. Select its painter from the bar currently
-- displayed, and restore it when the container switches to an unrelated bar.
---@param experience SeamlessDarkmode.Paint
---@param reputation SeamlessDarkmode.Paint
---@param restore SeamlessDarkmode.Paint
function app.StatusTrackingBars(experience, reputation, restore)
    local info = _G.StatusTrackingBarInfo
    for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
        local container = _G[name]
        if container then
            local paint = restore
            if info and container.shownBarIndex == info.BarsEnum.Experience then
                paint = experience
            elseif info and container.shownBarIndex == info.BarsEnum.Reputation then
                paint = reputation
            end
            paint(container.BarFrameTexture)
        end
    end
end

-- Every option group with the frame functions it switches. Order is the options order.
---@type SeamlessDarkmode.Group[]
app.groups = {
    {
        key = "unitframes",
        name = "Unit frames",
        frames = { PlayerFrame, TargetFrame, FocusFrame, PetFrame, PartyFrame, BossFrames },
    },
    {
        key = "minimap",
        name = "Minimap",
        frames = { Minimap, AddonCompartmentButton, MinimapButtons },
    },
    { key = "actionbars", name = "Action bar slot borders", frames = { ActionBars } },
    { key = "endcaps", name = "Action bar gryphons", frames = { EndCaps } },
    { key = "experience", name = "XP bar border", frames = {} },
    { key = "reputation", name = "Reputation bar border", frames = {} },
}
