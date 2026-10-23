-- Run from the repository root: lua src/tests/damage-meter-windows.lua
unpack = unpack or table.unpack
local methods = {}
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
    assert(template == nil, "Meter windows must not inherit templates or create Core panel controls")
    local frame = object(parent)
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
dofile("src/tests/locale-support.lua")
assert(loadfile("SeamlessDamageMeter/src/db.lua"))("SeamlessDamageMeter", app)
assert(loadfile("SeamlessDamageMeter/src/settings.lua"))("SeamlessDamageMeter", app)
app.db.profile.windowDefaults = app.windowDefaults
assert(app.windowDefaults.fixedHeight and app.windowDefaults.visibleLines == 7)
app.db.profile.windowDefaults.fixedHeight = false
dofile("src/tests/locale-support.lua")
assert(loadfile("SeamlessDamageMeter/src/data.lua"))("SeamlessDamageMeter", app)
for _, name in ipairs({ "archive", "live", "service", "breakdowns", "capture" }) do
    dofile("src/tests/locale-support.lua")
    assert(loadfile("SeamlessDamageMeter/src/" .. name .. ".lua"))("SeamlessDamageMeter", app)
end
app.combatService:Initialize({})
dofile("src/tests/locale-support.lua")
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
assert(
    #app.windows == app.MAX_WINDOWS and #app.db.profile.windows == app.MAX_WINDOWS,
    "Every slot must exist from startup"
)
for id = 2, app.MAX_WINDOWS do
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
local arrowAnchor = frame.statistic.arrow.points.CENTER
assert(
    frame.statistic:GetWidth() > 25
        and arrowAnchor[2] == frame.statistic
        and arrowAnchor[3] == "LEFT"
        and arrowAnchor[4] == 12.5,
    "Nested view keeps the type arrow in its left slot while the selector widens"
)
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
local openTypeMenu
MenuUtil = {
    CreateRootMenuDescription = function()
        menuRoot = menuDescription()
        return menuRoot
    end,
    CreateContextMenu = function(owner, generator)
        menuRoot = menuDescription()
        generator(owner, menuRoot)
        openTypeMenu = {
            GetOwnerRegion = function()
                return owner
            end,
        }
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
            GetOpenMenu = function()
                return openTypeMenu
            end,
            CloseMenu = function(_, menu)
                assert(menu == openTypeMenu)
                openTypeMenu = nil
            end,
            OpenMenu = function(_, owner, root, anchor)
                openTypeMenu = nil -- Opening another menu replaces the type menu.
                assert(owner == frame.session and root == menuRoot)
                assert(anchor[1] == "BOTTOMRIGHT" and anchor[2] == owner and anchor[3] == "TOPRIGHT")
                assert(anchor[5] > 0, "Session menu must prefer opening above the selector")
            end,
        }
    end,
}
frame.statistic.scripts.OnClick()
assert(openTypeMenu and openTypeMenu:GetOwnerRegion() == frame.statistic)
local firstTypeRoot = menuRoot
frame.statistic.scripts.OnClick()
assert(openTypeMenu == nil and menuRoot == firstTypeRoot, "Second selector click closes without reopening")
frame.statistic.scripts.OnClick()
assert(openTypeMenu and menuRoot ~= firstTypeRoot, "Third selector click opens a fresh menu")
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
frame.config.overrides.numbers = "minimal"
app:RefreshWindows()
assert(frame.rows[1].value:IsShown() and not frame.rows[1].secondaryValue:IsShown())
assert(not frame.rows[1].percentageValue:IsShown(), "Minimal hides the share column")
frame.config.overrides.numbers = "compact"
frame.config.statistic = "Dps"
app:RefreshWindows()
assert(frame.rows[1].value.text == "3" and frame.rows[1].secondaryValue:IsShown())
assert(not frame.rows[1].percentageValue:IsShown(), "Compact shows rate and total without share")
frame.config.overrides.numbers = "complete"
app:RefreshWindows()
assert(frame.rows[1].secondaryValue:IsShown() and frame.rows[1].percentageValue:IsShown())
frame.config.overrides.numbers = nil
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
assert(#app.db.profile.windows == app.MAX_WINDOWS and not frame:IsShown() and not second:IsShown())
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
inherited.config.position.scale = 1.5
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
app:SetWindowEnabled(second.config, true)
inherited.title.scripts.OnDragStart(inherited.title)
inherited.title.scripts.OnDragStop(inherited.title)
assert(inherited.config.anchorTo == nil and inherited.anchorTarget == UIParent, "A dragged window leaves its anchor")
assert(app:GetWindowSetting(inherited.config, "relativePoint") == app:GetWindowSetting(inherited.config, "point"))
inherited.config.anchorTo = second.config.id
inherited.config.position = app:NewWindowPosition()
app:SetWindowEnabled(second.config, false)
app.core = { logger = { chat = function() end } }
for _ = 1, 12 do
    app:AddWindow()
end
assert(#app.db.profile.windows == app.MAX_WINDOWS, "All creation paths must enforce the window limit")
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
assert(allocated == app.MAX_WINDOWS, "Repeated removal and creation must not grow the frame pool")
print("Damage meter window regressions OK")

-- Exercise LibEditMode's public settings and movement callback contract.
local registered = 0
local callbacks, controls, moves, buttons = {}, {}, {}, {}
local editing = false
local combat = false
function InCombatLockdown()
    return combat
end
function methods:GetScale()
    return self.scale or 1
end
app.core.RefreshOptions = function() end
app.addon = {
    IsEnabled = function()
        return true
    end,
}
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
local lem = { SettingType = { Slider = 1, Checkbox = 2, Dropdown = 3, Divider = "divider", Header = "header" } }
function lem:AddFrame(frame, callback, defaults, name)
    assert(name == "Seamless Damage " .. frame.windowID)
    assert(defaults.point == "CENTER")
    registered = registered + 1
    frame.Selection = setmetatable({}, {
        __index = function()
            error("Selection is owned by LibEditMode")
        end,
        __newindex = function()
            error("Selection is owned by LibEditMode")
        end,
    })
    moves[frame] = callback
end
function lem:AddFrameSettings(frame, settings)
    controls[frame] = settings
end
function lem:AddFrameSettingsButtons(frame, settings)
    buttons[frame] = settings
end
function lem:RegisterCallback(event, callback)
    callbacks[event] = callback
end
function lem:RefreshFrameSettings() end
function lem:IsInEditMode()
    return editing
end
local editModeOptions
app.core.RegisterEditModeOptions = function(_, id, spec)
    assert(id == "SeamlessDamageMeter" and not editModeOptions)
    editModeOptions = spec
end
app.core.GetEditModeLibrary = function()
    return lem
end
local positionSpecs = {}
app.core.GetEditModePositionSettings = function(_, spec)
    positionSpecs[#positionSpecs + 1] = spec
    return { { name = "Position", kind = lem.SettingType.Header }, { name = "X", kind = lem.SettingType.Slider } }
end
app.db.profiles = { Original = app.db.profile }
EventRegistry = { TriggerEvent = function() end }
EditModeManagerFrame = {
    -- Accessing native layout containers would risk tainting Blizzard's Edit Mode setup.
    AccountSettings = setmetatable({}, {
        __index = function()
            error("Do not access native layout containers")
        end,
    }),
    EnterEditMode = function()
        editing = true
        callbacks.enter()
    end,
    ExitEditMode = function()
        editing = false
        callbacks.exit()
    end,
}
dofile("src/tests/locale-support.lua")
assert(loadfile("SeamlessDamageMeter/src/editmode.lua"))("SeamlessDamageMeter", app)
combat = false
app:RebuildWindows()
assert(registered == app.MAX_WINDOWS)
callbacks.layout("Modern")
local meter = app.windowFrames[1]
local function setting(name)
    for _, entry in ipairs(controls[meter]) do
        if entry.name == name then
            return entry
        end
    end
    error("Missing control: " .. name)
end
EditModeManagerFrame:EnterEditMode()
assert(meter:IsShown())
local order = {}
for index, entry in ipairs(controls[meter]) do
    order[entry.name] = index
end
assert(order.Position == 1 and order["Lock position outside Edit Mode"] == 2 and order.Position < order.X)
assert(order.X < order.Window and order.Window < order["Lock size"])
assert(order.Style + 1 == order.Numbers and order.Numbers + 1 == order.Skin, "Numbers opens the Style section")
local positionSpec = positionSpecs[1]
assert(positionSpec.get("relativeTo") == (meter.config.anchorTo and tostring(meter.config.anchorTo) or "screen"))
assert(positionSpec.get("point") == app:GetWindowSetting(meter.config, "point"))
positionSpec.set("x", 123)
assert(meter.config.position.x == 123, "Position X edits the window offset")
assert(positionSpec.anchorFrames()[1].value == "screen")
for _, entry in ipairs(positionSpec.anchorFrames()) do
    assert(entry.value ~= tostring(meter.config.id), "a window never anchors to itself")
end
assert(order.Skin < order["Modify global style"] and order["Modify global style"] < order["Bar height"])
assert(setting("Style").kind == lem.SettingType.Header)
assert(setting("Window").kind == lem.SettingType.Header and controls[meter][1].kind == lem.SettingType.Header)
assert(setting("Modify global style").default and setting("Modify global style").get())
local sharedStyle = app.db.profile.skins[meter.config.skin].settings
local sharedHeight, sharedAlpha, sharedClasses =
    sharedStyle.rowHeight, sharedStyle.backgroundColor[4], sharedStyle.classColors
setting("Modify global style").set(nil, false)
setting("Bar height").set(nil, 31)
setting("Background").set(nil, 25)
setting("Show class color").set(nil, false)
assert(app:GetWindowSetting(meter.config, "rowHeight") == 31)
assert(app:GetWindowSetting(meter.config, "backgroundColor")[4] == 0.25)
assert(app:GetWindowSetting(meter.config, "classColors") == false)
assert(sharedStyle.rowHeight == sharedHeight and sharedStyle.backgroundColor[4] == sharedAlpha)
assert(sharedStyle.classColors == sharedClasses)
assert(app:GetWindowSetting(app.windowFrames[2].config, "rowHeight") == sharedHeight)
app:PrepareWindowSettings()
app:RebuildWindows()
assert(setting("Bar height").get() == 31, "Rebuilding preserves local appearance overrides")
setting("Modify global style").set(nil, true)
assert(setting("Bar height").get() == sharedHeight, "Global mode uses the shared style")
setting("Modify global style").set(nil, false)
assert(setting("Bar height").get() == 31, "Local mode restores saved overrides")
setting("Modify global style").set(nil, true, true)
assert(meter.config.styleOverrides == nil, "Reset clears local appearance overrides")
assert(setting("Numbers").default == "complete" and setting("Numbers").get() == "complete")
assert(setting("Show type selector").default and setting("Show type selector").get())
setting("Show type selector").set(nil, false)
assert(not meter.statistic.arrow:IsShown() and not meter.statistic.mouseEnabled)
assert(not setting("Show type selector").get())
setting("Show type selector").set(nil, true)
assert(meter.statistic.arrow:IsShown() and meter.statistic.mouseEnabled)
setting("Numbers").set(nil, "minimal")
assert(setting("Numbers").get() == "minimal")
assert(app:GetWindowSetting(app.windowFrames[2].config, "numbers") == "complete")
setting("Numbers").set(nil, "complete")
setting("Frame width").set(nil, 615)
assert(app:GetWindowSetting(meter.config, "width") == 615)
setting("Lock size").set(nil, true)
assert(setting("Frame width").disabled())
setting("Frame width").set(nil, 700)
assert(app:GetWindowSetting(meter.config, "width") == 615)
setting("Lock position outside Edit Mode").set(nil, true)
meter:SetPoint("CENTER", UIParent, "CENTER", 250, 150)
moves[meter](meter, "Modern", "CENTER", 250, 150)
assert(meter.config.position.x == 250, "Edit Mode moves persist while locked outside Edit Mode")
-- An Edit Mode move releases the moved window's anchor; windows anchored to it keep theirs.
local follower = app.windowFrames[2]
local followerEnabled = follower.config.enabled
follower.config.enabled = true
meter.config.anchorTo, follower.config.anchorTo = 3, 1
app:RebuildWindows()
assert(meter.anchorTarget == app.windowFrames[3] and follower.anchorTarget == meter)
moves[meter](meter, "Modern", "TOPLEFT", 40, -60)
assert(meter.config.anchorTo == nil and meter.anchorTarget == UIParent, "A moved window leaves its anchor")
assert(meter.config.position.point == "TOPLEFT" and meter.config.position.relativePoint == "TOPLEFT")
assert(meter.config.position.x == 40 and meter.config.position.y == -60)
assert(meter.config.editModeLayouts.Modern.anchorTo == nil, "The released anchor is saved in the layout")
assert(follower.config.anchorTo == 1 and follower.anchorTarget == meter, "Dependents keep following")
follower.config.anchorTo, follower.config.enabled = nil, followerEnabled
app:RebuildWindows()
setting("Lock position outside Edit Mode").set(nil, false)
setting("Bar height").set(nil, 29)
assert(app:GetWindowSetting(meter.config, "rowHeight") == 29)
local firstConfig = meter.config
local otherProfile = { windows = {}, windowDefaults = app.windowDefaults, skins = {} }
local originalProfile = app.db.profile
app.db.profile = otherProfile
app.db.profiles.Other = otherProfile
app:ApplyEditModeLayout()
app:RebuildWindows()
assert(meter.config ~= firstConfig)
setting("Frame width").set(nil, 530)
assert(app:GetWindowSetting(meter.config, "width") == 530)
app.db.profile = originalProfile
app:ApplyEditModeLayout()
app:RebuildWindows()
assert(setting("Frame width").get() == 615 and registered == app.MAX_WINDOWS)
callbacks.layout("Modern")
assert(setting("Frame width").default == app.windowDefaults.width)
assert(setting("Bar height").default == 24, "Defaults must not capture customized skin values")
meter.config.anchorTo = nil
moves[meter](meter, "Modern", "TOPLEFT", 80, -90)
assert(meter.config.position.point == "TOPLEFT" and meter.config.position.x == 80)
assert(meter.config.editModeLayouts.Modern.x == 80)
callbacks.create("Copied", 4, "Modern")
assert(meter.config.editModeLayouts.Copied.x == 80)
callbacks.layout("Copied")
setting("Lock size").set("Copied", false)
setting("Frame width").set("Copied", 540)
callbacks.layout("Modern")
assert(setting("Frame width").get() == 615, "Switching layouts restores geometry")
callbacks.rename("Copied", "Renamed")
callbacks.layout("Renamed")
assert(setting("Frame width").get() == 540)
assert(meter.config.editModeLayouts.Copied == nil)
callbacks.layout("Modern")
callbacks.delete("Renamed")
assert(meter.config.editModeLayouts.Renamed == nil)
setting("Lock size").set("Modern", true)
setting("Frame width").set("Modern", setting("Frame width").default, true)
assert(setting("Frame width").get() == app.windowDefaults.width, "Reset must bypass size lock")
setting("Lock size").set("Modern", false)
setting("Frame width").set("Modern", 615)
setting("Lock size").set("Modern", true)
assert(registered == app.MAX_WINDOWS, "Layouts and profiles must reuse registered frames")
local liveAPIForPreview = C_DamageMeter
C_DamageMeter = setmetatable({}, {
    __index = function(_, key)
        return function()
            error("Preview queried live API: " .. key)
        end
    end,
})
meter.config.collapsed = true
app:RebuildWindows()
assert(meter.body:IsShown() and meter.config.collapsed)
assert(meter.session.text.text == "Preview")
local previewStatistic = meter.config.statistic
for _, statistic in ipairs({ "DamageDone", "HealingDone", "Dps", "Hps", "Interrupts", "Dispels" }) do
    meter.config.statistic = statistic
    local preview = app:GetPreviewSession(meter.config)
    local total = 0
    for _, source in ipairs(preview.combatSources) do
        total = total + source.totalAmount
    end
    assert(preview.totalAmount == total and total > 0, "Preview shares use the sum of sample amounts")
    app:RefreshWindows()
    assert(meter.rows[1].percentageValue:IsShown())
    assert(meter.rows[1].percentageValue.args[1] > 0, "Complete previews display a percentage")
end
meter.config.statistic = previewStatistic
app:RefreshWindows()
assert(editModeOptions.enabled())
local group = editModeOptions.options[1]
group.set(false)
assert(not meter:IsShown() and meter.config.enabled)
group.set(true)
assert(meter:IsShown())
C_DamageMeter = liveAPIForPreview
combat = true
setting("Frame width").set(nil, 780)
assert(setting("Frame width").get() == 615)
combat = false
EditModeManagerFrame:ExitEditMode()
setting("Frame width").set(nil, 780)
assert(app:GetWindowSetting(meter.config, "width") == 615, "Ignore callbacks outside Edit Mode")
print("Damage meter LibEditMode regressions OK")

app.db.profile.skins[meter.config.skin].settings.rowHeight = 24
meter.config.collapsed = false
meter.config.hidden = false
meter.config.enabled = true
meter.config.overrides.lockSize = false
app:RebuildWindows()
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
assert(opened == "SeamlessDamageMeter:window1")
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
