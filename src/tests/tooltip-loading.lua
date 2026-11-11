-- Load real Tooltip feature modules before their page declarations, without an AceDB instance.
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
function LibStub(name)
    assert(name == "AceLocale-3.0", name)
    return {
        GetLocale = function()
            return L
        end,
    }
end
local function newModule(self, name, prototype)
    local module = setmetatable({ moduleName = name, modules = {} }, { __index = prototype })
    module.NewModule = newModule
    function module:GetModule(key)
        return assert(self.modules[key], key)
    end
    function module:IterateModules()
        return pairs(self.modules)
    end
    self.modules[name] = module
    return module
end
local app = {
    addon = { modules = {}, NewModule = newModule },
    core = {},
    media = {
        LSM = { MediaType = {} },
        Values = function()
            return {}
        end,
    },
    unitTooltip = {},
}
Enum = { TooltipDataType = {}, TooltipDataLineType = {} }
NORMAL_FONT_COLOR = {
    WrapTextInColorCode = function(_, text)
        return text
    end,
}
GRAY_FONT_COLOR = NORMAL_FONT_COLOR
C_CVar = {
    GetCVar = function()
        return "1"
    end,
}
C_UnitAuras = {}
C_Item = {
    GetItemQualityColor = function(quality)
        return quality / 7, 0.5, 1
    end,
}
function CreateColor(r, g, b)
    return {
        WrapTextInColorCode = function(_, name)
            return ("%.2f:%.2f:%.2f:%s"):format(r, g, b, name)
        end,
    }
end
for quality = 0, 7 do
    _G["ITEM_QUALITY" .. quality .. "_DESC"] = "Quality " .. quality
end
local function loadFile(file)
    assert(loadfile("SeamlessTooltip/" .. file))("SeamlessTooltip", app)
end
loadFile("src/core/db.lua")
loadFile("src/core/features.lua")
local toc = assert(io.open("SeamlessTooltip/SeamlessTooltip.toc"))
local count = 0
for line in toc:lines() do
    local file = line:gsub("\\", "/"):match("^(src/features/[^\r]+%.lua)")
    if file then
        loadFile(file)
        count = count + 1
    end
end
toc:close()
assert(count == 24 and app.db == nil, "All runtime features load before AceDB")
dofile("src/tests/settings-support.lua").pages("SeamlessTooltip", app)
local quality = app.optionPages.items.config.args.QualityBorder.args.minQuality
assert(#quality.sorting == 8 and quality.sorting[1] == 0 and quality.sorting[8] == 7)
assert(quality.values[2] == "0.29:0.50:1.00:Quality 2")
assert(app.features:GetModule("QualityBorder").info == nil, "Settings belong to the page")
local painted
app.features.ItemLink = function()
    return "item:123"
end
issecretvalue = function()
    return false
end
app.border = {
    Paint = function(_, r, g, b)
        painted = { r, g, b }
    end,
}
app.db = { profile = { features = { QualityBorder = { minQuality = 2 } } } }
C_Item.GetItemQualityByID = function()
    return 3
end
app.features:GetModule("QualityBorder"):OnItemTooltip({}, {})
assert(painted[1] == 3 / 7 and painted[2] == 0.5 and painted[3] == 1)

-- Blizzard's damage meter anchors spell tooltips to a Texture, not a Frame. Such owners have
-- no GetAttribute; ordinary owners still follow the cursor and unit frames keep their anchor.
local cursorAnchor = app.features:GetModule("CursorAnchor")
local cursorSettings = { position = "ANCHOR_CURSOR_RIGHT", offsetX = 12, offsetY = -8 }
app.db.profile.features.CursorAnchor = cursorSettings
local calls = {}
local tooltip = {
    ClearAllPoints = function()
        calls[#calls + 1] = "clear"
    end,
    SetOwner = function(_, owner, position, x, y)
        calls[#calls + 1] = { owner, position, x, y }
    end,
}
local function isNotForbidden()
    return false
end
UIParent = { IsForbidden = isNotForbidden }
local texture = { IsForbidden = isNotForbidden }
local frame = {
    IsForbidden = isNotForbidden,
    GetAttribute = function(_, key)
        assert(key == "unit")
    end,
}
for _, owner in ipairs({ texture, frame, UIParent }) do
    calls = {}
    cursorAnchor:AnchorToCursor(tooltip, owner)
    assert(#calls == 2 and calls[1] == "clear")
    assert(calls[2][1] == owner and calls[2][2] == "ANCHOR_CURSOR_RIGHT")
    assert(calls[2][3] == 12 and calls[2][4] == -8)
end
local function unexpectedAttribute()
    error("Unit fields and forbidden owners must be checked before attributes")
end
local unitFrame = { IsForbidden = isNotForbidden, unit = "player", GetAttribute = unexpectedAttribute }
local secureUnitFrame = {
    IsForbidden = isNotForbidden,
    GetAttribute = function(_, key)
        assert(key == "unit")
        return "target"
    end,
}
local forbiddenOwner = {
    IsForbidden = function()
        return true
    end,
    GetAttribute = unexpectedAttribute,
}
calls = {}
cursorAnchor:AnchorToCursor(tooltip, nil)
for _, owner in ipairs({ unitFrame, secureUnitFrame, forbiddenOwner }) do
    cursorAnchor:AnchorToCursor(tooltip, owner)
end
assert(#calls == 0, "Unit frames, forbidden owners and absent owners keep the default anchor")

-- Exercise both entry points Blizzard uses to lay out the backdrop: applying media and resizing.
local secret = {}
issecretvalue = function(value)
    return value == secret
end
local width, height = secret, 40
local layouts = 0
local function setAlpha(self, alpha)
    self.alpha = alpha
end
GameTooltip = { NineSlice = { SetAlpha = setAlpha } }
local backdrop = {
    GetWidth = function()
        return width
    end,
    GetHeight = function()
        return height
    end,
    GetEffectiveScale = function()
        return 1
    end,
    SetupTextureCoordinates = function()
        local aspect = width / height
        assert(aspect > 0)
        layouts = layouts + 1
    end,
    SetBackdrop = function(self, info)
        self.backdropInfo = info
        if info then
            self:SetupTextureCoordinates()
        end
    end,
    SetAlpha = setAlpha,
    SetAllPoints = function() end,
    SetUsingParentLevel = function() end,
    SetBackdropColor = function() end,
    SetBackdropBorderColor = function() end,
    Show = function() end,
    Hide = function() end,
}
function CreateFrame(_, _, parent, template)
    assert(parent == GameTooltip and template == "BackdropTemplate")
    return backdrop
end
app.media.LSM.RegisterCallback = function() end
app.media.LSM.UnregisterCallback = function() end
app.media.Fetch = function(_, key)
    return key
end
app.border.SetFrame = function() end
app.db.profile.features.Backdrop = app.optionPages.general.defaults.profile.features.Backdrop
local backdropFeature = app.features:GetModule("Backdrop")
backdropFeature:OnEnable()
assert(layouts == 0 and backdrop.alpha == 0 and GameTooltip.NineSlice.alpha == 1)
width = 80
backdrop:SetupTextureCoordinates()
assert(layouts == 1 and backdrop.alpha == 1 and GameTooltip.NineSlice.alpha == 0)
height = secret
backdrop:SetupTextureCoordinates()
assert(layouts == 1 and backdrop.alpha == 0 and GameTooltip.NineSlice.alpha == 1)
backdropFeature:OnDisable()
assert(backdrop.backdropInfo == nil and GameTooltip.NineSlice.alpha == 1)
print("Tooltip runtime feature loading, page quality choices, border behavior, cursor anchoring and backdrop OK")
