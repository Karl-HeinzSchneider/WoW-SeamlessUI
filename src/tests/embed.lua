-- Empty shipped page, opt-in adapter lifecycle and current-profile bindings.
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
function LibStub(name)
    assert(name == "AceLocale-3.0")
    return {
        GetLocale = function()
            return L
        end,
    }
end
local app = { addon = {}, optionPages = {} }
function app.addon:NewModule(name, module)
    assert(name == "Embed")
    return module
end
assert(loadfile("Seamless/src/config/schema.lua"))("Seamless", app)
assert(loadfile("Seamless/src/embed/embed.lua"))("Seamless", app)
local page = app.optionPages.embed
assert(page.config.type == "group" and page.config.name == "Embed")
assert(next(page.config.args) == nil and next(page.defaults.profile.embed) == nil)
app.embed:OnProfileRefresh() -- Core refreshes before module startup, without a database.
local enabled, disabled, refreshed = 0, 0, 0
local spec = {
    name = "Test addon",
    enable = function()
        enabled = enabled + 1
    end,
    disable = function()
        disabled = disabled + 1
    end,
    refresh = function()
        refreshed = refreshed + 1
    end,
}
app.embed:Register("test", spec)
assert(not pcall(function()
    app.embed:Register("test", spec)
end))
assert(not pcall(function()
    app.embed:Register("missingCallbacks", { name = "Invalid" })
end))
app.embed:OnProfileRefresh()
assert(enabled == 0 and disabled == 0)
local defaults = app.addon:GetOptionsDefaults(app.optionPages)
assert(defaults.profile.embed.test == false)
app.db = { profile = { embed = { test = false } } }
assert(not pcall(function()
    app.embed:Register("late", spec)
end))
app.embed:OnEnable()
assert(enabled == 0 and disabled == 0)
local toggle = page.config.args.test
assert(toggle.name == spec.name and toggle.type == "toggle" and toggle.default == false)
toggle.set(nil, true)
assert(toggle.get() == true and enabled == 1)
app.embed:OnProfileRefresh()
assert(enabled == 1 and refreshed == 1)
-- Switch/reset/copy profiles without retaining a reference to the previous profile.
local previous = app.db.profile
app.db.profile = { embed = { test = false } }
app.embed:OnProfileRefresh()
assert(disabled == 1 and toggle.get() == false)
assert(previous.embed.test == true)
app.db.profile = { embed = { test = true } }
app.embed:OnProfileRefresh()
assert(enabled == 2)
app.embed:OnDisable()
assert(disabled == 2 and toggle.get() == true) -- Disabling Core preserves the saved choice.
app.embed:OnProfileRefresh()
assert(disabled == 2)
app.embed:OnEnable()
assert(enabled == 3)
toggle.set(nil, false)
assert(disabled == 3 and toggle.get() == false)
app.embed:OnDisable()
assert(disabled == 3)
local toc = assert(io.open("Seamless/Seamless.toc"))
local entries = 0
for line in toc:lines() do
    if line:gsub("\\", "/"):match("^src/embed/") then
        assert(line:gsub("\\", "/"):match("^src/embed/embed%.xml\r?$"))
        entries = entries + 1
    end
end
toc:close()
assert(entries == 1)
local xml = assert(io.open("Seamless/src/embed/embed.xml"))
assert(xml:read("*a"):find('file="embed.lua"', 1, true))
xml:close()
print("Embed empty page, opt-in lifecycle, profile changes and isolated loader passed")
