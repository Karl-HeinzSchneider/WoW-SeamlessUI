---@type string, SeamlessUnitframes
local _, app = ...

-- Decides whether a unit is still needed by one of your quests and which icon to show for it.
--
-- Whether the unit is needed comes from the same tooltip data the default tooltip renders its quest
-- objective lines from (C_TooltipInfo.GetUnit), so icon and tooltip always agree. Which icon to use
-- comes from matching that objective text against the quest log (C_QuestLog.GetQuestObjectives):
-- "monster" objectives get the slay icon, everything else the loot icon.
---@class SeamlessUnitframes.QuestIcons
local questIcons = {}
app.questIcons = questIcons

local function accessible(value)
    return not canaccessvalue or canaccessvalue(value)
end

---@alias SeamlessUnitframes.QuestIconKey "slay"|"loot"

---@class SeamlessUnitframes.QuestIconDef
---@field texture string
---@field coords number[]  # left, right, top, bottom

-- The crosshair cursor textures are 512x256 sprite sheets with the cursor at several sizes plus a
-- greyed-out variant; the texcoords pick the largest (128px) sprite in the top-left cell.
---@type table<SeamlessUnitframes.QuestIconKey, SeamlessUnitframes.QuestIconDef>
questIcons.ICONS = {
    slay = { texture = "Interface\\Cursor\\Crosshair\\UIAttackCrosshair2x", coords = { 0, 0.25, 0, 0.5 } },
    loot = {
        -- Alternative, a loot sack:
        -- texture = "Interface\\Cursor\\Crosshair\\UILootAllCrosshair2x",
        -- coords = { 0.0390625, 0.2578125, 0.05859375, 0.49609375 },
        texture = "Interface\\Cursor\\Crosshair\\UIBuyCrosshair2x",
        coords = { 0.029296875, 0.255859375, 0.03125, 0.484375 },
    },
}

-- Objective text -> objective type ("monster", "item", "object", "event", ...) for every
-- unfinished objective in the quest log.
---@return table<string, string>
local function collectObjectiveTypes()
    local types = {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader then
            for _, objective in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
                if objective.text and objective.text ~= "" and not objective.finished then
                    types[objective.text] = objective.type
                end
            end
        end
    end
    return types
end

-- Tooltip lines may carry a "- " list prefix; the quest log text does not.
---@param text string
---@return string
local function normalize(text)
    return (text:gsub("^%s*%-%s*", ""):gsub("%s+$", ""))
end

-- The icon key for a unit, or nil while no quest needs it.
---@param unit string  # unit token, e.g. "target" or "nameplate3"
---@return SeamlessUnitframes.QuestIconKey|nil
function questIcons:ForUnit(unit)
    if not UnitExists(unit) then
        return nil
    end
    local data = C_TooltipInfo.GetUnit(unit)
    if not data or not data.lines then
        return nil
    end

    local types
    for _, line in ipairs(data.lines) do
        -- Restricted tooltip fields cannot be used for branching or text matching.
        -- Skip objectives whose completion is unknown rather than guessing they are needed.
        if
            accessible(line.type)
            and line.type == Enum.TooltipDataLineType.QuestObjective
            and accessible(line.completed)
            and not line.completed
        then
            types = types or collectObjectiveTypes()
            local objectiveType = accessible(line.leftText) and line.leftText and types[normalize(line.leftText)]
            -- Unknown objective text (no quest log match) falls back to the loot icon.
            return objectiveType == "monster" and "slay" or "loot"
        end
    end
    return nil
end

-- A square icon frame above `parent`'s art; size and anchor are left to the caller.
---@param parent Frame
---@return Frame frame, Texture icon
function questIcons:CreateFrame(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(11)
    frame:EnableMouse(false)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    frame.Icon = icon
    return frame, icon
end

-- Shows `frame` with the icon for `key`, or hides it when key is nil.
---@param frame Frame  # from questIcons:CreateFrame
---@param key SeamlessUnitframes.QuestIconKey|nil
function questIcons:SetIcon(frame, key)
    if key then
        local def = self.ICONS[key]
        frame.Icon:SetTexture(def.texture)
        frame.Icon:SetTexCoord(unpack(def.coords))
        frame:Show()
    else
        frame.Icon:SetTexture(nil)
        frame:Hide()
    end
end
