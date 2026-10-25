unpack = unpack or table.unpack
-- Settings declarations are the source for frame details; flags never reach AceConfig.
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
function LibStub()
    return {
        NotifyChange = function() end,
        GetLocale = function()
            return L
        end,
    }
end
local combat = false
function InCombatLockdown()
    return combat
end
local app = { addon = {}, options = { panels = {} } }
assert(loadfile("Seamless/src/config/registry.lua"))("Seamless", app)
assert(loadfile("Seamless/src/config/model.lua"))("Seamless", app)
local value, disabled, hidden = 1, false, false
local paths = {}
local root = {
    type = "group",
    name = "Addon",
    args = {
        frame = {
            type = "group",
            name = "Frame",
            args = {
                first = {
                    type = "range",
                    order = 1,
                    name = "First",
                    editMode = true,
                    default = 1,
                    min = 0,
                    max = 10,
                    step = 1,
                    disabled = function()
                        return disabled
                    end,
                    hidden = function()
                        return hidden
                    end,
                },
                advanced = { type = "input", order = 2, name = "Advanced", hideInEditmode = true },
                explicit = { type = "toggle", order = 3, name = "Explicit", hideInEditmode = false },
                group = {
                    type = "group",
                    order = 4,
                    name = "Group",
                    args = {
                        color = { type = "color", order = 1, name = "Color" },
                        action = { type = "execute", order = 2, name = "Action" },
                    },
                },
                last = {
                    type = "select",
                    order = 5,
                    name = "Last",
                    values = { a = "A", b = "B" },
                    sorting = { "b", "a" },
                },
                excluded = {
                    type = "group",
                    order = 6,
                    name = "Excluded",
                    hideInEditmode = true,
                    args = { child = { type = "toggle", name = "Child", hideInEditmode = false } },
                },
                message = { type = "description", order = 7, name = "Message" },
            },
            get = function(info)
                paths[#paths + 1] = table.concat(info, "/")
                return value
            end,
            set = function(info, newValue)
                paths[#paths + 1] = table.concat(info, "/")
                value = newValue
            end,
        },
    },
}
app.options.panels.Addon = { options = root }
local core = app.addon
local function rows()
    local result = {}
    for _, section in ipairs(core:GetEditModeOptionSections("Addon", { "frame" })) do
        for _, row in ipairs(section.options) do
            result[#result + 1] = row
        end
    end
    return result
end
local result = rows()
assert(#result == 6, "Every supported option mirrors by default; true excludes a subtree")
assert(result[1].option:Read("name") == "First")
assert(result[2].option:Read("name") == "Explicit")
assert(result[3].option:Read("type") == "color")
assert(result[4].option:Read("type") == "execute")
assert(result[5].option:Read("name") == "Last", "Sibling ordering survives nested groups")
assert(result[6].option:Read("type") == "description")
assert(result[1].option:InEditModeLayout(), "The editMode badge is independent of hideInEditmode visibility")
assert(result[1].option:Read("get") == 1)
assert(result[1].set(7))
assert(value == 7 and paths[1] == "frame/first" and paths[2] == "frame/first")
assert(result[1].option:DefaultValue() == 1)
assert(result[5].option:Choices()[1].value == "b")
disabled = true
assert(result[1].disabled())
disabled, combat = false, true
assert(result[1].disabled())
combat, hidden = false, true
assert(result[1].hidden() and #rows() == 5)
hidden = false
local args = root.args.frame.args
assert(args.advanced.hideInEditmode == nil and args.explicit.hideInEditmode == nil and args.first.editMode == nil)
app.config:NormalizeOptionTags(root)
assert(app.config:GetOptionTags(args.advanced).hideInEditmode == true, "Normalization retains explicit true")
args.advanced.hideInEditmode = false
assert(#rows() == 7, "Changing a flag takes effect on refresh")
args.group.hideInEditmode = true
assert(#rows() == 5)
assert(#core:GetEditModeOptionSections("Addon", { "frame", "group" }) == 0)
assert(#core:GetEditModeOptionSections("Addon", { "missing" }) == 0)
assert(not pcall(function()
    app.config:NormalizeOptionTags({ hideInEditmode = "yes" })
end))
local frame, enabled = {}, true
core:RegisterEditModeSettings(
    function()
        return frame
    end,
    "Addon",
    { "frame" },
    function()
        return enabled
    end
)
local sections, owners = core:GetEditModeSettingsSections(frame)
assert(#sections > 0 and owners.Addon)
enabled = false
sections, owners = core:GetEditModeSettingsSections(frame)
assert(#sections == 0 and not owners.Addon)
assert(#core:GetEditModeSettingsSections({}) == 0)
assert(#core:GetEditModeOptionSections("Addon", { "frame", "first" }) == 1, "Bindings can target a single option")
print("PASS: default Edit Mode mirroring, opt-outs, metadata, ordering, callbacks and dynamic state")

enabled = true
local positionArgs = {
    x = { type = "range", name = "X", hideInEditmode = true },
    y = { type = "range", name = "Y" },
}
args.position = { type = "group", name = "Position", args = positionArgs }
app.config.positionGroups[positionArgs] = true
local position = { id = "position", options = { { key = "x" }, { key = "y" }, { key = "revert" } } }
local filtered = core:FilterEditModePositionSection(frame, position)
assert(filtered.options[1].hidden() and not filtered.options[2].hidden())
assert(not position.options[1].hidden, "Position filtering does not mutate cached rows")
args.position.hideInEditmode = true
filtered = core:FilterEditModePositionSection(frame, position)
assert(filtered.options[2].hidden() and filtered.options[3].hidden(), "Position group opt-out includes its actions")
print("PASS: shared Position controls honor declaration opt-outs without duplication")

assert(result[1].type == "range" and result[2].type == "toggle", "Declarations use the existing details row types")
assert(result[4].type == "button" and result[6].type == "text")
local cached = rows()[1]
assert(cached == result[1], "Stable row identity preserves slider and typed-input state across layouts")
local first = args.first
first.validate = function(_, value)
    return value >= 0
end
assert(not cached.set(-1) and value == 7, "Mirrored setters preserve validation")
first.validate = nil
local pending
function StaticPopup_Show(_, _, _, callback)
    pending = callback
end
first.confirm = true
assert(cached.set(4) and value == 7 and pending, "Confirmation happens before applying")
pending()
assert(value == 4)
first.confirm = nil
print("PASS: existing row schemas, stable identity, validation and confirmation")
