-- Run from the repository root: lua src/tests/damage-meter-windows.lua
unpack = unpack or table.unpack
local methods = {}
local expandedScrollChild
local meterGroupRow
local function object(parent)
    return setmetatable({ parent = parent, scripts = {}, width = 400, height = 200, shown = true }, {
        __index = function(_, key)
            if methods[key] then
                return methods[key]
            end
            if key:match("^[A-Z]") then
                return function() end
            end
        end,
    })
end
function methods:SetScript(event, callback)
    self.scripts[event] = callback
end
function methods:GetScript(event)
    return self.scripts[event]
end
function methods:CreateTexture()
    return object(self)
end
function methods:CreateFontString()
    return object(self)
end
function methods:SetFont(path, size, flags)
    self.font = { path, size, flags }
end
function methods:SetParent(parent)
    self.parent = parent
end
function methods:GetParent()
    return self.parent
end
function methods:GetFrameLevel()
    return self.frameLevel or 1
end
function methods:SetFrameLevel(level)
    self.frameLevel = level
end
function methods:EnableMouse(enabled)
    self.mouseEnabled = enabled
end
function methods:SetFrameStrata(strata)
    self.frameStrata = strata
end
function methods:GetFrameStrata()
    return self.frameStrata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM"
end
function methods:SetAlpha(alpha)
    self.alpha = alpha
end
function methods:StartSizing(corner)
    self.sizing = corner
end
function methods:StopMovingOrSizing()
    self.sizing = nil
end
function methods:SetPoint(...)
    self.point = { ... }
    self.points = self.points or {}
    self.points[self.point[1]] = self.point
end
function methods:SetText(text)
    self.text = text
end
function methods:GetStringWidth()
    return #(self.text or "") * 7
end
function methods:SetJustifyH(justification)
    self.justifyH = justification
end
function methods:SetFormattedText(format, ...)
    self.format, self.args = format, { ... }
end
function methods:SetNormalAtlas(atlas)
    self.normalAtlas = atlas
end
function methods:SetAtlas(atlas)
    self.atlas = atlas
end
function methods:SetTexture(texture)
    self.texture = texture
end
function methods:SetStatusBarTexture(texture)
    self.fill = texture
end
function methods:SetStatusBarColor(...)
    self.color = { ... }
end
function methods:SetWidth(width)
    self.width = width
end
function methods:SetHeight(height)
    self.height = height
    if self.scripts.OnSizeChanged then
        self.scripts.OnSizeChanged(self)
    end
end
function methods:SetVerticalScroll(offset)
    self.verticalScroll = offset
end
function methods:GetVerticalScroll()
    return self.verticalScroll or 0
end
function methods:GetVerticalScrollRange()
    return math.max(0, (self.scrollChild and self.scrollChild:GetHeight() or 0) - self:GetHeight())
end
function methods:SetScrollChild(child)
    self.scrollChild = child
end
function methods:SetSize(width, height)
    self.width = width
    self:SetHeight(height)
end
function methods:SetResizeBounds(_, minHeight)
    if self.height < minHeight then
        self:SetHeight(minHeight)
    end
end
function methods:GetWidth()
    return self.width
end
function methods:GetHeight()
    return self.height
end
function methods:GetSize()
    return self.width, self.height
end
function methods:GetCenter()
    return 0, 0
end
function methods:GetTop()
    return 100
end
function methods:GetLeft()
    return -self.width / 2
end
function methods:GetRight()
    return self.width / 2
end
function methods:GetBottom()
    return 100 - self.height
end
function methods:GetEffectiveScale()
    return self.scale or 1
end
function methods:SetScale(scale)
    self.scale = scale
end
function methods:SetValue(value)
    self.statusValue = value
    if self.scripts.OnValueChanged then
        self.scripts.OnValueChanged(self, value)
    end
end
function methods:SetMinMaxValues(minimum, maximum)
    self.minimum, self.maximum = minimum, maximum
end
function methods:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then
        self.scripts.OnHide(self)
    end
end
function methods:Show()
    self.shown = true
end
function methods:SetShown(shown)
    self.shown = shown
end
function methods:IsShown()
    return self.shown
end

UIParent = object()
function CreateFrame(_, name, parent, template)
    assert(
        template == nil or (template == "ResizeCheckButtonTemplate" and parent == expandedScrollChild),
        "Only the Edit Mode group checkbox may inherit a template"
    )
    local frame = object(parent)
    if template == "ResizeCheckButtonTemplate" then
        assert(not meterGroupRow, "Only one group checkbox may be created")
        meterGroupRow = frame
        frame.Button, frame.Label = object(frame), object(frame)
    end
    if name then
        assert(_G[name] == nil, "Named frames must be reused")
        _G[name] = frame
    end
    return frame
end
RAID_CLASS_COLORS = { MAGE = { r = 0.2, g = 0.5, b = 1 } }
FACTION_BAR_COLORS = { [4] = { r = 1, g = 1, b = 0 }, [5] = { r = 0, g = 0.6, b = 0.1 } }
DAMAGE_METER_CURRENT_SESSION_SHORT = "C"
DAMAGE_METER_OVERALL_SESSION_SHORT = "O"
DAMAGE_METER_SOURCE_NAME = "%d. %s"
Enum = { DamageMeterSessionType = { Current = 0, Overall = 1 }, DamageMeterType = { DamageDone = 0, Dps = 1 } }
function GetClassAtlas(class)
    return class
end
function UnitAffectingCombat()
    return false
end
function SecondsToClock(seconds)
    return tostring(seconds)
end
local secret = setmetatable({}, {
    __lt = function()
        error("Secret comparison")
    end,
    __le = function()
        error("Secret comparison")
    end,
    __add = function()
        error("Secret arithmetic")
    end,
    __div = function()
        error("Secret arithmetic")
    end,
    __concat = function()
        error("Secret concatenation")
    end,
})
function issecretvalue(value)
    return value == secret
end
function AbbreviateLargeNumbers(value)
    assert(value ~= secret, "Secret amounts must go directly to a widget")
    return tostring(value)
end

local session = { combatSources = {}, maxAmount = secret, durationSeconds = 10 }
for index = 1, 12 do
    session.combatSources[index] = {
        name = secret,
        totalAmount = secret,
        amountPerSecond = secret,
        classFilename = "MAGE",
        specIconID = 0,
        isLocalPlayer = index == 12,
    }
end
local reads = 0
local lastSessionType, lastMeterType, lastSessionID
local history = {}
C_DamageMeter = {
    GetCombatSessionFromType = function(sessionType, meterType)
        lastSessionType, lastMeterType, lastSessionID = sessionType, meterType, nil
        reads = reads + 1
        return session
    end,
    GetCombatSessionFromID = function(sessionID, meterType)
        lastSessionID, lastMeterType = sessionID, meterType
        return session
    end,
    IsDamageMeterAvailable = function()
        return true
    end,
    GetAvailableCombatSessions = function()
        return history
    end,
}
local liveAPI = C_DamageMeter
C_CVar = {
    GetCVarBool = function()
        return true
    end,
}
local app = { db = { profile = { windows = {}, nextID = 1, initialized = false } } }
NumberFontNormal = {
    GetFont = function()
        return "native-meter-font", 14, "OUTLINE"
    end,
}
LibStub = function()
    return {
        Fetch = function()
            return "test-font"
        end,
    }
end
assert(loadfile("SeamlessDamageMeter/src/settings.lua"))("SeamlessDamageMeter", app)
app.db.profile.windowDefaults = app.windowDefaults
assert(app.windowDefaults.fixedHeight and app.windowDefaults.visibleLines == 7)
app.db.profile.windowDefaults.fixedHeight = false
assert(loadfile("SeamlessDamageMeter/src/data.lua"))("SeamlessDamageMeter", app)
for _, name in ipairs({ "archive", "live", "service", "breakdowns", "capture" }) do
    assert(loadfile("SeamlessDamageMeter/src/" .. name .. ".lua"))("SeamlessDamageMeter", app)
end
app.combatService:Initialize({})
assert(loadfile("SeamlessDamageMeter/src/windows.lua"))("SeamlessDamageMeter", app)
app:RebuildWindows()
local frame = app.windows[1]
assert(frame.message.font[1] == "native-meter-font", "Default text uses the client's damage meter font")
app.db.profile.skins.default.settings.font = "Custom font"
app:StyleWindowLabel(frame.message, frame.config)
assert(frame.message.font[1] == "test-font", "Custom skin fonts still resolve through shared media")
app.db.profile.skins.default.settings.font = "Default damage meter"
assert(frame.statistic.arrow:IsShown() and frame.statistic.mouseEnabled, "Type selector is visible by default")
local categoryAnchor = frame.statistic.text.points.TOPLEFT
assert(categoryAnchor[4] == 25 and categoryAnchor[5] == -9, "Category text must sit at the reference header height")
local categoryWidth = frame.statistic.text:GetWidth()
app.db.profile.skins.default.settings.hideTypeSelector = true
app:RebuildWindows()
assert(not frame.statistic.arrow:IsShown() and not frame.statistic.mouseEnabled)
for index, value in ipairs(categoryAnchor) do
    assert(
        frame.statistic.text.points.TOPLEFT[index] == value,
        "Hiding the selector must preserve the category position"
    )
