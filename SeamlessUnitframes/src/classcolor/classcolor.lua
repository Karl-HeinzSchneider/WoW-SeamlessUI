---@type string, SeamlessUnitframes
local _, app = ...

local log = app.logger
local addon = app.addon

-- Colors the health bars of the game's unit frames in the class color of the player they show.
-- The bar's green fill atlas is swapped for its white "-Status" variant (the one the game tints
-- for heal prediction), and the bar color tints that. NPCs keep the default green.
---@class SeamlessUnitframes.ClassColor : AceModule
local module = {}
app.classColor = addon:NewModule("ClassColor", module) --[[@as SeamlessUnitframes.ClassColor]]

---@class SeamlessUnitframes.ClassColor.Frame
---@field key string  # the key in profile.classColor.frames
---@field name string  # the label in the options
---@field frameName? string  # the global unit frame; nil for the party frames

-- The unit frames that can be class colored, in the order of the options.
---@type SeamlessUnitframes.ClassColor.Frame[]
module.frames = {
    { key = "player", name = "Player", frameName = "PlayerFrame" },
    { key = "pet", name = "Pet", frameName = "PetFrame" },
    { key = "target", name = "Target", frameName = "TargetFrame" },
    { key = "targettarget", name = "Target of Target", frameName = "TargetFrameToT" },
    { key = "focus", name = "Focus", frameName = "FocusFrame" },
    { key = "focustarget", name = "Target of Focus", frameName = "FocusFrameToT" },
    { key = "party", name = "Party" },
}

-- The fields UnitFrame_Initialize puts on a unit frame's health bar.
---@class SeamlessUnitframes.ClassColor.HealthBar : StatusBar
---@field unit string?
---@field unitFrame Frame?
---@field lockColor boolean?  # the game never recolors the bar; its atlas carries the color

local STATUS_SUFFIX = "-Status"
local STATUS_SUFFIX_LOWER = STATUS_SUFFIX:lower()

-- Every health bar seen (its texture is hooked once), and the ones showing a class color now.
---@type table<SeamlessUnitframes.ClassColor.HealthBar, true>
local known = {}
---@type table<SeamlessUnitframes.ClassColor.HealthBar, true>
local colored = {}
-- Health bar atlas -> its white variant, or false when there is none.
---@type table<string, string|false>
local statusAtlases = {}
local settingAtlas = false

---@param atlas string
local function IsStatusAtlas(atlas)
    return atlas:lower():sub(-#STATUS_SUFFIX) == STATUS_SUFFIX_LOWER
end

-- The white variant of a health bar atlas, or nil when the game has none (e.g. the minus-mob bar).
---@param atlas string
---@return string?
local function StatusAtlas(atlas)
    if IsStatusAtlas(atlas) then
        return atlas
    end
    local status = statusAtlases[atlas]
    if status == nil then
        local candidate = atlas .. STATUS_SUFFIX
        status = C_Texture.GetAtlasInfo(candidate) and candidate or false
        statusAtlases[atlas] = status
    end
    return status or nil
end

---@param texture Texture
---@param atlas string
local function SetAtlas(texture, atlas)
    settingAtlas = true
    texture:SetAtlas(atlas)
    settingAtlas = false
end

-- Which entry of module.frames a unit frame belongs to.
---@param unitFrame Frame?
---@return string?
local function FrameKey(unitFrame)
    if not unitFrame then
        return nil
    end
    for _, entry in ipairs(module.frames) do
        if entry.frameName and unitFrame == _G[entry.frameName] then
            return entry.key
        end
    end
    if PartyFrame and unitFrame:GetParent() == PartyFrame then
        return "party"
    end
end

-- The class color of a connected player, or nil. The class is secret while the unit's identity
-- is restricted; the bar keeps its default color then.
---@param unit string?
---@return ColorMixin?
local function UnitClassColor(unit)
    if not unit or not UnitIsPlayer(unit) or not UnitIsConnected(unit) then
        return nil
    end
    local _, class = UnitClass(unit)
    if not class or (canaccessvalue and not canaccessvalue(class)) then
        return nil
    end
    return RAID_CLASS_COLORS[class]
end

-- The color the game gives a health bar (see UnitFrameHealthBar_Update).
---@param bar SeamlessUnitframes.ClassColor.HealthBar
local function DefaultColor(bar)
    if bar.lockColor then
        return 1, 1, 1
    elseif bar.unit and not UnitIsConnected(bar.unit) then
        return 0.5, 0.5, 0.5
    end
    return 0, 1, 0
end

---@param bar SeamlessUnitframes.ClassColor.HealthBar
---@param key string
---@return ColorMixin?
local function BarColor(bar, key)
    local db = app.db.profile.classColor
    if not db.enabled or not db.frames[key] then
        return nil
    end
    -- A pet has no class; it takes its owner's. In a vehicle the pet frame shows the player.
    return UnitClassColor(key == "pet" and "player" or bar.unit)
end

---@param bar SeamlessUnitframes.ClassColor.HealthBar
---@param key string
local function Apply(bar, key)
    local texture = bar:GetStatusBarTexture()
    local atlas = texture and texture:GetAtlas()
    if not atlas or atlas == "" then
        return
    end

    local color = BarColor(bar, key)
    local statusAtlas = color and StatusAtlas(atlas)
    if color and statusAtlas then
        if atlas ~= statusAtlas then
            SetAtlas(texture, statusAtlas)
        end
        bar:SetStatusBarColor(color:GetRGB())
        colored[bar] = true
    elseif colored[bar] then
        -- Only undo what this module did, so a bar it never colored is left alone.
        colored[bar] = nil
        if IsStatusAtlas(atlas) then
            SetAtlas(texture, atlas:sub(1, -#STATUS_SUFFIX - 1))
        end
        bar:SetStatusBarColor(DefaultColor(bar))
    end
end

-- Colors one health bar if it belongs to a unit frame in module.frames.
---@param bar SeamlessUnitframes.ClassColor.HealthBar?
local function Update(bar)
    local key = bar and FrameKey(bar.unitFrame)
    if not key then
        return
    end
    ---@cast bar SeamlessUnitframes.ClassColor.HealthBar
    if not known[bar] then
        known[bar] = true
        -- The game swaps the fill atlas on its own (target classification, vehicles, party art);
        -- put the white one back each time.
        hooksecurefunc(bar:GetStatusBarTexture(), "SetAtlas", function()
            if not settingAtlas then
                Apply(bar, key)
            end
        end)
    end
    Apply(bar, key)
end

function module:OnInitialize()
    -- Every unit frame runs this on a unit change and on max health changes.
    hooksecurefunc("UnitFrameHealthBar_Update", Update)
end

function module:OnEnable()
    self:Refresh()
end

-- Recolors every health bar, after a setting changed.
function module:Refresh()
    for _, entry in ipairs(module.frames) do
        local frame = entry.frameName and _G[entry.frameName]
        if frame then
            Update(frame.healthbar)
        end
    end
    if PartyFrame then
        for i = 1, MAX_PARTY_MEMBERS or 4 do
            local memberFrame = PartyFrame["MemberFrame" .. i]
            if memberFrame then
                Update(memberFrame.healthbar)
            end
        end
    end
    -- Party frames are pooled and may have been swapped; recolor every bar ever seen as well.
    for bar in pairs(known) do
        Update(bar)
    end
    log:debug("Class colors refreshed")
end

function module:OnProfileRefresh()
    self:Refresh()
end
