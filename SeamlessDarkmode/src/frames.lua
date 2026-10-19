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

---@param paint SeamlessDarkmode.Paint
local function CalendarButton(paint)
    local button = _G.GameTimeFrame
    paint(button and button.StateTexture)
end

---@param paint SeamlessDarkmode.Paint
local function TrackingButton(paint)
    local cluster = _G.MinimapCluster
    local tracking = cluster and cluster.Tracking
    local button = tracking and tracking.Button
    paint(button and button.StateTexture)
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
        frames = { Minimap, CalendarButton, TrackingButton, AddonCompartmentButton, MinimapButtons },
    },
    { key = "actionbars", name = "Action bar slot borders", frames = { ActionBars } },
    { key = "endcaps", name = "Action bar gryphons", frames = { EndCaps } },
    { key = "experience", name = "XP bar border", frames = {} },
    { key = "reputation", name = "Reputation bar border", frames = {} },
}
