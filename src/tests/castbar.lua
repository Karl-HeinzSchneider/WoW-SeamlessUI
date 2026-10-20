-- Run from the repository root: lua src/tests/castbar.lua
local root = "SeamlessCastbar/src/"

-- Locale: the English baseline through the real AceLocale.
GetLocale = function()
    return "enUS"
end
geterrorhandler = function()
    return function(message)
        error(message)
    end
end
dofile("Seamless/lib/LibStub/LibStub.lua")
dofile("Seamless/lib/AceLocale-3.0/AceLocale-3.0.lua")
dofile("Seamless/locales/enUS.lua")

local spellNames = { [689] = "Drain Life", [5143] = "Arcane Missiles", [10] = "Blizzard" }
local subtexts = { [116] = "Rank 3", [133] = "" }
C_Spell = {
    GetSpellName = function(spellID)
        return spellNames[spellID]
    end,
    GetSpellSubtext = function(spellID)
        return subtexts[spellID]
    end,
}
local channel
UnitChannelInfo = function()
    return channel
end

local function FontString(text)
    local shown = true
    return {
        GetText = function()
            return text
        end,
        SetText = function(_, value)
            text = value
        end,
        SetPoint = function() end,
        Show = function()
            shown = true
        end,
        Hide = function()
            shown = false
        end,
        IsShown = function()
            return shown
        end,
    }
end
local function Texture()
    local texture = FontString()
    texture.points = {}
    texture.SetAtlas = function() end
    texture.SetWidth = function() end
    texture.ClearAllPoints = function(self)
        self.points = {}
    end
    texture.SetPoint = function(self, point, _, _, x)
        self.points[point] = x
    end
    return texture
end
local function Animation(field, value)
    local animation = { [field] = value }
    animation.GetStartDelay = function(self)
        return self.startDelay
    end
    animation.SetStartDelay = function(self, delay)
        self.startDelay = delay
    end
    animation.GetDuration = function(self)
        return self.duration
    end
    animation.SetDuration = function(self, duration)
        self.duration = duration
    end
    return animation
