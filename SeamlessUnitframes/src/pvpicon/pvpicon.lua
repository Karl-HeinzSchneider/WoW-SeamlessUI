---@type string, SeamlessUnitframes
local _, app = ...

local addon = app.addon
local unitFrames = app.unitFrames

-- Hides the PvP icon of the player, target, focus and party frames, chosen per unit frame
-- (profile.unitFrames[key].hidePvPIcon). The game shows and hides the icon itself; this only sets
-- its alpha, which the game never changes, so no update needs hooking and nothing is shown that
-- the game hid.
---@class SeamlessUnitframes.PvPIcon : AceModule, AceEvent-3.0
local module = {}
app.pvpIcon = addon:NewModule("PvPIcon", module, "AceEvent-3.0") --[[@as SeamlessUnitframes.PvPIcon]]

-- The icons we made transparent.
---@type table<Texture, boolean>
local hidden = {}

-- False for nil and for a secret value.
local function Readable(value)
    return (not canaccessvalue or canaccessvalue(value)) and value ~= nil
end

-- The PvP icons of a frame: the regions the game's own PvP indicator update uses, and the circle
-- the Legacy layout draws behind one.
---@param frame table
---@param key string
---@return Texture[]
local function Icons(frame, key)
    local elements
    if key == "player" then
        elements = PlayerFrame_GetPvPIndicatorElements and PlayerFrame_GetPvPIndicatorElements()
    elseif key == "target" or key == "focus" then
        elements = frame.GetPvPIndicatorElements and frame:GetPvPIndicatorElements()
    elseif key == "party" then
        local overlay = frame.PartyMemberOverlay
        elements = Readable(overlay) and overlay and { overlay.PVPIcon }
    end
    local icons = {}
    for _, region in pairs(elements or {}) do
        if Readable(region) and region and region.SetAlpha then
            icons[#icons + 1] = region
            local background = app.legacyLayout:PvPBackground(region)
            if background then
                icons[#icons + 1] = background
            end
        end
    end
    return icons
end

---@param frame table
---@param key string
local function Apply(frame, key)
    local hide = addon:IsEnabled() and app.db.profile.unitFrames[key].hidePvPIcon
    for _, icon in ipairs(Icons(frame, key)) do
        if hide then
            icon:SetAlpha(0)
            hidden[icon] = true
        elseif hidden[icon] then
            icon:SetAlpha(1)
            hidden[icon] = nil
        end
    end
end

function module:OnEnable()
    -- The party member frames are created when the party frame first shows.
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "Refresh")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
    self:Refresh()
end

function module:OnDisable()
    self:Refresh()
end

-- Reapplies every icon, after a setting changed.
function module:Refresh()
    for _, frame in ipairs(unitFrames:All()) do
        local key = unitFrames:KeyOf(frame)
        if key and unitFrames:Get(key).pvpIcon then
            Apply(frame, key)
        end
    end
end

function module:OnProfileRefresh()
    self:Refresh()
end
