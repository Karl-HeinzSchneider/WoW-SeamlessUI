---@type string, SeamlessUnitframes
local _, app = ...

-- The game's unit frames this addon changes. The options have a health bar color per entry and the
-- settings live in profile.unitFrames[key]; a feature finds its frames through here.
---@class SeamlessUnitframes.UnitFrames
local unitFrames = {}
app.unitFrames = unitFrames

---@class SeamlessUnitframes.UnitFrame
---@field key string  # the key in profile.unitFrames
---@field name string  # the label in the options
---@field frameName? string  # the global unit frame; nil for the party frames

-- A game unit frame, with the field UnitFrame_Initialize sets.
---@class SeamlessUnitframes.GameUnitFrame : Frame
---@field healthbar StatusBar?

-- In the order of the options.
---@type SeamlessUnitframes.UnitFrame[]
unitFrames.list = {
    { key = "player", name = "Player", frameName = "PlayerFrame" },
    { key = "pet", name = "Pet", frameName = "PetFrame" },
    { key = "target", name = "Target", frameName = "TargetFrame" },
    { key = "targettarget", name = "Target of Target", frameName = "TargetFrameToT" },
    { key = "focus", name = "Focus", frameName = "FocusFrame" },
    { key = "focustarget", name = "Target of Focus", frameName = "FocusFrameToT" },
    { key = "party", name = "Party" },
}

-- Whether this client has the frame (the party frames always count).
---@param entry SeamlessUnitframes.UnitFrame
function unitFrames:Exists(entry)
    return entry.frameName == nil or _G[entry.frameName] ~= nil
end

-- The key of the entry a unit frame belongs to, or nil for any other frame.
---@param unitFrame Frame?
---@return string?
function unitFrames:KeyOf(unitFrame)
    if not unitFrame then
        return nil
    end
    for _, entry in ipairs(self.list) do
        if entry.frameName and unitFrame == _G[entry.frameName] then
            return entry.key
        end
    end
    if PartyFrame and unitFrame:GetParent() == PartyFrame then
        return "party"
    end
end

-- Every unit frame that exists right now. The party member frames are pooled and created when the
-- party frame first shows.
---@return SeamlessUnitframes.GameUnitFrame[]
function unitFrames:All()
    local frames = {}
    for _, entry in ipairs(self.list) do
        local frame = entry.frameName and _G[entry.frameName]
        if frame then
            frames[#frames + 1] = frame
        end
    end
    if PartyFrame then
        for i = 1, MAX_PARTY_MEMBERS or 4 do
            local memberFrame = PartyFrame["MemberFrame" .. i]
            if memberFrame then
                frames[#frames + 1] = memberFrame
            end
        end
    end
    return frames
end
