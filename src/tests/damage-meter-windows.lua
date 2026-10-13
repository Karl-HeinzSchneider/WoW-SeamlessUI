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
function methods:SetParent(parent)
    self.parent = parent
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
    assert(template == nil, "Meter frames must not inherit templates")
    local frame = object(parent)
    if name then
        assert(_G[name] == nil, "Named frames must be reused")
        _G[name] = frame
    end
    return frame
end
RAID_CLASS_COLORS = { MAGE = { r = 0.2, g = 0.5, b = 1 } }
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
LibStub = function()
    return {
        Fetch = function()
            return "test-font"
        end,
    }
end
assert(loadfile("SeamlessDamageMeter/src/settings.lua"))("SeamlessDamageMeter", app)
app.db.profile.windowDefaults = app.windowDefaults
assert(loadfile("SeamlessDamageMeter/src/data.lua"))("SeamlessDamageMeter", app)
assert(loadfile("SeamlessDamageMeter/src/windows.lua"))("SeamlessDamageMeter", app)
app:RebuildWindows()
local frame = app.windows[1]
assert(frame.statistic.arrow:IsShown() and frame.statistic.mouseEnabled, "Type selector is visible by default")
local categoryAnchor = frame.statistic.text.points.TOPLEFT
assert(categoryAnchor[4] == 25 and categoryAnchor[5] == -9, "Category text must sit at the reference header height")
local categoryWidth = frame.statistic.text:GetWidth()
frame.config.overrides.hideTypeSelector = true
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
frame.config.overrides.hideTypeSelector = false
app:RebuildWindows()
assert(frame.statistic.arrow:IsShown() and frame.statistic.mouseEnabled, "Selector can be restored")
assert(frame.statistic.points.TOPLEFT[2] == frame and frame.statistic.points.TOPLEFT[4] == 3)
assert(frame.timer.points.LEFT[2] == frame.statistic.text, "Timer follows the category label")
assert(frame.timer:IsShown(), "Combat timer is visible by default")
app.db.profile.windowDefaults.hideCombatTimer = true
app:RebuildWindows()
assert(not frame.timer:IsShown(), "Combat timer inherits the shared hide setting")
frame.config.overrides.hideCombatTimer = false
app:RebuildWindows()
assert(frame.timer:IsShown(), "A false override restores the combat timer")
frame.config.overrides.hideCombatTimer = true
app:RebuildWindows()
assert(not frame.timer:IsShown(), "A window override hides the combat timer")
frame.config.overrides.hideCombatTimer = nil
app.db.profile.windowDefaults.hideCombatTimer = false
app:RebuildWindows()
assert(#app.windows == 10 and #app.db.profile.windows == 10, "Every slot must exist from startup")
for id = 2, 10 do
    assert(app.windowFrames[id] and not app.windowFrames[id]:IsShown())
end
assert(SeamlessDamageMeterWindow1 == frame and frame.windowID == 1)
assert(frame.rows[1]:GetHeight() == 24 and frame.rows[1].entry:GetHeight() == 24)
assert(frame.rows[1].icon:GetWidth() == 24 and frame.rows[1].icon:GetHeight() == 24)
assert(frame:IsShown() and frame.scrollbar:IsShown())
assert(frame.rows[1].name.args[2] == secret)
assert(frame.rows[1].value.args[1] == secret)
assert(frame.rows[1].value.args[2] == secret, "Restricted rates must also go directly to the widget")
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
frame.rows[1].entry.scripts.OnEnter()
assert(sourceReads == 1 and detailGUID == "player-1")
local tooltip = app.detailTooltip
local detailBar = tooltip.rows[1]
assert(tooltip.owner == frame.rows[1] and tooltip:GetFrameStrata() == "TOOLTIP")
assert(tooltip.header == nil and tooltip.title == nil, "The detail panel has no header")
assert(tooltip.points.BOTTOMLEFT[2] == frame.rows[1].entry and tooltip.points.BOTTOMLEFT[3] == "TOPLEFT")
assert(tooltip.points.BOTTOMRIGHT[2] == frame.rows[1].entry and tooltip.points.BOTTOMRIGHT[3] == "TOPRIGHT")
assert(tooltip.points.BOTTOMLEFT[4] == 0 and tooltip.points.BOTTOMLEFT[5] == 0)
assert(
    tooltip.points.BOTTOMRIGHT[4] == 0 and tooltip.points.BOTTOMRIGHT[5] == 0,
    "Panel matches the bar edges above it"
)
assert(detailBar.value.args[1] == secret and detailBar.value.args[2] == secret)
assert(detailBar.maximum == secret and detailBar.statusValue == secret, "Restricted bar scales go to widget setters")
assert(detailBar.fill.texture == frame.rows[1].fill.texture, "Detail and main bars share the exact texture")
assert(detailBar.icon.texture == 1001, "Spell icons come from C_Spell")
assert(detailBar:GetHeight() == frame.rows[1]:GetHeight() and detailBar.icon:GetWidth() == 24)
assert(detailBar.color[1] == RAID_CLASS_COLORS.MAGE.r)
assert(detailBar.entry.points.TOPLEFT[3] == 0, "First bar begins at the top with no header gap")
assert(
    not tooltip.mouseEnabled and not detailBar.entry.mouseEnabled,
    "The hover panel does not steal the owner's mouse"
)
app:RefreshWindows()
assert(tooltip:IsShown() and sourceReads == 2, "Live refresh preserves and updates the hover")
frame.rows[1].entry.scripts.OnLeave()
assert(not tooltip:IsShown() and tooltip.owner == nil)
app:RefreshWindows()
assert(not tooltip:IsShown(), "Refresh must not reopen a tooltip after leaving")
session.combatSources[12].sourceCreatureID = 42
frame.localRow.entry.scripts.OnEnter()
assert(detailCreature == 42, "Pinned rows support creature source IDs")
assert(tooltip.points.BOTTOMLEFT[2] == frame.localRow.entry and tooltip.points.BOTTOMRIGHT[2] == frame.localRow.entry)
frame.localRow.entry.scripts.OnLeave()
details.totalAmount = 100
details.combatSpells[1].totalAmount, details.combatSpells[1].amountPerSecond = 25, 5
frame.rows[1].entry.scripts.OnEnter()
assert(detailBar.value.args[3] == 25, "Public values include the spell's percentage share")
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
assert(detailBar.value.args[1] == "5" and detailBar.value.args[2] == "25", "DPS uses rate before total")
frame.config.statistic = "DamageDone"
frame.config.overrides.rowHeight, frame.config.overrides.rowSpacing = 30, 6
frame.config.overrides.classColors = false
app:RefreshWindows()
assert(
    detailBar:GetHeight() == 30 and detailBar.icon:GetWidth() == 30,
    "Detail rows inherit owner appearance overrides"
)
assert(detailBar.color[1] == app:GetWindowSetting(frame.config, "barColor")[1])
frame.config.overrides.rowHeight, frame.config.overrides.rowSpacing, frame.config.overrides.classColors = nil, nil, nil
app:RefreshWindows()
frame.rows[1].entry.scripts.OnLeave()
assert(details.combatSpells[1].name == nil, "Returned spell tables stay untouched")
history = { { sessionID = 77 } }
C_DamageMeter.GetCombatSessionSourceFromID = function(id, meterType, guid)
    assert(id == 77 and meterType == 0 and guid == "player-1")
    return details
end
frame.config.sessionID = 77
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
details.combatSpells = { firstSpell }
app:RefreshWindows()
assert(tooltip.offset == 0 and not tooltip.rows[2]:IsShown(), "Shrinking detail lists hide pooled surplus bars")
details.combatSpells = {}
app:RefreshWindows()
assert(not tooltip:IsShown(), "Empty data hides the headerless panel")
details.combatSpells = { firstSpell }
frame.rows[1].entry.scripts.OnEnter()
frame.rows[1].entry.scripts.OnHide()
assert(not tooltip:IsShown(), "Hiding the owner entry dismisses the panel")
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
frame.rows[1].entry.scripts.OnLeave()
frame.config.statistic = "DamageDone"
app:RefreshWindows()
C_DeathRecap = nil
assert(frame.statistic:GetFrameLevel() == 2 and frame.session:GetFrameLevel() == 2)
-- Exercise the actual button callbacks, menu selection and API routing together.
local menuRoot
local function menuDescription(label)
    local description = { label = label, entries = {} }
    function description:CreateButton(text, choose)
        local child = menuDescription(text)
        child.choose = choose
        table.insert(self.entries, child)
        return child
    end
    function description:CreateRadio(text, selected, choose)
        local child = { label = text, selected = selected, choose = choose }
        table.insert(self.entries, child)
        return child
    end
    function description:CreateDivider()
        table.insert(self.entries, { divider = true })
    end
    return description
end
MenuUtil = {
    CreateContextMenu = function(owner, generator)
        menuRoot = menuDescription()
        generator(owner, menuRoot)
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
assert(fight.label == "Combat 42 [15]" and otherFight.label == "Boss")
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
assert(frame.favorites:IsShown(), "Replacing a favorite keeps the shortcuts open")
favorite.scripts.OnClick(favorite, "RightButton")
menuRoot.entries[#menuRoot.entries].choose()
assert(app.db.profile.favorites[1] == nil and favorite.row.name.text == "+ Set favorite")
local selector = frame.favorites.buttons[7]
assert(selector.row.name.text == "Select type" and selector.number.text == "")
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
assert(frame.rows[1].value.args[1] == "12345" and frame.rows[1].value.args[2] == "2.8")
frame.config.statistic = "Dps"
app:RefreshWindows()
assert(frame.rows[1]:IsShown())
assert(
    frame.rows[1].value.args[1] == "2.8" and frame.rows[1].value.args[2] == "12345",
    "Rate display must swap primary and secondary values"
)
frame.config.statistic = "Interrupts"
Enum.DamageMeterType.Interrupts = 2
app:RefreshWindows()
assert(frame.rows[1].value.text == "12345", "Action counts must not show a rate")
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
slot.config.overrides.fontSize = 20
app:RebuildWindows()
assert(not slot:IsShown() and app:GetUnusedWindowSlot() == nil, "Hidden windows must retain their slot")
local previousConfig = slot.config
app:SetWindowEnabled(previousConfig, false)
assert(slot.config == previousConfig and not slot:IsShown())
assert(app:GetUnusedWindowSlot() == 3)
app:AddWindow()
assert(app.windowFrames[3] == slot and slot:IsShown(), "Reactivation must reuse the slot's frame")
assert(slot.config == previousConfig and slot.config.overrides.fontSize == 20)
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
    frame.EMECheckButtonFrame = object(frame)
    frame.Selection = object(frame)
    self.baseFramesDB[frame.system], self.framesDB[frame.system] = db, db
    frame.EMECheckButtonFrame:SetScript("OnClick", function(button, mouseButton)
        if mouseButton == "LeftButton" then
            self.framesDB[frame.system].enabled = button:GetChecked()
            frame:SetShown(button:GetChecked())
        end
    end)
    frame.SetScaleOverride = frame.SetScale
end
function eme:RegisterResizable(frame, minimum, maximum, step)
    assert(minimum == 50 and maximum == 200 and step == 5)
end
function eme:RegisterSlider(frame, name, key, callback, minimum, maximum, step)
    assert(name == (key == "width" and "Width" or "Height"))
    assert(minimum == (key == "width" and 200 or 120))
    assert(maximum == (key == "width" and 800 or 900) and step == 1)
    frame.editModeSliders = frame.editModeSliders or {}
    frame.editModeSliders[key] = callback
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
local function ClickWindow(frame, enabled, mouseButton)
    local button = frame.EMECheckButtonFrame
    button:SetChecked(enabled)
    button:GetScript("OnClick")(button, mouseButton or "LeftButton")
end
ClickWindow(meter, true)
assert(meter:IsShown(), "Checking a slot must show its preview")
assert(meter.config.enabled and not meter.config.hidden, "Checking must activate and unhide the real slot")
meter.config.enabled = true
app:RebuildWindows()
meter.config.editMode.profiles["1-Other"] = { enabled = true, settings = {} }
meter.config.enabled = false
app:RebuildWindows()
assert(not meter:IsShown(), "Deactivating a slot must reset its Edit Mode preview")
assert(not meter.config.editMode.profiles["1-Other"].enabled, "Deactivation must update other native layouts")
ClickWindow(meter, true)
app:RebuildWindows()
assert(meter:IsShown() and meter.config.enabled, "Activation survives ordinary rebuilds")
meter:SetScaleOverride(1.25)
assert(meter.config.overrides.scale == 1.25)
assert(eme.framesDB[meter.system].settings[16] ~= nil)
local originalDatabase = meter.config.editMode
app.db.profile = { windows = {}, initialized = false, windowDefaults = app.windowDefaults }
app:RebuildWindows()
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
ClickWindow(meter, false)
assert(not meter:IsShown() and not meter.config.enabled, "Unchecking must deactivate the real slot")
ClickWindow(meter, true)
ClickWindow(meter, false, "RightButton")
assert(meter.config.enabled, "The library's right-click reset must not deactivate a slot")
EditModeManagerFrame:ExitEditMode()
assert(meter:IsShown() and meter.config.enabled, "A checked slot must remain usable after Edit Mode")

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