end
local function Bar(name, ownCastTime)
    local value, max = 0, 0
    local bar = {
        unit = name,
        Text = FontString("Frostbolt"),
        Icon = FontString(),
        CastTimeText = ownCastTime and FontString() or nil,
        textures = {},
        GetValue = function()
            return value
        end,
        SetValue = function(_, v)
            value = v
        end,
        GetMinMaxValues = function()
            return 0, max
        end,
        SetMinMaxValues = function(_, _, m)
            max = m
        end,
        GetWidth = function()
            return 100
        end,
        CreateFontString = function(self)
            self.ownText = FontString()
            return self.ownText
        end,
        CreateTexture = function(self)
            local texture = Texture()
            self.textures[#self.textures + 1] = texture
            return texture
        end,
    }
    local fade, hold = Animation("startDelay", 0.2), Animation("duration", 1)
    bar.FadeOutAnim = {
        GetAnimations = function()
            return fade
        end,
    }
    bar.HoldFadeOutAnim = {
        GetAnimations = function()
            return hold
        end,
    }
    return bar, fade, hold
end

local app = {}
local function load(file)
    assert(loadfile(root .. file))("SeamlessCastbar", app)
end
load("text.lua")
load("ticks.lua")
load("hold.lua")
app.db = {
    profile = {
        bars = { player = true, target = true, focus = true },
        castTime = { enabled = true, format = "ELAPSED_TOTAL", decimals = 1 },
        rank = { enabled = true },
        ticks = { enabled = true },
        icon = { enabled = true },
        hold = { enabled = true, success = 0.5, interrupt = 2 },
    },
}
local keys = {}
app.BarKey = function(bar)
    return keys[bar]
end
app.Active = function(bar)
    return keys[bar] ~= nil and app.db.profile.bars[keys[bar]]
end

-- Formats
assert(app.FormatCastTime(1.23, 2.5, "ELAPSED_TOTAL", 1) == "1.2 / 2.5")
assert(app.FormatCastTime(1.23, 2.5, "REMAINING_TOTAL", 1) == "1.3 / 2.5")
assert(app.FormatCastTime(1.23, 2.5, "REMAINING", 2) == "1.27")
assert(app.FormatCastTime(4, 3, "ELAPSED_TOTAL", 0) == "3 / 3", "clamped, no decimals")

-- Target: our own text; a channel's value is the time left.
local target = Bar("target")
keys[target] = "target"
target:SetMinMaxValues(0, 2.5)
target:SetValue(1.23)
target.casting = true
app.UpdateCastTime(target)
assert(target.ownText:GetText() == "1.2 / 2.5")
target.casting, target.channeling = nil, true
target:SetValue(2)
app.UpdateCastTime(target)
assert(target.ownText:GetText() == "0.5 / 2.5", "channel elapsed")
app.db.profile.bars.target = false
app.UpdateCastTime(target)
assert(not target.ownText:IsShown(), "hidden when the bar is switched off")
app.db.profile.bars.target = true

-- Player: the game's own text is reformatted, nothing created.
local player = Bar("player", true)
keys[player] = "player"
player:SetMinMaxValues(0, 2)
player:SetValue(0.5)
player.casting = true
app.UpdateCastTime(player)
assert(player.CastTimeText:GetText() == "0.5 / 2.0" and not player.ownText)

-- Rank, idempotent and restored.
player.spellID = 116
app.UpdateName(player)
assert(player.Text:GetText() == "Frostbolt (Rank 3)")
app.UpdateName(player)
assert(player.Text:GetText() == "Frostbolt (Rank 3)", "idempotent")
app.db.profile.rank.enabled = false
app.UpdateName(player)
assert(player.Text:GetText() == "Frostbolt", "restored")
app.db.profile.rank.enabled = true
player.spellID = 133
app.UpdateName(player)
assert(player.Text:GetText() == "Frostbolt", "no rank")

-- Icon: only on the detached player bar.
player.look = "CLASSIC"
player.Icon:Hide()
app.UpdateIcon(player)
assert(player.Icon:IsShown())
app.db.profile.icon.enabled = false
app.UpdateIcon(player)
assert(not player.Icon:IsShown(), "icon restored")
target.look = "UNITFRAME"
target.Icon:Hide()
app.UpdateIcon(target)
assert(not target.Icon:IsShown(), "target icon left alone")

-- Ticks
local times = app.TickTimes(1, 5)
assert(#times == 4 and times[1] == 1 and times[4] == 4)
assert(#app.TickTimes(1, 3) == 2, "Arcane Missiles rank 1")
assert(#app.TickTimes(3, 15) == 4, "Drain Soul")
assert(#app.TickTimes(1, 4.3) == 4, "pushed back")
channel = "Drain Life"
target:SetMinMaxValues(0, 5)
app.UpdateTicks(target)
assert(#target.textures == 4)
assert(math.abs(target.textures[1].points.TOP - 80) < 1e-6, "first tick near the full end")
target.channeling = nil
target.casting = true
app.UpdateTicks(target)
assert(not target.textures[1]:IsShown(), "hidden on casts")
channel = "Mind Control"
target.channeling = true
app.UpdateTicks(target)
assert(not target.textures[1]:IsShown(), "unknown channel")

-- Hold
local focus, fade, hold = Bar("focus")
keys[focus] = "focus"
app.ApplyHold(focus)
assert(fade.startDelay == 0.5 and hold.duration == 2)
app.ApplyHold(focus)
app.db.profile.hold.enabled = false
app.ApplyHold(focus)
assert(fade.startDelay == 0.2 and hold.duration == 1, "hold restored")

print("PASS: cast time formats, rank, icon, channel ticks and hold time")
