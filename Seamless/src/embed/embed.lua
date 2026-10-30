---@type string, SeamlessCore
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessCore.EmbedSpec
---@field name string Localized checkbox label.
---@field order? number
---@field enable fun() Start the embedded runtime using the current profile.
---@field disable fun() Stop its runtime without affecting standalone owners.
---@field refresh? fun() Reapply the current profile to an already running runtime.

---@class SeamlessCore.Embed : AceModule
---@field active? boolean
local module = {}
app.embed = app.addon:NewModule("Embed", module) --[[@as SeamlessCore.Embed]]

---@type table<string, SeamlessCore.EmbedSpec>
local entries = {}
local running = {}
local defaults = { profile = { embed = {} } }
local controls = {}

-- Kept beside the optional loader so removing embed.xml removes the page too.
app.optionPages.embed = {
    defaults = defaults,
    config = { type = "group", name = L["Embed"], order = 600, args = controls },
}

-- Call from an adapter loaded by embed.xml before AceDB and options initialize.
function module:Register(id, spec)
    assert(not app.db, "Register embedded addons at file load")
    assert(type(id) == "string" and id ~= "" and not entries[id], "Invalid or duplicate embed ID")
    assert(
        type(spec.name) == "string" and type(spec.enable) == "function" and type(spec.disable) == "function",
        "Embed requires a name, enable and disable callbacks"
    )
    entries[id] = spec
    defaults.profile.embed[id] = false
    controls[id] = {
        type = "toggle",
        name = spec.name,
        order = spec.order,
        default = false,
        get = function()
            return app.db.profile.embed[id]
        end,
        set = function(_, value)
            app.db.profile.embed[id] = value
            self:OnProfileRefresh()
        end,
    }
end

function module:OnProfileRefresh()
    for id, spec in pairs(entries) do
        local enabled = not not (self.active and app.db.profile.embed[id])
        if enabled ~= not not running[id] then
            if enabled then
                spec.enable()
            else
                spec.disable()
            end
            running[id] = enabled
        elseif enabled and spec.refresh then
            spec.refresh()
        end
    end
end

function module:OnEnable()
    self.active = true
    self:OnProfileRefresh()
end

function module:OnDisable()
    self.active = false
    self:OnProfileRefresh()
end
