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
assert(count == 23 and app.db == nil, "All runtime features load before AceDB")
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
print("Tooltip runtime feature loading, page quality choices and border behavior OK")
