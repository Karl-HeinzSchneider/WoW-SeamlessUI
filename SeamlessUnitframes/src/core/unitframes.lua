---@type string, SeamlessUnitframes
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- The game's unit frames this addon changes. The options have a tab per entry and the
-- settings live in profile.unitFrames[key]; a feature finds its frames through here.
---@class SeamlessUnitframes.UnitFrames
local unitFrames = {}
app.unitFrames = unitFrames

---@class SeamlessUnitframes.UnitFrame
---@field key string  # the key in profile.unitFrames
---@field name string  # the label in the options
---@field frameName? string  # the global unit frame; nil for the party frames
---@field system? string  # its Enum.EditModeUnitFrameSystemIndices name, if it has an Edit Mode system
---@field linkedTo? string  # the key of the frame whose Edit Mode settings show this one's
---@field players? boolean  # shows player characters: name display and class icon apply
---@field pvpIcon? boolean  # has a PvP icon

-- A game unit frame, with the field UnitFrame_Initialize sets.
---@class SeamlessUnitframes.GameUnitFrame : Frame
---@field healthbar StatusBar?

-- In the order of the options tabs.
---@type SeamlessUnitframes.UnitFrame[]
unitFrames.list = {
    {
        key = "player",
        name = L["Player"],
        frameName = "PlayerFrame",
        system = "Player",
        players = true,
        pvpIcon = true,
    },
    { key = "pet", name = L["Pet"], frameName = "PetFrame", system = "Pet" },
    {
        key = "target",
        name = L["Target"],
        frameName = "TargetFrame",
        system = "Target",
        players = true,
        pvpIcon = true,
    },
    {
        key = "targettarget",
        name = L["Target of Target"],
        frameName = "TargetFrameToT",
        linkedTo = "target",
        players = true,
    },
    { key = "focus", name = L["Focus"], frameName = "FocusFrame", system = "Focus", players = true, pvpIcon = true },
    {
        key = "focustarget",
        name = L["Target of Focus"],
        frameName = "FocusFrameToT",
        linkedTo = "focus",
        players = true,
    },
    { key = "party", name = L["Party"], system = "Party", players = true, pvpIcon = true },
}

---@param key string
---@return SeamlessUnitframes.UnitFrame
function unitFrames:Get(key)
    for _, entry in ipairs(self.list) do
        if entry.key == key then
            return entry
        end
    end
    error("Unknown unit frame " .. tostring(key))
end

-- Whether this client has the frame (the party frames always count).
---@param entry SeamlessUnitframes.UnitFrame
function unitFrames:Exists(entry)
    return entry.frameName == nil or _G[entry.frameName] ~= nil
end

-- The key of the entry a unit frame belongs to, or nil for any other frame.
---@param unitFrame Frame?
---@return string?
function unitFrames:KeyOf(unitFrame)
    if (canaccessvalue and not canaccessvalue(unitFrame)) or not unitFrame then
        return nil
    end
    for _, entry in ipairs(self.list) do
        if entry.frameName and unitFrame == _G[entry.frameName] then
            return entry.key
        end
    end
    if PartyFrame then
        for i = 1, 4 do
            local member = PartyFrame["MemberFrame" .. i]
            if (not canaccessvalue or canaccessvalue(member)) and member == unitFrame then
                return "party"
            end
        end
    end
end

-- Every unit frame that exists right now. The party member frames are pooled and created when the
-- party frame first shows.
---@return SeamlessUnitframes.GameUnitFrame[]
function unitFrames:All()
    local frames = {}
    for _, entry in ipairs(self.list) do
        local frame = entry.frameName and _G[entry.frameName]
        if (not canaccessvalue or canaccessvalue(frame)) and frame then
            frames[#frames + 1] = frame
        end
    end
    if PartyFrame then
        for i = 1, 4 do
            local memberFrame = PartyFrame["MemberFrame" .. i]
            if (not canaccessvalue or canaccessvalue(memberFrame)) and memberFrame then
                frames[#frames + 1] = memberFrame
            end
        end
    end
    return frames
end
