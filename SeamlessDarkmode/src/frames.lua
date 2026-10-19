---@type string, SeamlessDarkmode
local _, app = ...

-- One function per Blizzard frame. Each names the exact textures of that frame (and its
-- subframes) that are decoration, and passes them to `paint`. `paint` either tints a texture or
-- restores the color it had before it was first tinted, so the same function applies and undoes
-- darkmode. Portraits, icons, bar fills, text and status/flash textures are never named here.
--
-- Frame names that may be missing in this client are looked up through _G and skipped when nil.

---@alias SeamlessDarkmode.Paint fun(texture: Texture?)

local NINE_SLICE_PIECES = {
    "TopLeftCorner",
    "TopRightCorner",
    "BottomLeftCorner",
    "BottomRightCorner",
    "TopEdge",
    "BottomEdge",
    "LeftEdge",
    "RightEdge",
}

-- The border pieces of a NineSlice panel; its Center (the background) keeps its color.
---@param paint SeamlessDarkmode.Paint
---@param nineSlice Frame?
local function paintNineSlice(paint, nineSlice)
    if not nineSlice then
        return
    end
    for _, key in ipairs(NINE_SLICE_PIECES) do
        paint(nineSlice[key])
    end
end

-- The frame art of an action button: its NormalTexture (the metal ring) and the empty slot art.
-- `Border` is the equipped/proc indicator and stays untouched.
---@param paint SeamlessDarkmode.Paint
---@param button Button?
local function paintActionButton(paint, button)
    if not button then
        return
    end
    paint(button.NormalTexture or button:GetNormalTexture())
    paint(button.SlotArt)
end

---@param paint SeamlessDarkmode.Paint
---@param prefix string
---@param count integer
local function paintActionButtons(paint, prefix, count)
    for i = 1, count do
        paintActionButton(paint, _G[prefix .. i])
    end
end

-- Unit frames ----------------------------------------------------------------------------------

---@param paint SeamlessDarkmode.Paint
local function PlayerFrame(paint)
    local container = _G.PlayerFrame and _G.PlayerFrame.PlayerFrameContainer
    if not container then
        return
    end
    paint(container.FrameTexture)
    paint(container.AlternatePowerFrameTexture)
    paint(container.VehicleFrameTexture)
end

-- TargetFrame, FocusFrame and the boss frames share the target frame template.
---@param paint SeamlessDarkmode.Paint
---@param frame Frame?
local function TargetFrameTemplate(paint, frame)
    local container = frame and frame.TargetFrameContainer
    if not container then
        return
    end
    paint(container.FrameTexture)
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
    paint(_G.PetFrame and _G.PetFrame.Texture)
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

-- Action bars ----------------------------------------------------------------------------------

---@param paint SeamlessDarkmode.Paint
local function MainActionBar(paint)
    local bar = _G.MainActionBar or _G.MainMenuBar
    if bar then
        paint(bar.BorderArt)
        local endCaps = bar.EndCaps
        if endCaps then
            paint(endCaps.LeftEndCap)
            paint(endCaps.RightEndCap)
        end
    end
    paintActionButtons(paint, "ActionButton", 12)
end

---@param paint SeamlessDarkmode.Paint
local function MultiBars(paint)
    paintActionButtons(paint, "MultiBarBottomLeftButton", 12)
    paintActionButtons(paint, "MultiBarBottomRightButton", 12)
    paintActionButtons(paint, "MultiBarRightButton", 12)
    paintActionButtons(paint, "MultiBarLeftButton", 12)
    paintActionButtons(paint, "MultiBar5Button", 12)
    paintActionButtons(paint, "MultiBar6Button", 12)
    paintActionButtons(paint, "MultiBar7Button", 12)
end

---@param paint SeamlessDarkmode.Paint
local function PetActionBar(paint)
    paintActionButtons(paint, "PetActionButton", 10)
end

---@param paint SeamlessDarkmode.Paint
local function StanceBar(paint)
    paintActionButtons(paint, "StanceButton", 10)
end

-- Minimap --------------------------------------------------------------------------------------

---@param paint SeamlessDarkmode.Paint
local function Minimap(paint)
    paint(_G.MinimapCompassTexture)
    paint(_G.MinimapCluster and _G.MinimapCluster.BorderTop)
end

-- Bags and bank --------------------------------------------------------------------------------

---@param paint SeamlessDarkmode.Paint
local function ContainerFrames(paint)
    local combined = _G.ContainerFrameCombinedBags
    paintNineSlice(paint, combined and combined.NineSlice)
    for i = 1, 13 do
        local frame = _G["ContainerFrame" .. i]
        paintNineSlice(paint, frame and frame.NineSlice)
    end
end

---@param paint SeamlessDarkmode.Paint
local function BankFrame(paint)
    paintNineSlice(paint, _G.BankFrame and _G.BankFrame.NineSlice)
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
        key = "actionbars",
        name = "Action bars",
        frames = { MainActionBar, MultiBars, PetActionBar, StanceBar },
    },
    { key = "minimap", name = "Minimap", frames = { Minimap } },
    { key = "bags", name = "Bags and bank", frames = { ContainerFrames, BankFrame } },
}