end
assert(frame.statistic.text:GetWidth() == categoryWidth)
assert(
    frame.timer:GetWidth() == 0 and frame.timer.justifyH == "LEFT",
    "Timer must use natural width and left alignment"
)
assert(frame.statistic.text.text == "Damage done", "Hiding the selector retains the category label")
app.db.profile.skins.default.settings.hideTypeSelector = false
app:RebuildWindows()
assert(frame.statistic.arrow:IsShown() and frame.statistic.mouseEnabled, "Selector can be restored")
assert(frame.statistic.points.TOPLEFT[2] == frame and frame.statistic.points.TOPLEFT[4] == 3)
assert(frame.timer.points.LEFT[2] == frame.statistic.text, "Timer follows the category label")
assert(frame.timer:IsShown(), "Combat timer is visible by default")
app.db.profile.skins.default.settings.hideCombatTimer = true
app:RebuildWindows()
assert(not frame.timer:IsShown(), "Combat timer inherits the shared hide setting")
app.db.profile.skins.default.settings.hideCombatTimer = false
app:RebuildWindows()
assert(frame.timer:IsShown(), "A skin edit restores the combat timer")
app.db.profile.skins.default.settings.hideCombatTimer = true
app:RebuildWindows()
assert(not frame.timer:IsShown(), "A skin edit hides the combat timer")
app.db.profile.skins.default.settings.hideCombatTimer = false
app:RebuildWindows()
assert(#app.windows == 10 and #app.db.profile.windows == 10, "Every slot must exist from startup")
for id = 2, 10 do
    assert(app.windowFrames[id] and not app.windowFrames[id]:IsShown())
end
assert(SeamlessDamageMeterWindow1 == frame and frame.windowID == 1)
app.db.profile.skins.default.settings.showIcons = false
app:RebuildWindows()
assert(not frame.rows[1].icon:IsShown() and frame.rows[1].points.TOPLEFT[2] == 0)
app.db.profile.skins.default.settings.showIcons = true
app:RebuildWindows()
assert(frame.rows[1].icon:IsShown() and frame.rows[1].points.TOPLEFT[2] == 24)
assert(frame.rows[1]:GetHeight() == 24 and frame.rows[1].entry:GetHeight() == 24)
assert(frame.rows[1].icon:GetWidth() == 24 and frame.rows[1].icon:GetHeight() == 24)
assert(frame:IsShown() and frame.scrollbar:IsShown())
assert(frame.rows[1].name.args[2] == secret)
assert(frame.rows[1].value.args[1] == secret)
assert(frame.rows[1].secondaryValue.args[1] == secret, "Restricted rates must go directly to their column")
assert(frame.rows[1].points.TOPLEFT[2] == 24, "Bar must start immediately after its icon inside the list inset")
assert(frame.localRow:IsShown(), "Offscreen local player must stay visible")
-- Hover details use the selected source/session and accept restricted values unchanged.
C_Spell = {
    GetSpellName = function()
        return "Fireball"
    end,
    GetSpellTexture = function(id)
        return 1000 + id
    end,
}
local sourceReads, detailGUID, detailCreature = 0
local details = {
    totalAmount = secret,
    maxAmount = secret,
    combatSpells = { { spellID = 1, totalAmount = secret, amountPerSecond = secret } },
}
C_DamageMeter.GetCombatSessionSourceFromType = function(sessionType, meterType, guid, creature)
    assert(
        sessionType == Enum.DamageMeterSessionType.Current and meterType == Enum.DamageMeterType[frame.config.statistic]
    )
    sourceReads = sourceReads + 1
    detailGUID, detailCreature = guid, creature
    return details
end
session.combatSources[1].sourceGUID = "player-1"
local hoverCombatState = UnitAffectingCombat
UnitAffectingCombat = function()
    return true
end
frame.rows[1].entry.scripts.OnEnter()
assert(sourceReads == 1 and detailGUID == "player-1")
local tooltip = app.detailTooltip
local detailBar = tooltip.rows[1]
frame.rows[1].entry.scripts.OnMouseUp(nil, "LeftButton")
assert(
    frame.detail and frame.rows[1].statusValue == secret and frame.rows[1].value.args[1] == secret,
    "Nested bars pass restricted amounts directly to widgets"
)
assert(frame.statistic.text.args[1] == secret, "Nested names go directly to the header")
app.db.profile.skins.default.settings.hideTypeSelector = true
app:RefreshWindows()
assert(
    not frame.statistic.arrow:IsShown() and not frame.statistic.mouseEnabled,
    "Nested view respects the hidden type selector setting"
)
frame:GetScript("OnMouseUp")(frame, "RightButton")
assert(
    not frame.detail and not frame.statistic.arrow:IsShown(),
    "Right-click returns from nested view while the type selector stays hidden"
)
app.db.profile.skins.default.settings.hideTypeSelector = false
app:RefreshWindows()
frame.rows[1].entry.scripts.OnMouseUp(nil, "LeftButton")
frame.statistic.scripts.OnClick()
frame.rows[1].entry.scripts.OnEnter()

assert(tooltip.owner == frame.rows[1] and tooltip:GetFrameStrata() == "TOOLTIP")
assert(tooltip.header == nil and tooltip.title == nil, "The detail panel has no header")
assert(tooltip.points.BOTTOMLEFT[2] == frame.rows[1].entry and tooltip.points.BOTTOMLEFT[3] == "TOPLEFT")
assert(tooltip.points.BOTTOMRIGHT[2] == frame.rows[1].entry and tooltip.points.BOTTOMRIGHT[3] == "TOPRIGHT")
assert(tooltip.points.BOTTOMLEFT[4] == 0 and tooltip.points.BOTTOMLEFT[5] == 0)
assert(
    tooltip.points.BOTTOMRIGHT[4] == 0 and tooltip.points.BOTTOMRIGHT[5] == 0,
    "Panel matches the bar edges above it"
)
assert(detailBar.value.args[1] == secret and detailBar.secondaryValue.args[1] == secret)
assert(detailBar.percentageValue.text == "", "Restricted percentage inputs stay blank")
assert(detailBar.maximum == secret and detailBar.statusValue == secret, "Restricted bar scales go to widget setters")
assert(detailBar.fill.texture == frame.rows[1].fill.texture, "Detail and main bars share the exact texture")
assert(detailBar.icon.texture == 1001, "Spell icons come from C_Spell")
assert(detailBar:GetHeight() == frame.rows[1]:GetHeight() and detailBar.icon:GetWidth() == 24)
assert(detailBar.color[1] == RAID_CLASS_COLORS.MAGE.r)
assert(
    detailBar.color[2] == RAID_CLASS_COLORS.MAGE.g
        and detailBar.color[3] == RAID_CLASS_COLORS.MAGE.b
        and detailBar.color[4] == 1,
    "Class bars use unmodified class RGB at full opacity"
)
assert(
    not tooltip.targetLabel:IsShown() and not tooltip.targetMessage:IsShown() and tooltip.count == 1,
    "Combat hover shows only normal spells, without an unavailable target section"
)
assert(detailBar.entry.points.TOPLEFT[3] == 0, "First bar begins at the top with no header gap")
assert(
    not tooltip.mouseEnabled and not detailBar.entry.mouseEnabled,
    "The hover panel does not steal the owner's mouse"
)
local readsBeforeRefresh = sourceReads
app:RefreshWindows()
assert(tooltip:IsShown() and sourceReads == readsBeforeRefresh + 1, "Live refresh preserves and updates the hover")
UnitAffectingCombat = hoverCombatState
frame.rows[1].entry.scripts.OnLeave()
assert(not tooltip:IsShown() and tooltip.owner == nil)
app:RefreshWindows()
assert(not tooltip:IsShown(), "Refresh must not reopen a tooltip after leaving")
session.combatSources[12].sourceCreatureID = 42
frame.localRow.entry.scripts.OnEnter()
assert(app.detailTooltip ~= tooltip and app.detailTooltip == app.postCombatTooltip)
tooltip = app.detailTooltip
assert(detailCreature == 42, "Pinned rows support creature source IDs")
assert(tooltip.points.BOTTOMLEFT[2] == frame.localRow.entry and tooltip.points.BOTTOMRIGHT[2] == frame.localRow.entry)
frame.localRow.entry.scripts.OnLeave()
details.totalAmount = 100
details.combatSpells[1].totalAmount, details.combatSpells[1].amountPerSecond = 25, 5
frame.rows[1].entry.scripts.OnEnter()
detailBar = tooltip.rows[1]
assert(detailBar.percentageValue.args[1] == 25, "Public spell shares occupy a separate percentage column")
assert(app.detailTooltip == tooltip and tooltip.rows[1] == detailBar, "The panel and its bars are pooled")
details.combatSpells[1].combatSpellDetails = { specIconID = 777, unitClassFilename = "MAGE", unitName = secret }
app:RefreshWindows()
assert(detailBar.icon.texture == 777, "API specialization icon takes precedence")
assert(detailBar.name.args[2] == secret, "Restricted detail names go directly to labels")
details.combatSpells[1].combatSpellDetails.specIconID = 0
app:RefreshWindows()
assert(detailBar.icon.atlas == "MAGE", "API unit class supplies an icon when there is no specialization")
details.combatSpells[1].combatSpellDetails = nil
frame.config.statistic = "Dps"
app:RefreshWindows()
assert(detailBar.value.text == "5" and detailBar.secondaryValue.text == "25", "DPS uses rate before total")
frame.config.statistic = "DamageDone"
app.db.profile.skins.default.settings.rowHeight, app.db.profile.skins.default.settings.rowSpacing = 30, 6
app.db.profile.skins.default.settings.classColors = false
app:RefreshWindows()
assert(
    detailBar:GetHeight() == 30 and detailBar.icon:GetWidth() == 30,
    "Detail rows inherit owner appearance overrides"
)
assert(detailBar.color[1] == app:GetWindowSetting(frame.config, "barColor")[1])
app.db.profile.skins.default.settings.rowHeight, app.db.profile.skins.default.settings.rowSpacing, app.db.profile.skins.default.settings.classColors =
    24, 4, true
app:RefreshWindows()
frame.rows[1].entry.scripts.OnLeave()
assert(details.combatSpells[1].name == nil, "Returned spell tables stay untouched")
history = { { sessionID = 77 } }
C_DamageMeter.GetCombatSessionSourceFromID = function(id, meterType, guid)
    assert(id == 77 and meterType == 0 and guid == "player-1")
    return details
end
frame.config.sessionID = 77
frame.config.sessionGeneration = app.combatService.generation
frame.rows[1].entry.scripts.OnEnter()
assert(tooltip:IsShown(), "History hover uses the ID API")
history = {}
app:RefreshWindows()
assert(not tooltip:IsShown(), "Expired history dismisses hover details")
frame.config.sessionID = nil
app:RefreshWindows()
frame.rows[1].preview = true
local beforePreview = sourceReads
frame.rows[1].entry.scripts.OnEnter()
assert(sourceReads == beforePreview and not tooltip:IsShown(), "Preview hover never reads live details")
frame.rows[1].preview = nil
local firstSpell = details.combatSpells[1]
for index = 2, 20 do
    details.combatSpells[index] = { spellID = index, totalAmount = 25, amountPerSecond = 5 }
end
frame.rows[1].entry.scripts.OnEnter()
assert(tooltip.capacity < tooltip.count and tooltip:GetHeight() <= UIParent:GetHeight() * 0.75)
local mainOffset = frame.offset
frame.rows[1].entry.scripts.OnMouseWheel(frame.rows[1].entry, -1)
assert(tooltip.offset == 3 and tooltip.rows[1].icon.texture == 1004, "Wheel reaches later detail bars in API order")
assert(frame.offset == mainOffset, "Scrolling a long breakdown keeps its source row in place")
app:RefreshWindows()
assert(tooltip.offset == 3, "Live refresh preserves detail scrolling")
frame.rows[1].entry.scripts.OnMouseUp(nil, "LeftButton")
assert(frame.detail and frame.rows[1].icon.texture == 1001, "Click replaces character rows with spells")
assert(not tooltip:IsShown(), "Nested view dismisses the hover panel")
frame:GetScript("OnMouseWheel")(frame, -1)
assert(frame.offset == 3 and frame.rows[1].icon.texture == 1004, "Nested spells use normal window scrolling")
app:RefreshWindows()
assert(frame.detail and frame.offset == 3, "Refresh preserves nested view and scrolling")
local originalSource = session.combatSources[1]
local refreshedSource = {}
for key, value in pairs(originalSource) do
    refreshedSource[key] = value
end
session.combatSources[1], session.combatSources[2] = session.combatSources[2], refreshedSource
app:RefreshWindows()
assert(
    frame.detail.source == refreshedSource and frame.rows[1].icon.texture == 1004,
    "Nested selection follows public identity across new API tables and rank changes"
)
session.combatSources[1], session.combatSources[2] = originalSource, session.combatSources[1]
app:RefreshWindows()
local unavailableSource = {}
for key, value in pairs(originalSource) do
    unavailableSource[key] = value
end
unavailableSource.sourceGUID = secret
session.combatSources[1] = unavailableSource
app:RefreshWindows()
assert(
    frame.detail and frame.message.text == "This source is no longer available.",
    "Restricted identities never select a different row by rank or name"
)
session.combatSources[1] = originalSource
app:RefreshWindows()

frame:GetScript("OnMouseUp")(frame, "RightButton")
assert(not frame.detail and frame.offset == mainOffset, "Back restores category scrolling")
frame.rows[1].entry.scripts.OnEnter()

details.combatSpells = { firstSpell }
app:RefreshWindows()
assert(tooltip.offset == 0 and not tooltip.rows[2]:IsShown(), "Shrinking detail lists hide pooled surplus bars")
details.combatSpells = {}
app:RefreshWindows()
assert(tooltip.targetMessage:IsShown(), "Empty details explain unavailable data")
details.combatSpells = { firstSpell }
frame.rows[1].entry.scripts.OnEnter()
frame.rows[1].entry.scripts.OnHide()
assert(not tooltip:IsShown(), "Hiding the owner entry dismisses the panel")
-- Per-target totals must combine every spell without mutating the API tables.
local savedSpells, savedTotal, savedMaximum = details.combatSpells, details.totalAmount, details.maxAmount
UIParent:SetHeight(800)
details.totalAmount, details.maxAmount = 100, 50
details.combatSpells = {
    {
        spellID = 1,
        totalAmount = 30,
        amountPerSecond = 3,
        combatSpellDetails = { unitName = "Wolf", amount = 30, specIconID = 777 },
    },
    { spellID = 2, totalAmount = 20, amountPerSecond = 2, combatSpellDetails = { unitName = "Wolf", amount = 20 } },
    { spellID = 3, totalAmount = 50, amountPerSecond = 5, combatSpellDetails = { unitName = "Bear", amount = 50 } },
}
local oldSessionAPI, oldDetailsAPI =
    C_DamageMeter.GetCombatSessionFromType, C_DamageMeter.GetCombatSessionSourceFromType
local enemySession = {
    totalAmount = 100,
    maxAmount = 50,
    durationSeconds = 10,
    combatSources = {
        { name = "Wolf", sourceCreatureID = 1, totalAmount = 50, amountPerSecond = 5, specIconID = 777 },
        { name = "Bear", sourceCreatureID = 2, totalAmount = 50, amountPerSecond = 5 },
    },
}
local enemyReads = 0
Enum.DamageMeterType.EnemyDamageTaken = 10
local enemyDetails = {
    {
        totalAmount = 50,
        maxAmount = 30,
        combatSpells = {
            {
                spellID = 1,
                totalAmount = 30,
                amountPerSecond = 3,
                combatSpellDetails = { unitName = "Player", amount = 30 },
            },
            {
                spellID = 2,
                totalAmount = 20,
                amountPerSecond = 2,
                combatSpellDetails = { unitName = "Player", amount = 20 },
            },
        },
    },
    {
        totalAmount = 50,
        maxAmount = 50,
        combatSpells = {
            {
                spellID = 3,
                totalAmount = 50,
                amountPerSecond = 5,
                combatSpellDetails = { unitName = "Player", amount = 50 },
            },
        },
    },
}
C_DamageMeter.GetCombatSessionFromType = function(kind, meterType)
    if meterType == 10 then
        enemyReads = enemyReads + 1
        return enemySession
    end
    return oldSessionAPI(kind, meterType)
end
C_DamageMeter.GetCombatSessionSourceFromType = function(kind, meterType, guid, creature)
    if meterType == 10 then
        enemyReads = enemyReads + 1
        return enemyDetails[creature]
    end
    return oldDetailsAPI(kind, meterType, guid, creature)
end
local savedName, savedAmount = session.combatSources[1].name, session.combatSources[1].totalAmount
session.combatSources[1].name, session.combatSources[1].totalAmount = "Player", 100
app.combatService:Invalidate()
local breakdown = app:GetTargetBreakdown(frame.config, session.combatSources[1])
assert(
    #breakdown.entries == 2 and breakdown.entries[1].spellName == "Bear" and breakdown.entries[2].spellName == "Wolf"
)
assert(breakdown.complete and breakdown.maxAmount == 50 and breakdown.entries[2].enemyShare == 100)
frame.rows[1].entry.scripts.OnEnter()
assert(tooltip.count == 6 and tooltip.targetLabel:IsShown() and not tooltip.targetMessage:IsShown())
assert(tooltip.rows[5].name.text == "Bear" and tooltip.rows[6].name.text == "Wolf")
assert(tooltip.rows[5].statusValue == 50 and tooltip.rows[6].statusValue == 50)
assert(tooltip.rows[5].value.text == "50" and tooltip.rows[5].secondaryValue.text == "5")
assert(tooltip.rows[5].percentageValue.args[1] == 50 and tooltip.rows[5].enemyPercentageValue.args[1] == 100)
assert(
    tooltip.rows[1].value:GetWidth() == tooltip.rows[5].value:GetWidth()
        and tooltip.rows[1].value.points.RIGHT[4] == tooltip.rows[5].value.points.RIGHT[4],
    "Spells and targets share numeric column widths and offsets"
)
assert(tooltip.rows[6].icon.texture == 777)
local availableEnemyReads = enemyReads
UnitAffectingCombat = function()
    return true
end
enemySession.combatSources[1].totalAmount = secret
app.combatService:Invalidate()
app:RefreshWindows()
local richTooltip = tooltip
tooltip = app.detailTooltip
assert(tooltip == app.combatSpellTooltip and tooltip ~= richTooltip and not richTooltip:IsShown())
assert(
    tooltip.count == 3 and not tooltip.targetLabel:IsShown() and not tooltip.targetMessage:IsShown(),
    "Entering combat removes available targets without replacing spell bars"
)
assert(enemyReads == availableEnemyReads, "Combat hover never queries target analysis")
assert(
    not tooltip.rows[1].enemyPercentageValue:IsShown() and not richTooltip:IsShown(),
    "Pooled target columns and rows disappear in combat"
)
enemySession.combatSources[1].totalAmount = 50
app.combatService:Invalidate()
app:RefreshWindows()
assert(
    tooltip.count == 3 and not tooltip.targetLabel:IsShown(),
    "Combat hover stays spell-only even with public targets"
)
UnitAffectingCombat = hoverCombatState
frame.config.statistic = "Dps"
app:RefreshWindows()
assert(not tooltip:IsShown() and app.detailTooltip == richTooltip, "Leaving combat switches back to the richer pool")
tooltip = app.detailTooltip
assert(
    tooltip.rows[5].value.text == "5" and tooltip.rows[5].secondaryValue.text == "50",
    "Targets preserve the same rate/amount column order as spells in DPS view"
)
frame.config.statistic = "DamageDone"
session.combatSources[1].totalAmount = 120
assert(not app:GetTargetBreakdown(frame.config, session.combatSources[1]).complete, "Partial totals are labelled")
session.combatSources[1].totalAmount = 100
enemyDetails[1].combatSpells[1].combatSpellDetails.unitName = secret
app.combatService:Invalidate()
assert(app:GetTargetBreakdown(frame.config, session.combatSources[1]) == nil, "Restricted identities cannot be grouped")
enemyDetails[1].combatSpells[1].combatSpellDetails.unitName = "Player"
enemyDetails[1].combatSpells[1].totalAmount = secret
app.combatService:Invalidate()
assert(
    app:GetTargetBreakdown(frame.config, session.combatSources[1]) == nil,
    "Restricted contributions cannot be added"
)
app:RefreshWindows()
assert(
    not tooltip.targetLabel:IsShown()
        and not tooltip.targetMessage:IsShown()
        and not tooltip.rows[5]:IsShown()
        and tooltip.count == 3,
    "Unavailable targets disappear while the normal spell breakdown remains"
)
session.combatSources[1].name, session.combatSources[1].totalAmount = savedName, savedAmount
C_DamageMeter.GetCombatSessionFromType, C_DamageMeter.GetCombatSessionSourceFromType = oldSessionAPI, oldDetailsAPI
app.combatService:Invalidate()
frame.rows[1].entry.scripts.OnLeave()
details.combatSpells, details.totalAmount, details.maxAmount = savedSpells, savedTotal, savedMaximum
UIParent:SetHeight(200)
local recapID
C_DeathRecap = {
    GetRecapEvents = function(id)
        recapID = id
        return { { event = "SWING_DAMAGE", amount = secret, sourceName = secret } }
    end,
    GetRecapMaxHealth = function(id)
        assert(id == 99)
        return secret
    end,
}
Enum.DamageMeterType.Deaths = 3
frame.config.statistic = "Deaths"
session.combatSources[1].deathRecapID = 99
app:RefreshWindows()
frame.rows[1].entry.scripts.OnEnter()
assert(recapID == 99 and detailBar.maximum == secret and detailBar.statusValue == secret)
assert(detailBar.icon.texture == 89163, "Recap melee bars use the attack spell icon")
assert(detailBar.name.args[2] == secret and detailBar.value.args[1] == secret)
assert(not tooltip.targetLabel:IsShown(), "Death recap keeps its existing layout without a Targets category")
frame.rows[1].entry.scripts.OnLeave()
frame.config.statistic = "DamageDone"
app:RefreshWindows()
C_DeathRecap = nil
assert(frame.statistic:GetFrameLevel() == 2 and frame.session:GetFrameLevel() == 2)
-- Exercise the actual button callbacks, menu selection and API routing together.
local menuRoot
local function menuDescription(label)
    local description = { label = label, entries = {} }
    function description:SetScrollMode(height)
        self.maxScrollHeight = height
    end
    function description:AddInitializer(initializer)
        self.initializer = initializer
    end
    function description:CreateButton(text, choose)
        local child = menuDescription(text)
        child.choose = choose
        table.insert(self.entries, child)
        return child
    end
    function description:CreateRadio(text, selected, choose)
        local child = menuDescription(text)
        child.selected, child.choose = selected, choose
        table.insert(self.entries, child)
        return child
    end
    function description:CreateTitle(text)
        table.insert(self.entries, { title = text })
    end
    function description:CreateDivider()
        table.insert(self.entries, { divider = true })
    end
    return description
end
MenuUtil = {
    CreateRootMenuDescription = function()
        menuRoot = menuDescription()
        return menuRoot
    end,
    CreateContextMenu = function(owner, generator)
        menuRoot = menuDescription()
        generator(owner, menuRoot)
    end,
}
MenuVariants = { GetDefaultContextMenuMixin = function() end }
AnchorUtil = {
    CreateAnchor = function(...)
        return { ... }
    end,
}
Menu = {
    PopulateDescription = function(generator, owner, root)
        generator(owner, root)
    end,
    GetManager = function()
        return {
            OpenMenu = function(_, owner, root, anchor)
                assert(owner == frame.session and root == menuRoot)
                assert(anchor[1] == "BOTTOMRIGHT" and anchor[2] == owner and anchor[3] == "TOPRIGHT")
                assert(anchor[5] > 0, "Session menu must prefer opening above the selector")
            end,
        }
    end,
}
frame.statistic.scripts.OnClick()
local damage, dps = menuRoot.entries[1].entries[1], menuRoot.entries[1].entries[2]
assert(damage.selected() and not dps.selected())
frame.offset = 5
dps.choose()
assert(frame.config.statistic == "Dps" and frame.offset == 0 and dps.selected())
assert(lastMeterType == Enum.DamageMeterType.Dps and frame.statistic.text.text == "DPS")
history = { { sessionID = 42, name = "", durationSeconds = 15 }, { sessionID = 43, name = "Boss" } }
frame.session.scripts.OnClick()
local fight, otherFight = menuRoot.entries[1], menuRoot.entries[2]
local current, overall = menuRoot.entries[4], menuRoot.entries[5]
assert(fight.label == "Combat 42 (live)" and otherFight.label == "Boss (live)")
local menuButton = object()
menuButton.fontString = object(menuButton)
menuButton.fontString:SetText(fight.label)
menuButton.fontString.GetUnboundedStringWidth = methods.GetStringWidth
menuButton.AttachFontString = function(self)
    self.duration = object(self)
    return self.duration
end
local menuWidth, menuHeight = fight.initializer(menuButton)
assert(menuWidth > 55 and menuHeight == 20)
assert(menuButton.duration.text == "15" and menuButton.duration.justifyH == "RIGHT")
assert(menuButton.fontString.points.RIGHT[2] == menuButton.duration, "Names reserve the separate duration column")
assert(
    app.combatService:Describe({ name = "Boss", state = "archived", capturedAt = 123, durationSeconds = 15 }, true)
        == "Boss (archived)",
    "Menu labels omit timestamps and duration, keeping archive status beside the name"
)
assert(current.selected() and not overall.selected() and not fight.selected())
frame.offset = 5
fight.choose()
assert(fight.selected() and not current.selected() and frame.offset == 0)
assert(lastSessionID == 42 and lastMeterType == Enum.DamageMeterType.Dps)
assert(frame.config.sessionName == "Combat 42" and frame.session.text.text == 42)
overall.choose()
assert(overall.selected() and not fight.selected())
assert(frame.config.sessionID == nil and frame.config.sessionName == nil)
assert(lastSessionType == Enum.DamageMeterSessionType.Overall and frame.session.text.text == "O")
current.choose()
damage.choose()
history = {}
assert(lastSessionType == Enum.DamageMeterSessionType.Current and lastMeterType == Enum.DamageMeterType.DamageDone)
Enum.DamageMeterType.Deaths, Enum.DamageMeterType.EnemyDamageTaken = 3, 4
frame.statistic.scripts.OnClick()
local enemy = menuRoot.entries[1].entries[3]
local deaths = menuRoot.entries[3].entries[1]
enemy.choose()
assert(lastMeterType == Enum.DamageMeterType.EnemyDamageTaken)
deaths.choose()
assert(lastMeterType == Enum.DamageMeterType.Deaths)
damage.choose()
local fullHeight = app:GetWindowSetting(frame.config, "height")
assert(next(app.db.profile.favorites) == nil and not frame.favorites:IsShown())
frame.scripts.OnMouseUp(frame, "LeftButton")
assert(not frame.favorites:IsShown())
frame.scripts.OnMouseUp(frame, "RightButton")
assert(frame.favorites:IsShown() and #frame.favorites.buttons == 7)
local favorite = frame.favorites.buttons[1]
assert(frame.favorites.parent == frame and favorite.row.entry.parent == frame.favorites)
assert(frame.favorites:GetFrameLevel() > frame.body:GetFrameLevel())
assert(favorite.mouseEnabled and not favorite.row.mouseEnabled and not favorite.row.entry.mouseEnabled)
assert(favorite:GetFrameLevel() > favorite.row:GetFrameLevel(), "Favorite buttons must receive clicks above row art")
assert(favorite.row:GetHeight() == frame.rows[1]:GetHeight())
assert(not frame.rows[1]:IsShown() and not frame.localRow:IsShown() and not frame.message:IsShown())
app:RefreshWindows()
assert(not frame.rows[1]:IsShown(), "Combat updates must not paint over favorites")
favorite.scripts.OnClick(favorite, "LeftButton")
assert(not menuRoot.entries[1].entries[1].selected(), "Empty favorites have no selected type")
menuRoot.entries[1].entries[2].choose()
assert(app.db.profile.favorites[1] == "Dps" and frame.config.statistic == "DamageDone")
assert(favorite.row.name.text == "DPS" and frame.favorites:IsShown())
assert(favorite.row.icon:IsShown() and favorite.row.icon.texture == "Interface\\Icons\\INV_Misc_QuestionMark")
frame.offset = 5
favorite.scripts.OnClick(favorite, "LeftButton")
assert(frame.config.statistic == "Dps" and frame.offset == 0 and not frame.favorites:IsShown())
assert(lastMeterType == Enum.DamageMeterType.Dps)
app:RebuildWindows()
assert(app.db.profile.favorites[1] == "Dps", "Rebuilding must preserve assigned favorites")
frame.scripts.OnMouseUp(frame, "RightButton")
favorite.scripts.OnClick(favorite, "RightButton")
assert(menuRoot.entries[1].entries[2].selected())
menuRoot.entries[1].entries[1].choose()
assert(app.db.profile.favorites[1] == "DamageDone" and frame.config.statistic == "Dps")
assert(favorite.row.icon.texture == "Interface\\Icons\\Spell_Fire_FlameBolt")
assert(frame.favorites:IsShown(), "Replacing a favorite keeps the shortcuts open")
favorite.scripts.OnClick(favorite, "RightButton")
menuRoot.entries[#menuRoot.entries].choose()
assert(app.db.profile.favorites[1] == nil and favorite.row.name.text == "+ Set favorite")
assert(favorite.row.icon.texture == "Interface\\Icons\\INV_Misc_QuestionMark")
local selector = frame.favorites.buttons[7]
assert(selector.row.name.text == "Select type" and selector.row.icon:IsShown())
for _, mouseButton in ipairs({ "LeftButton", "RightButton" }) do
    selector.scripts.OnClick(selector, mouseButton)
    menuRoot.entries[1].entries[1].choose()
    assert(frame.config.statistic == "DamageDone" and next(app.db.profile.favorites) == nil)
    assert(not frame.favorites:IsShown(), "The general selector changes the window type and closes favorites")
    app:ToggleFavorites(frame)
end
local savedOffset = frame.offset
frame.config.overrides.height = 120
app:RefreshWindows()
assert(frame.scrollbar:IsShown(), "Small windows must scroll five favorites and the general selector")
frame.favorites.scripts.OnMouseWheel(frame.favorites, -1)
assert(frame.favoriteOffset > 0 and frame.offset == savedOffset)
assert(not favorite.row.entry:IsShown(), "Favorite rows above the viewport must be hidden")
frame.config.overrides.height = nil
frame.scripts.OnMouseUp(frame, "RightButton")
assert(not frame.favorites:IsShown(), "Right-clicking again dismisses the overlay")
assert(frame.rows[1]:IsShown(), "Dismissing favorites restores combat rows")
damage.choose()
frame.collapse.scripts.OnClick()
assert(frame:IsShown() and not frame.body:IsShown())
assert(app:GetWindowSetting(frame.config, "height") == fullHeight and frame:GetHeight() == 32)
assert(frame.point[5] == (fullHeight - 32) / 2, "Collapse must keep the header position stable")
assert(not frame.localRow:IsShown())
app:RebuildWindows()
assert(frame:GetHeight() == 32 and app:GetWindowSetting(frame.config, "height") == fullHeight)
frame.collapse.scripts.OnClick()
assert(frame:GetHeight() == fullHeight, "Expanding must not overwrite saved height with resize minimum")
frame.scrollbar:SetValue(7)
assert(frame.offset == 7 and not frame.localRow:IsShown())
session.combatSources[8].totalAmount = 12345
session.combatSources[8].amountPerSecond = 2.8
app:RefreshWindows()
assert(frame.rows[1].value.text == "12.3k" and frame.rows[1].secondaryValue.text == "3")
assert(frame.rows[1].value:GetWidth() <= 45 and frame.rows[1].secondaryValue:GetWidth() <= 45)
for _, sample in ipairs({
    { 999, "999" },
    { 1000, "1.0k" },
    { 1100, "1.1k" },
    { 1000000, "1.0m" },
}) do
    session.combatSources[8].amountPerSecond = sample[1]
    app:RefreshWindows()
    assert(frame.rows[1].secondaryValue.text == sample[2], "Rates use compact units from one thousand")
end
session.combatSources[8].amountPerSecond = 2.8
app:RefreshWindows()
assert(
    frame.rows[1].value:GetWidth() == frame.rows[2].value:GetWidth()
        and frame.rows[1].value.points.RIGHT[4] == frame.rows[2].value.points.RIGHT[4],
    "Main meter columns align independently of public or restricted value text"
)
assert(
    frame.rows[1].name.points.RIGHT[2] == frame.rows[1].value
        and frame.rows[1].value.points.RIGHT[4] < frame.rows[1].secondaryValue.points.RIGHT[4]
        and frame.rows[1].secondaryValue.points.RIGHT[4] < frame.rows[1].percentageValue.points.RIGHT[4],
    "Name, amount, rate and percentage occupy non-overlapping columns"
)
session.totalAmount = 24690
app:RefreshWindows()
assert(frame.rows[1].percentageValue.args[1] == 50)
session.totalAmount = 12345
local previousWidth = frame.config.overrides.width
frame.config.overrides.width = 200
app:RefreshWindows()
assert(frame.rows[1].percentageValue.args[1] == 100)
assert(frame.rows[1].percentageValue:GetWidth() >= 32, "100% keeps its full measured width in narrow windows")
frame.config.overrides.width = previousWidth
session.totalAmount = secret
app:RefreshWindows()
assert(frame.rows[1].percentageValue.text == "", "Restricted totals clear a previously visible public percentage")
session.totalAmount = nil
frame.config.statistic = "Dps"
app:RefreshWindows()
assert(frame.rows[1]:IsShown())
assert(
    frame.rows[1].value.text == "3" and frame.rows[1].secondaryValue.text == "12.3k",
    "Rate display must swap primary and secondary values"
)
frame.config.statistic = "Interrupts"
Enum.DamageMeterType.Interrupts = 2
app:RefreshWindows()
assert(frame.rows[1].value.text == "12.3k", "Action counts must not show a rate")
assert(not frame.rows[1].secondaryValue:IsShown(), "Switching to action counts hides the pooled rate column")
frame.config.statistic = "DamageDone"
app:AddWindow()
local second = app.windows[2]
assert(SeamlessDamageMeterWindow2 == second)
app.db.profile.favorites[1] = "Dps"
assert(second.config.favorites == nil, "Favorites are stored only on the shared profile")
app.db.profile.maxVisibleFavorites = 2
app:ToggleFavorites(second)
assert(second.favorites.buttons[1].row.name.text == "DPS", "Every window uses the shared favorites")
assert(second.favorites.buttons[3].row.name.text == "Select type")
app.db.profile.maxVisibleFavorites = 8
app:RefreshWindows()
assert(second.favorites.buttons[9].row.name.text == "Select type")
assert(second.favorites.buttons[3].row.name.text == "+ Set favorite")
app.db.profile.maxVisibleFavorites = 0
app:RefreshWindows()
assert(second.favorites.buttons[1].row.name.text == "Select type")
assert(not second.favorites.buttons[2].row.entry:IsShown())
second.favorites.buttons[1].scripts.OnClick(second.favorites.buttons[1], "LeftButton")
menuRoot.entries[1].entries[1].choose()
assert(second.config.statistic == "DamageDone" and app.db.profile.favorites[1] == "Dps")
app.db.profile.maxVisibleFavorites = 6
app:ToggleFavorites(frame)
app:ToggleFavorites(second)
assert(not frame.favorites:IsShown() and second.favorites:IsShown())
app:ApplyWindowLayout(second)
assert(not second.favorites:IsShown())
reads = 0
app:RefreshWindows()
assert(reads == 1, "Matching windows should share one API read")
frame.config.sessionID = 99
app:RefreshWindows()
assert(frame.message:IsShown() and not frame.rows[1]:IsShown() and not frame.localRow:IsShown())
frame.config.sessionID = nil
session.combatSources = {}
app:RefreshWindows()
assert(frame.offset == 0 and not frame.scrollbar:IsShown())
assert(not frame.rows[1]:IsShown() and not frame.localRow:IsShown())
C_DamageMeter = nil
app:RefreshWindows()
assert(frame.message.text == "This client does not provide the damage meter API.")
app:SetWindowEnabled(app.db.profile.windows[1], false)
assert(
    app.windows[2] == second and SeamlessDamageMeterWindow2 == second,
    "Deleting another window must not rename or reassign this frame"
)
app:RebuildWindows()
assert(app.windows[2] == second)
app:SetWindowEnabled(app.db.profile.windows[2], false)
assert(#app.db.profile.windows == 10 and not frame:IsShown() and not second:IsShown())
app:RebuildWindows()
assert(
    app:GetUnusedWindowSlot() == 1 and not frame:IsShown() and not second:IsShown(),
    "A fully inactive profile must remain inactive"
)
app.db.profile = {
    initialized = true,
    nextID = 3,
    windowDefaults = app.windowDefaults,
    windows = { { id = 2, statistic = "DamageDone", session = "Current", width = 400, height = 200, x = 0, y = 0 } },
}
app:RebuildWindows()
assert(
    app.windows[2] == second and SeamlessDamageMeterWindow2 == second,
    "Profile changes must reuse the same named frame"
)
assert(second.config.width == nil and second.config.overrides.width == 400, "Legacy geometry must migrate")
app.db.profile.windowDefaults.width = 480
app:AddWindow()
local inherited = app.windowFrames[1]
assert(inherited:GetWidth() == 480 and next(inherited.config.overrides) == nil)
assert(second:GetWidth() == 400, "Migrated geometry must remain an override")
app.db.profile.windowDefaults.width = 520
app:RebuildWindows()
assert(inherited:GetWidth() == 520 and second:GetWidth() == 400)
inherited.config.anchorTo = second.config.id
inherited.config.overrides.scale = 1.5
app:RebuildWindows()
assert(inherited.anchorTarget == second and inherited:GetEffectiveScale() == 1.5)
assert(not app:CanAnchorTo(second.config, inherited.config.id))
local anchorPoint = inherited.point
app:SetWindowEnabled(second.config, false)
assert(inherited.config.anchorTo == 2 and inherited.anchorTarget == second and not second:IsShown())
for index = 1, 5 do
    assert(inherited.point[index] == anchorPoint[index], "Deactivation must preserve the dependent's anchor geometry")
end
assert(inherited.config.overrides.width == nil, "Deactivating an anchor must not override the inherited size")
app.core = { logger = { chat = function() end } }
for _ = 1, 12 do
    app:AddWindow()
end
assert(#app.db.profile.windows == 10, "All creation paths must enforce the window limit")
local slot = app.windowFrames[3]
slot.config.hidden = true
slot.config.collapsed = true
slot.config.statistic = "Dps"
slot.config.sessionID = 99
app.db.profile.skins.default.settings.fontSize = 20
app:RebuildWindows()
assert(not slot:IsShown() and app:GetUnusedWindowSlot() == nil, "Hidden windows must retain their slot")
local previousConfig = slot.config
app:SetWindowEnabled(previousConfig, false)
assert(slot.config == previousConfig and not slot:IsShown())
assert(app:GetUnusedWindowSlot() == 3)
app:AddWindow()
assert(app.windowFrames[3] == slot and slot:IsShown(), "Reactivation must reuse the slot's frame")
assert(slot.config == previousConfig and app:GetWindowSetting(slot.config, "fontSize") == 20)
assert(slot.config.statistic == "Dps" and slot.config.session == "Current")
assert(not slot.config.hidden and slot.config.collapsed and slot.config.sessionID == 99)
for _ = 1, 25 do
    app:SetWindowEnabled(slot.config, false)
    app:AddWindow()
    assert(app.windowFrames[3] == slot)
end
local allocated = 0
for id in pairs(app.windowFrames) do
    assert(id >= 1 and id <= 10)
    allocated = allocated + 1
end
assert(allocated == 10, "Repeated removal and creation must not grow the frame pool")
print("Damage meter window regressions OK")

-- Exercise the adapter against the library's exposed database contract and callbacks.
local registered = 0
EditModeManagerExpandedFrame = object()
expandedScrollChild = object(EditModeManagerExpandedFrame)
local eme = { baseFramesDB = {}, framesDB = {} }
function methods:HookScript(event, callback)
    local original = self.scripts[event]
    self.scripts[event] = function(...)
        if original then
            original(...)
        end
        callback(...)
    end
end
function methods:SetChecked(value)
    self.checked = value
end
function methods:GetChecked()
    return self.checked
end
function eme:IsRegistered(frame)
    return frame.system ~= nil
end
function eme:RegisterFrame(frame, name, db)
    assert(name == "Seamless Damage " .. frame.windowID, "Edit Mode labels must use the compact slot name")
    registered = registered + 1
    frame.system = 100 + registered
    local row = object(expandedScrollChild)
    row.layoutIndex = registered
    frame.EMECheckButtonFrame = object(row)
    frame.Selection = object(frame)
    self.baseFramesDB[frame.system], self.framesDB[frame.system] = db, db
    frame.EMECheckButtonFrame:SetScript("OnClick", function(button, mouseButton)
        if mouseButton == "LeftButton" then
            self.framesDB[frame.system].enabled = button:GetChecked()
            frame:SetShown(button:GetChecked())
        end
    end)
    frame.SetScaleOverride = frame.SetScale
    frame.CanBeMoved = function(self)
        return self.isSelected
    end
    frame.MoveWithArrowKey = function(self)
        self.arrowMoves = (self.arrowMoves or 0) + 1
    end
end
function eme:RegisterResizable(frame, minimum, maximum, step)
    assert(minimum == 50 and maximum == 200 and step == 5)
end
function eme:RegisterSlider(frame, name, key, callback, minimum, maximum, step)
    if key == "visibleLines" then
        assert(name == "Row count" and minimum == 1 and maximum == 30 and step == 1)
    elseif key == "width" or key == "height" then
        assert(name == (key == "width" and "Frame width" or "Frame height"))
        assert(minimum == (key == "width" and 200 or 120))
        assert(maximum == (key == "width" and 800 or 900) and step == 1)
    end
    local appearance = {
        rowHeight = { "Bar height", 16, 40, 1 },
        rowSpacing = { "Padding", 0, 12, 1 },
        windowAlpha = { "Transparency", 50, 100, 1 },
        backgroundColor = { "Background", 0, 100, 1 },
        fontSize = { "Text size", 50, 150, 10 },
    }
    if appearance[key] then
        local expected = appearance[key]
        assert(name == expected[1] and minimum == expected[2] and maximum == expected[3] and step == expected[4])
    end
    frame.editModeSliders = frame.editModeSliders or {}
    frame.editModeSliders[key] = callback
end
function eme:RegisterCustomCheckbox(frame, name, checked, unchecked, key)
    frame.editModeChecks = frame.editModeChecks or {}
    frame.editModeChecks[key] = { checked = checked, unchecked = unchecked }
    unchecked(true)
end
function eme:RegisterDropdown(frame, factory, key)
    assert(key == "skin")
    return factory:Create_UIDropDownMenu(nil, object(frame))
end
function eme:RegisterCustomButton(frame, name, callback, key)
    assert(
        (key == "editSkin" and name == "Edit selected skin")
            or (key == "createWindow" and name == "Create new window")
            or (key == "removeWindow" and name == "Remove window")
    )
    frame[key] = callback
end
function eme:SetDontResize(frame)
    frame.EMEDontResize = true
end
function eme:IsFrameEnabled(frame)
    return self.framesDB[frame.system].enabled
end
function methods:GetRect()
    return self:GetLeft(), self:GetBottom(), self:GetSize()
end
function methods:GetScale()
    return self.scale or 1
end
local combat = false
function InCombatLockdown()
    return combat
end
function hooksecurefunc(target, key, callback)
    local original = target[key]
    target[key] = function(...)
        original(...)
        callback(...)
    end
end
Enum.EditModeLayoutType = { Character = 2 }
EditModeManagerFrame = {
    GetActiveLayoutInfo = function()
        return { layoutType = 1, layoutName = "Test" }
    end,
    ExitEditMode = function(self)
        self.editModeActive = false
    end,
    EnterEditMode = function(self)
        self.editModeActive = true
    end,
}
local originalLibStub = LibStub
LibStub = function(name)
    if name == "EditModeExpanded-1.0" then
        return eme
    end
    return originalLibStub(name)
end
app.core.RefreshOptions = function() end
app.addon = {
    IsEnabled = function()
        return true
    end,
}
assert(loadfile("SeamlessDamageMeter/src/editmode.lua"))("SeamlessDamageMeter", app)
app:RebuildWindows()
assert(registered == 10, "Every slot must register once, including inactive slots")
assert(meterGroupRow.Label.text == "Seamless Damage Meter")
assert(meterGroupRow.Button:GetChecked(), "Used window previews must default to enabled")
for _, frame in pairs(app.windowFrames) do
    assert(not frame.EMECheckButtonFrame:GetParent():IsShown(), "Individual entries must be hidden")
end
local meter = app.windowFrames[1]
assert(meter.EMEDontResize)
assert(meter.resize:GetFrameLevel() > meter.Selection:GetFrameLevel(), "The drag grip must stay above selection")
assert(eme.baseFramesDB[meter.system] == meter.config.editMode)
assert(eme.framesDB[meter.system] == meter.config.editMode.profiles["1-Test"])
meter.config.enabled = false
meter.config.hidden = true
EditModeManagerFrame.editModeActive = true
app:RebuildWindows()
assert(not meter:IsShown(), "Deactivated slots must default to hidden in Edit Mode")
assert(not eme.framesDB[meter.system].enabled)
local function ClickGroup(enabled)
    local button = meterGroupRow.Button
    button:SetChecked(enabled)
    button:GetScript("OnClick")(button)
end
ClickGroup(false)
ClickGroup(true)
assert(not meter:IsShown() and not meter.config.enabled, "Group checkbox must not activate unused slots")
assert(meter.config.hidden, "Group checkbox must preserve temporary hiding")
meter.config.enabled = true
app:RebuildWindows()
assert(meter:IsShown(), "Used windows must preview even when temporarily hidden")
ClickGroup(false)
assert(not meter:IsShown() and meter.config.enabled, "Unchecking must hide previews without deactivating slots")
app:RebuildWindows()
assert(not meter:IsShown(), "Rebuilding must retain group preview visibility")
combat = true
ClickGroup(true)
assert(not meterGroupRow.Button:GetChecked() and not meter:IsShown(), "Combat must block preview changes")
combat = false
ClickGroup(true)
meter.config.editMode.profiles["1-Other"] = { enabled = true, settings = {} }
meter.config.enabled = false
app:RebuildWindows()
assert(not meter:IsShown(), "Deactivating a slot must reset its Edit Mode preview")
assert(not meter.config.editMode.profiles["1-Other"].enabled, "Deactivation must update other native layouts")
app:SetWindowEnabled(meter.config, true)
app:RebuildWindows()
assert(meter:IsShown() and meter.config.enabled, "Activation survives ordinary rebuilds")
meter:SetScaleOverride(1.25)
assert(meter.config.overrides.scale == 1.25)
assert(eme.framesDB[meter.system].settings[16] ~= nil)
meter:SetScaleOverride(0.8999997615814)
assert(meter.config.overrides.scale == 0.9, "Snap Edit Mode scale input before saving")
assert(eme.framesDB[meter.system].settings[16] == 90)
meter.config.overrides.scale = 0.923456
meter:SetScaleOverride(0.923456)
assert(meter.config.overrides.scale == 0.923456, "Unchanged fractional scale must survive library callbacks")
meter.config.overrides.width = 401.2345
app:SyncWindowEditMode(meter)
assert(eme.framesDB[meter.system].settings[16] == 90)
assert(eme.framesDB[meter.system].settings[18].width == 401)
assert(meter.config.overrides.scale == 0.923456 and meter.config.overrides.width == 401.2345)
meter.editModeSliders.width(449.999976)
assert(meter.config.overrides.width == 450)
local originalDatabase = meter.config.editMode
ClickGroup(false)
app.db.profile = { windows = {}, initialized = false, windowDefaults = app.windowDefaults }
app:RebuildWindows()
assert(not meter:IsShown() and meter.config.enabled, "Profile switches must retain preview visibility only")
assert(not meterGroupRow.Button:GetChecked(), "Profile switches must preserve the group checkbox")
ClickGroup(true)
assert(registered == 10, "Profile changes must reuse library registrations")
assert(meter.config.editMode ~= originalDatabase)
assert(eme.baseFramesDB[meter.system] == meter.config.editMode, "Rebind the active AceDB profile")
assert(meter.config.overrides.scale == nil, "Profile changes must preserve inheritance")
assert(meter.config.overrides.x == nil and meter.config.overrides.y == nil)
assert(meter:IsShown(), "The active default slot must be visible in Edit Mode")
assert(not app.windowFrames[10]:IsShown(), "Fresh inactive slots must be unchecked")
meter:SetScaleOverride(meter:GetScale())
assert(meter.config.overrides.scale == nil, "An unchanged library scale must remain inherited")
assert(
    meter.config.overrides.x == nil and meter.config.overrides.y == nil,
    "An unchanged library position stays inherited"
)
meter.createWindow()
assert(app.windowFrames[2].config.enabled and app.windowFrames[2]:IsShown(), "New slots must preview immediately")
assert(not app.windowFrames[3].config.enabled, "Creating a window must activate only one slot")
local removable = app.windowFrames[2]
local removedConfig, removedOverrides = removable.config, removable.config.overrides
local clearedSelection = 0
EditModeManagerExpandedFrame.ClearSelectedSystem = function()
    clearedSelection = clearedSelection + 1
end
removable.removeWindow()
assert(not removable:IsShown() and not removable.config.enabled, "Removing must deactivate the selected window")
assert(clearedSelection == 1, "Removing must dismiss the selected window's Edit Mode controls")
assert(meter:IsShown() and meter.config.enabled, "Removing must preserve other active windows")
assert(
    removable.config == removedConfig and removable.config.overrides == removedOverrides,
    "Removal must retain settings"
)
meter.createWindow()
assert(removable.config.enabled and removable:IsShown(), "Creation must reuse the removed slot")
combat = true
meter.createWindow()
removable.removeWindow()
assert(removable.config.enabled and clearedSelection == 1, "Combat must block removal")
assert(not app.windowFrames[3].config.enabled, "Creating in combat must be ignored")
combat = false
ClickGroup(false)
EditModeManagerFrame:ExitEditMode()
assert(meter:IsShown() and meter.config.enabled, "Hidden previews must return to normal visibility on exit")
meter.createWindow()
removable.removeWindow()
assert(removable.config.enabled and clearedSelection == 1, "Removal outside Edit Mode must be ignored")
assert(not app.windowFrames[3].config.enabled, "Creating outside Edit Mode must be ignored")

EditModeManagerFrame:EnterEditMode()
assert(not meter:IsShown() and not app.windowFrames[2]:IsShown(), "Re-entering must retain the group preview toggle")
ClickGroup(true)
assert(meter:IsShown() and app.windowFrames[2]:IsShown(), "Checking must show every used window")
assert(not app.windowFrames[3]:IsShown(), "Checking must leave unused slots hidden")
local draggingSettings, dialogRefreshes = false, 0
EditModeExpandedSystemSettingsDialog = {
    attachedToSystem = meter,
    pools = {
        EnumerateActiveByTemplate = function()
            local yielded = false
            return function()
                if not yielded then
                    yielded = true
                    return {
                        Slider = {
                            Slider = {
                                IsDraggingThumb = function()
                                    return draggingSettings
                                end,
                            },
                        },
                    }
                end
            end
        end,
    },
    UpdateSettings = function()
        dialogRefreshes = dialogRefreshes + 1
        meter.editModeSliders.visibleLines(25)
    end,
}
app:SyncWindowEditMode(meter)
assert(dialogRefreshes == 1 and app:GetWindowSetting(meter.config, "visibleLines") == 7)
draggingSettings = true
app:SyncWindowEditMode(meter)
assert(dialogRefreshes == 1, "Avoid rebuilding pooled EME sliders during a drag")
draggingSettings = false
EditModeExpandedSystemSettingsDialog = nil
local skin = app.db.profile.skins[meter.config.skin].settings
meter.editModeSliders.rowHeight(29.999976)
meter.editModeSliders.windowAlpha(74.999976)
meter.editModeSliders.fontSize(119.999976)
assert(skin.rowHeight == 30 and skin.windowAlpha == 0.75 and skin.fontSize == 18)
skin.fontSize = 17
app:SyncWindowEditMode(meter)
assert(eme.framesDB[meter.system].settings[18].fontSize == 110 and skin.fontSize == 17)
meter.editModeSliders.rowHeight(30)
meter.editModeSliders.rowSpacing(6)
meter.editModeSliders.windowAlpha(75)
meter.editModeSliders.backgroundColor(20)
meter.editModeSliders.fontSize(120)
meter.editModeChecks.showIcons.unchecked(false)
meter.editModeChecks.classColors.unchecked(false)
assert(skin.rowHeight == 30 and skin.rowSpacing == 6 and skin.windowAlpha == 0.75)
assert(skin.backgroundColor[4] == 0.2 and skin.fontSize == 18)
assert(not skin.showIcons and not skin.classColors)
assert(eme.framesDB[meter.system].settings[18].windowAlpha == 75)
assert(eme.framesDB[meter.system].settings[12].showIcons == 0)
meter.editModeSliders.rowHeight(24)
meter.editModeSliders.rowSpacing(4)
meter.editModeSliders.windowAlpha(100)
meter.editModeSliders.backgroundColor(50)
meter.editModeSliders.fontSize(100)
meter.editModeChecks.showIcons.checked()
meter.editModeChecks.classColors.checked()
meter.editModeChecks.fixedHeight.checked()
assert(app:GetWindowSetting(meter.config, "fixedHeight"))
meter.config.overrides.visibleLines = 7.25
app:SyncWindowEditMode(meter)
assert(app:GetWindowSetting(meter.config, "visibleLines") == 7.25, "Edit Mode must preserve fractional addon values")
assert(eme.framesDB[meter.system].settings[18].visibleLines == 7)
meter.editModeSliders.visibleLines(8)
assert(app:GetWindowSetting(meter.config, "visibleLines") == 8)
assert(meter:GetHeight() == 40 + 8 * 28 - 4)
meter.editModeChecks.lockSize.checked()
assert(not meter.resize:IsShown() and not meter.resize.mouseEnabled)
local lockedWidth = meter:GetWidth()
meter.editModeSliders.width(lockedWidth + 100)
meter.resize:GetScript("OnMouseDown")(meter.resize, "LeftButton")
assert(meter:GetWidth() == lockedWidth and not meter.editing)
meter.editModeChecks.lockSize.unchecked(false)
assert(meter.resize:IsShown() and meter.resize.mouseEnabled)
meter.isSelected = true
meter.editModeChecks.lockPosition.unchecked(true)
assert(not app:GetWindowSetting(meter.config, "lockPosition"))
assert(meter:CanBeMoved())
meter:MoveWithArrowKey("RIGHT")
assert(meter.arrowMoves == 1)
meter.editModeChecks.lockPosition.checked()
assert(eme.framesDB[meter.system].settings[12].lockPosition == 1)
assert(not meter:CanBeMoved())
meter:MoveWithArrowKey("RIGHT")
meter.title:GetScript("OnDragStart")()
assert(meter.arrowMoves == 1 and not meter.editing)
assert(meter.resize:IsShown() and meter.resize.mouseEnabled, "Position lock must preserve resizing")
meter.editModeChecks.lockPosition.unchecked(false)
assert(meter:CanBeMoved() and eme.framesDB[meter.system].settings[12].lockPosition == 0)
meter:MoveWithArrowKey("RIGHT")
assert(meter.arrowMoves == 2)
meter.editModeChecks.fixedHeight.unchecked(false)
assert(not app:GetWindowSetting(meter.config, "fixedHeight"))
assert(eme.framesDB[meter.system].settings[12].fixedHeight == 0)
assert(eme.framesDB[meter.system].settings[18].visibleLines == 8)
app.db.profile.skins.testSkin = { name = "Test skin", settings = { rowHeight = 32 } }
meter.skinDropdown:GetScript("OnClick")(meter.skinDropdown)
local skinChoice
for _, choice in ipairs(menuRoot.entries) do
    if choice.label == "Test skin" then
        skinChoice = choice
    end
end
assert(skinChoice, "Skin dropdown must include custom skins")
skinChoice.choose()
assert(meter.config.skin == "testSkin" and app:GetWindowSetting(meter.config, "rowHeight") == 32)
assert(meter.skinDropdown.text == "Skin: Test skin")
local openedSkin
app.core.OpenOptions = function(_, name, tab)
    assert(name == "SeamlessDamageMeter" and tab == "skin")
end
local previousStub = LibStub
LibStub = function(name)
    if name == "AceConfigDialog-3.0" then
        return {
            SelectGroup = function(_, name, tab, skin)
                openedSkin = skin
            end,
        }
    end
    return previousStub(name)
end
meter.editSkin()
assert(openedSkin == "testSkin")
LibStub = previousStub
meter.config.skin = "default"
app:RebuildWindows()
EditModeManagerFrame:ExitEditMode()
local savedLines = meter.config.overrides.visibleLines
meter.editModeSliders.visibleLines(12)
assert(meter.config.overrides.visibleLines == savedLines, "Outside-Edit-Mode callbacks must not change rows")

local realAPI = liveAPI
C_DamageMeter = setmetatable({}, {
    __index = function(_, key)
        return function()
            error("Edit Mode must never query live damage data: " .. key)
        end
    end,
})
meter.config.collapsed = true
local normalCombatState = UnitAffectingCombat
UnitAffectingCombat = function()
    return true
end
EditModeManagerFrame:EnterEditMode()
assert(meter.config.collapsed and meter.body:IsShown(), "Collapsed slots must temporarily expand for preview")
assert(meter:GetHeight() == app:GetWindowSetting(meter.config, "height"))
assert(meter.session.text.text == "Preview")
assert(meter.rows[1].name.args[2] == "Jaina" and meter.rows[1].icon.atlas == "MAGE")
assert(meter.rows[1].statusValue == 125000 and meter.rows[2].statusValue == 112000)
app.db.profile.locked = true
meter.resize:GetScript("OnMouseDown")(meter.resize, "LeftButton")
assert(meter.editing, "Edit Mode must allow the resize grip even when normal dragging is locked")
assert(meter.sizing == "BOTTOMRIGHT" and meter.resize:GetFrameStrata() == "HIGH")
assert(meter.resize.alpha == 1, "Entering Edit Mode must expose the grip immediately")
meter.Selection:SetFrameLevel(1500)
app:SyncWindowEditMode(meter)
assert(meter.resize:GetFrameLevel() > meter.Selection:GetFrameLevel())
meter:SetSize(610, 410)
meter.resize:GetScript("OnMouseUp")(meter.resize, "LeftButton")
assert(not meter.editing and not meter.sizing, "Releasing the grip must finish resizing")
assert(meter.config.overrides.width == 610 and meter.config.overrides.height == 410)
assert(eme.framesDB[meter.system].settings[18].width == 610)
assert(eme.framesDB[meter.system].settings[18].height == 410)
meter.config.overrides.width, meter.config.overrides.height = nil, nil
app:RebuildWindows()
local inheritedWidth = app:GetWindowSetting(meter.config, "width")
meter.editModeSliders.width(inheritedWidth)
assert(meter.config.overrides.width == nil, "Unchanged sliders must preserve inheritance")
meter.editModeSliders.width(650)
meter.editModeSliders.height(450)
assert(meter:GetWidth() == 650 and meter:GetHeight() == 450, "Sliders must resize the preview immediately")
assert(meter.config.overrides.width == 650 and meter.config.overrides.height == 450)
assert(eme.framesDB[meter.system].settings[18].width == 650)
assert(eme.framesDB[meter.system].settings[18].height == 450)
for _, statistic in ipairs(app.statistics) do
    meter.config.statistic = statistic.key
    meter.config.sessionID = 999
    app:RefreshWindows()
    local sample = app:GetSession(meter.config)
    assert(sample.isPreview and #sample.combatSources == 9)
    assert(sample.combatSources[9].classFilename == "PRIEST")
    if statistic.key == "Interrupts" or statistic.key == "Dispels" then
        assert(sample.maxAmount == 27 and sample.combatSources[1].totalAmount == 27)
    end
end
meter.config.sessionID = nil
meter.config.statistic = "DamageDone"
C_DamageMeter = realAPI
UnitAffectingCombat = normalCombatState
EditModeManagerFrame:ExitEditMode()
assert(meter.config.collapsed and not meter.body:IsShown() and meter:GetHeight() == 32)
assert(meter.session.text.text ~= "Preview", "Exiting must clear sample labels")
assert(meter.resize:GetFrameStrata() == meter:GetFrameStrata(), "Exiting restores the grip's normal strata")
assert(meter:GetWidth() == 650 and app:GetWindowSetting(meter.config, "height") == 450)
meter.editModeSliders.width(700)
assert(meter:GetWidth() == 650, "Native layout callbacks outside Edit Mode must not overwrite meter size")
assert(not app:GetSession(meter.config).isPreview, "Exiting must restore live data")
meter.config.hidden = true
EditModeManagerFrame:ExitEditMode()
assert(not meter:IsShown(), "Exit must restore the profile's normal visibility")
local savedX = meter.config.overrides.x
local originalCenter = methods.GetCenter
function methods:GetCenter()
    if self.testCenter then
        return self.testCenter, 0
    end
    return originalCenter(self)
end
meter.testCenter = 200
meter:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 10, 10)
assert(meter.config.overrides.x ~= savedX, "Library movement must update meter overrides")
assert(meter.point[1] == "BOTTOMLEFT", "Saving library movement must not recursively reposition")
meter.config.hidden, meter.config.collapsed = false, false
meter.config.overrides.fixedHeight = true
for _, lines in ipairs({ 1, 7, 7.25, 7.5, 7.75 }) do
    meter.config.overrides.visibleLines = lines
    app:RebuildWindows()
    assert(meter:GetHeight() == 40 + lines * 28 - 4, "Fixed height must include padding and fractional rows")
end
meter.config.overrides.showResizeHandle = false
EditModeManagerFrame:EnterEditMode()
assert(not meter.resize:IsShown(), "Disabled grip must stay hidden in Edit Mode")
meter.resize:GetScript("OnMouseDown")(meter.resize, "LeftButton")
assert(not meter.editing, "Disabled grip must not start resizing")
local manualHeight = meter.config.overrides.height
meter.editModeSliders.height(600)
assert(meter:GetHeight() == 253 and meter.config.overrides.height == manualHeight)
meter.editModeSliders.width(600)
assert(meter:GetWidth() == 600 and meter:GetHeight() == 253)
EditModeManagerFrame:ExitEditMode()
meter.config.overrides.fixedHeight = false
app:RebuildWindows()
assert(meter:GetHeight() == manualHeight, "Disabling fixed height restores manual height")
combat = true
savedX = meter.config.overrides.x
meter:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 20)
assert(meter.config.overrides.x == savedX, "Do not inspect restricted geometry in combat")
print("Damage meter Edit Mode regressions OK")

-- Saved history uses the same windows and hover panels without any live APIs.
GameTooltip = object()
combat = false
function date(_, timestamp)
    return tostring(timestamp)
end
local archiveID = app.archive:Commit({
    name = "Saved boss",
    capturedAt = 1000,
    durationSeconds = 10,
    complete = true,
    categories = {
        DamageDone = {
            complete = true,
            session = {
                totalAmount = 100,
                maxAmount = 100,
                durationSeconds = 10,
                combatSources = {
                    {
                        sourceGUID = "saved-player",
                        name = "Jaina",
                        totalAmount = 100,
                        amountPerSecond = 10,
                        classFilename = "MAGE",
                        specIconID = 0,
                    },
                },
            },
            details = {
                {
                    totalAmount = 100,
                    maxAmount = 100,
                    combatSpells = {
                        {
                            spellID = 1,
                            totalAmount = 100,
                            amountPerSecond = 10,
                            isAvoidable = true,
                            overkillAmount = 10,
                            combatSpellDetails = { unitName = "Wolf", amount = 100 },
                        },
                    },
                },
            },
        },
        EnemyDamageTaken = {
            complete = true,
            session = {
                totalAmount = 100,
                maxAmount = 100,
                durationSeconds = 10,
                combatSources = { { sourceCreatureID = 11, name = "Wolf", totalAmount = 100, amountPerSecond = 10 } },
            },
            details = {
                {
                    totalAmount = 100,
                    maxAmount = 100,
                    combatSpells = {
                        {
                            spellID = 1,
                            totalAmount = 100,
                            amountPerSecond = 10,
                            combatSpellDetails = { unitName = "Jaina", amount = 100 },
                        },
                    },
                },
            },
        },
    },
})
meter.config.archiveID, meter.config.statistic = archiveID, "DamageDone"
C_DamageMeter = nil
app:RefreshWindows()
assert(meter.rows[1].name.args[2] == "Jaina" and meter.session.text.text == "S" .. archiveID)
meter.rows[1].entry.scripts.OnEnter()
assert(app.detailTooltip.targetLabel:IsShown() and app.detailTooltip.rows[3].statusValue == 100)
meter.rows[1].entry.scripts.OnMouseUp(nil, "LeftButton")
assert(meter.detail and meter.detail.source.name == "Jaina", "Click opens this source inside the meter")
assert(meter.rows[1].statusValue == 100 and meter.rows[1].source == nil, "Nested view renders spell bars")
assert(meter.statistic.text.args[1] == "Jaina", "Nested header identifies the selected character")
assert(not app.detailTooltip:IsShown(), "Opening a source dismisses its hover")
meter.rows[1].entry.scripts.OnEnter()
assert(not app.detailTooltip:IsShown(), "Spell rows do not query another source breakdown")
meter.rows[1].entry.scripts.OnMouseUp(nil, "RightButton")
assert(not meter.detail and meter.rows[1].source.name == "Jaina", "Right-click returns to sources")
meter.rows[1].entry.scripts.OnMouseUp(nil, "LeftButton")
meter.statistic.scripts.OnClick()
assert(not meter.detail and meter.rows[1].source.name == "Jaina", "Header returns to sources")
meter.rows[1].entry.scripts.OnMouseUp(nil, "LeftButton")
meter.config.statistic = "HealingDone"
app:RefreshWindows()
assert(not meter.detail, "Changing category clears the selected source")
meter.config.statistic = "DamageDone"
app:RefreshWindows()

meter.rows[1].entry.scripts.OnMouseUp(nil, "LeftButton")
app.combatService:Delete(archiveID)
app:RefreshWindows()
assert(meter.message.text == "This saved fight was deleted.")
C_DamageMeter = realAPI
print("Damage meter archived windows regressions OK")

meter.config.statistic = "Threat"
app.db.profile.skins.default.settings.classColors = false
app:RefreshWindow(meter, {
    maxAmount = 100,
    targetName = secret,
    combatSources = {
        { name = "Tank", classFilename = "MAGE", totalAmount = secret, threatPercentage = secret },
    },
})
assert(meter.session.text.text == "", "Threat hides the unused fight selector label")
assert(meter.statistic.text.args[1] == secret, "Threat target names go directly to the header label")
assert(meter.rows[1].statusValue == secret, "Restricted threat percentages go directly to the bar")
assert(meter.rows[1].value.args[1] == secret, "Restricted threat totals go directly to the label")
assert(meter.rows[1].percentageValue.args[1] == secret, "Restricted threat percentages go directly to the label")
assert(not meter.rows[1].secondaryValue:IsShown(), "Threat has no rate column")
assert(meter.rows[1].color[1] == RAID_CLASS_COLORS.MAGE.r, "Threat always uses class colors")
app:RefreshWindow(meter, {
    maxAmount = 100,
    combatSources = {
        {
            name = "Pet",
            classFilename = "MAGE",
            isPet = true,
            reaction = 4,
            totalAmount = secret,
            threatPercentage = secret,
        },
    },
})
assert(
    meter.rows[1].color[1] == 1 and meter.rows[1].color[2] == 1 and meter.rows[1].color[3] == 0,
    "Pet threat bars use reaction colors even when class colors are disabled"
)
app:RefreshWindow(meter, {
    maxAmount = 100,
    combatSources = {
        { name = "Unknown pet", isPet = true, totalAmount = 1, threatPercentage = 1 },
        { name = "Unknown player", totalAmount = 1, threatPercentage = 1 },
    },
})
for index = 1, 2 do
    assert(meter.rows[index].color[2] == FACTION_BAR_COLORS[5].g, "Unavailable colors use faction color 5")
end
meter.rows[1].entry.scripts.OnEnter()
assert(not app.detailTooltip or not app.detailTooltip:IsShown(), "Threat does not request spell details")
app:RefreshWindow(meter, { combatSources = {}, maxAmount = 100 })
assert(meter.statistic.text.text == "Threat", "Threat without a target retains its title")
assert(meter.message.text == "", "Threat without a target has no hint text")
print("Damage meter threat window regressions OK")

local originalGetSession, originalRefreshWindow = app.GetSession, app.RefreshWindow
local originalWindows, originalEditing = app.windows, app.IsEditingWindows
local threatReads, threatRenders = 0, 0
app.windows = {
    meter,
    {
        config = { statistic = "DamageDone" },
        IsShown = function()
            return true
        end,
    },
}
function app:IsEditingWindows()
    return false
end
function app:GetSession(config)
    assert(config.statistic == "Threat", "Threat events do not refresh damage windows")
    threatReads = threatReads + 1
    return {}
end
function app:RefreshWindow()
    threatRenders = threatRenders + 1
end
meter:Show()
app.combatService.cache["l:Threat"] = { "stale" }
app:RefreshThreatWindows()
assert(threatReads == 1 and threatRenders == 1 and app.combatService.cache["l:Threat"] == nil)
function app:IsEditingWindows()
    return true
end
app:RefreshThreatWindows()
assert(threatReads == 1, "Live events never query threat in Edit Mode")
function app:IsEditingWindows()
    return false
end
meter:Hide()
app:RefreshThreatWindows()
assert(threatReads == 1, "Hidden threat windows do not query live data")
app.GetSession, app.RefreshWindow = originalGetSession, originalRefreshWindow
app.windows, app.IsEditingWindows = originalWindows, originalEditing
print("Damage meter threat event window regressions OK")

-- Settings menu ordering, actions and reversible noninteractive state.
local oldManager = Menu.GetManager
Menu.GetManager = function()
    return { OpenMenu = function() end }
end
local oldDescription = MenuUtil.CreateRootMenuDescription
MenuUtil.CreateRootMenuDescription = function()
    local root = oldDescription()
    local function extend(description)
        local create = description.CreateButton
        function description:CreateButton(...)
            local child = create(self, ...)
            function child:SetEnabled(enabled)
                self.enabled = enabled
            end
            return child
        end
        function description:CreateSpacer()
            table.insert(self.entries, { spacer = true })
        end
    end
    extend(root)
    return root
end
local oldRefresh = app.RefreshWindows
app.RefreshWindows = function() end
meter.config.noninteractive = nil
meter.settings:GetScript("OnClick")(meter.settings)
local expected = {
    "Settings",
    "Editmode",
    false,
    "Lock Position",
    "Make Noninteractive",
    "Reset Data",
    "Delete Window",
    false,
    "Create New Window",
}
assert(#menuRoot.entries == #expected)
for index, label in ipairs(expected) do
    assert(label and menuRoot.entries[index].label == label or not label and menuRoot.entries[index].spacer)
end
menuRoot.entries[4].choose()
assert(app:GetWindowSetting(meter.config, "lockPosition"))
meter.settings:GetScript("OnClick")(meter.settings)
assert(menuRoot.entries[4].label == "Unlock Position")
menuRoot.entries[4].choose()
assert(not app:GetWindowSetting(meter.config, "lockPosition"))
menuRoot.entries[5].choose()
assert(meter.config.noninteractive)
meter.settings:GetScript("OnClick")(meter.settings)
assert(menuRoot.entries[5].label == "Make Interactive")
menuRoot.entries[4].choose()
assert(app:GetWindowSetting(meter.config, "lockPosition"))
meter.settings:GetScript("OnClick")(meter.settings)
assert(menuRoot.entries[4].label == "Unlock Position")
menuRoot.entries[4].choose()
assert(not app:GetWindowSetting(meter.config, "lockPosition"))
menuRoot.entries[5].choose()
assert(not meter.config.noninteractive)
local resetCalls = 0
C_DamageMeter = {
    ResetAllCombatSessions = function()
        resetCalls = resetCalls + 1
    end,
}
menuRoot.entries[6].choose()
assert(resetCalls == 1)
local opened
app.core = {
    OpenOptions = function(_, addon, tab)
        opened = addon .. ":" .. tab
    end,
}
menuRoot.entries[1].choose()
assert(opened == "SeamlessDamageMeter:windows")
SettingsPanel = {
    Close = function(_, skip)
        assert(skip)
    end,
}
EditModeManagerFrame = {}
ShowUIPanel = function(panel)
    assert(panel == EditModeManagerFrame)
    opened = "editmode"
end
menuRoot.entries[2].choose()
assert(opened == "editmode")
app.RefreshWindows = oldRefresh
Menu.GetManager = oldManager
MenuUtil.CreateRootMenuDescription = oldDescription
print("Damage meter settings menu regressions OK")
meter.config.noninteractive = true
app:RefreshWindow(meter, { combatSources = {}, maxAmount = 1 })
assert(meter.mouseEnabled == false and meter.title.mouseEnabled == false)
assert(meter.statistic.mouseEnabled == false and meter.session.mouseEnabled == false)
assert(meter.resize.mouseEnabled == false and meter.scrollbar.mouseEnabled == false)
meter.config.noninteractive = false
app:RefreshWindow(meter, { combatSources = {}, maxAmount = 1 })
assert(meter.mouseEnabled and meter.title.mouseEnabled and meter.session.mouseEnabled)
print("Damage meter noninteractive regressions OK")
