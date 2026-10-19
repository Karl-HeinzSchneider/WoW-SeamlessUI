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

-- Action bars ----------------------------------------------------------------------------------

-- The ring (NormalTexture) and empty-slot art of every button an action bar created through
-- the client's ActionBarMixin (`bar.actionButtons`). Border is the equipped/proc indicator.
---@param paint SeamlessDarkmode.Paint
---@param bar Frame?
local function ActionBarButtons(paint, bar)
    if not bar or not bar.actionButtons then
        return
    end
    for _, button in ipairs(bar.actionButtons) do
        paint(button.NormalTexture)
        paint(button.SlotArt)
    end
end

---@param paint SeamlessDarkmode.Paint
local function MainActionBar(paint)
    local bar = _G.MainActionBar
    if not bar then
        return
    end
    paint(bar.BorderArt)
    paint(bar.EndCaps.LeftEndCap.Texture)
    paint(bar.EndCaps.RightEndCap.Texture)
    ActionBarButtons(paint, bar)
end

---@param paint SeamlessDarkmode.Paint
local function MultiBars(paint)
    ActionBarButtons(paint, _G.MultiBarBottomLeft)
    ActionBarButtons(paint, _G.MultiBarBottomRight)
    ActionBarButtons(paint, _G.MultiBarRight)
    ActionBarButtons(paint, _G.MultiBarLeft)
    ActionBarButtons(paint, _G.MultiBar5)
    ActionBarButtons(paint, _G.MultiBar6)
    ActionBarButtons(paint, _G.MultiBar7)
end

---@param paint SeamlessDarkmode.Paint
local function PetActionBar(paint)
    ActionBarButtons(paint, _G.PetActionBar)
end

---@param paint SeamlessDarkmode.Paint
local function StanceBar(paint)
    ActionBarButtons(paint, _G.StanceBar)
end

---@param paint SeamlessDarkmode.Paint
local function PossessActionBar(paint)
    ActionBarButtons(paint, _G.PossessActionBar)
end

-- Every option group with the frame functions it switches. Order is the options order.
---@type SeamlessDarkmode.Group[]
app.groups = {
    {
        key = "unitframes",
        name = "Unit frames",
        frames = { PlayerFrame, TargetFrame, FocusFrame, PetFrame, PartyFrame, BossFrames },
    },
    { key = "minimap", name = "Minimap", frames = { Minimap } },
    {
        key = "actionbars",
        name = "Action bars",
        frames = { MainActionBar, MultiBars, PetActionBar, StanceBar, PossessActionBar },
    },
}
