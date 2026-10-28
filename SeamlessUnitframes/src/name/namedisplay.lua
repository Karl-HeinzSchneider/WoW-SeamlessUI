---@type string, SeamlessUnitframes
local _, app = ...

local addon = app.addon
local unitFrames = app.unitFrames

-- Shortens the name of player characters on the game's unit frames to the first name or the
-- surname, chosen per unit frame (profile.unitFrames[key].nameDisplay). The client gives
-- characters a first name and an optional surname (UnitName returns both); the game shows both.
-- NPCs always keep their name; a character without a surname keeps its first name.
-- The player frame also supports joined names and a character-specific custom name.
---@class SeamlessUnitframes.NameDisplay : AceModule
local module = {}
app.nameDisplay = addon:NewModule("NameDisplay", module) --[[@as SeamlessUnitframes.NameDisplay]]

-- The choices of profile.unitFrames[key].nameDisplay; labels live in the options pages.
---@alias SeamlessUnitframes.NameDisplayMode "full"|"first"|"last"|"combine"|"override"

-- The game's own text of each name we changed, keyed by frame, to put back for "full".
---@type table<Frame, string>
local native = {}

-- False for nil and for a secret value (the client hides a unit's identity in some situations).
local function Readable(value)
    return (not canaccessvalue or canaccessvalue(value)) and value ~= nil
end

-- The first name and surname of a unit. With regional unique names the client can return both in
-- the first value, joined by its surname separator.
---@param unit string
---@return string?, string?
local function NameParts(unit)
    local name, surname = UnitName(unit)
    if not Readable(name) or (surname ~= nil and not Readable(surname)) then
        return nil
    end
    if surname == nil or surname == "" then
        local separators = Constants and Constants.CharacterNameSeparatorConsts
        local separator = separators and separators.CHARACTERNAME_SURNAME_SEPARATOR
        if type(separator) == "string" and separator ~= "" then
            local first, rest = name:match("^(.-)" .. separator:gsub("%p", "%%%0") .. "(.+)$")
            if first and first ~= "" then
                return first, rest
            end
        end
        return name, nil
    end
    return name, surname
end

---@param frame Frame
---@param key string
local function Apply(frame, key)
    local fontString, unit = frame.name, frame.unit
    if not (Readable(fontString) and fontString and Readable(unit) and unit) then
        return
    end
    ---@type SeamlessUnitframes.NameDisplayMode
    local mode = app.db.profile.unitFrames[key].nameDisplay
    local text
    if mode ~= "full" and addon:IsEnabled() then
        if key == "player" and mode == "override" then
            local custom = app.db.char.nameOverride
            text = custom ~= "" and custom or nil
        else
            local isPlayer = UnitIsPlayer(unit)
            if Readable(isPlayer) and isPlayer then
                local first, surname = NameParts(unit)
                if key == "player" and mode == "combine" then
                    text = first and (first .. (surname or ""))
                else
                    text = mode == "first" and first or surname or first
                end
            end
        end
    end
    if not text then
        if native[frame] then
            fontString:SetText(native[frame])
            native[frame] = nil
        end
        return
    end
    if native[frame] == nil then
        local current = fontString:GetText()
        if not Readable(current) then
            return
        end
        native[frame] = current
    end
    fontString:SetText(text)
end

---@param frame Frame
local function Update(frame)
    local key = unitFrames:KeyOf(frame)
    if key then
        -- The game just set its own text; that is the one to put back.
        native[frame] = nil
        Apply(frame, key)
    end
end

function module:OnInitialize()
    -- Every unit frame sets its name here: on a unit change, a name update and party updates.
    hooksecurefunc("UnitFrame_Update", Update)
end

function module:ApplyPreview(frame, key)
    local fontString = frame.name
    local mode = app.db.profile.unitFrames[key].nameDisplay
    local character = app.previewCharacters and app.previewCharacters:Get(frame, key)
    if character then
        local separator = Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR
        local surname = character.surname ~= "" and character.surname or nil
        local full = character.name .. (surname and separator .. surname or "")
        fontString:SetText(mode == "first" and character.name or mode == "last" and (surname or character.name) or full)
        return
    end
    native[frame] = nil
    Apply(frame, key)
end

function module:OnEnable()
    self:Refresh()
end

function module:OnDisable()
    self:Refresh()
end

-- Reapplies every name, after a setting changed.
function module:Refresh()
    for _, frame in ipairs(unitFrames:All()) do
        local key = unitFrames:KeyOf(frame)
        if key then
            Apply(frame, key)
        end
    end
end

function module:OnProfileRefresh()
    self:Refresh()
end
