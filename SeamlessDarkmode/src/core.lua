---@type string, SeamlessDarkmode
local appName, app = ...

app.core = LibStub("AceAddon-3.0"):GetAddon("Seamless")
app.addon = LibStub("AceAddon-3.0"):NewAddon(appName, "AceConsole-3.0")

-- A texture's color before it was first tinted, restored when its group is switched off.
---@type table<Texture, number[]>
local originals = setmetatable({}, { __mode = "k" })

---@param texture Texture?
local function tint(texture)
    if not texture then
        return
    end
    local original = originals[texture]
    if not original then
        original = { texture:GetVertexColor() }
        originals[texture] = original
    end
    local color = app.db.profile.color
    texture:SetVertexColor(color.r, color.g, color.b, original[4])
end

---@param texture Texture?
local function restore(texture)
    local original = texture and originals[texture]
    if original then
        texture:SetVertexColor(original[1], original[2], original[3], original[4])
        originals[texture] = nil
    end
end

function app.addon:OnInitialize()
    local defaults = { enabled = true, color = { r = 0.22, g = 0.22, b = 0.22 }, groups = {} }
    for _, group in ipairs(app.groups) do
        defaults.groups[group.key] = true
    end
    app.db = LibStub("AceDB-3.0"):New("SeamlessDarkmodeDB", { profile = defaults }, true)
    app.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
    app.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
    app.db.RegisterCallback(self, "OnProfileReset", "Refresh")
    self:RegisterChatCommand("seamlessdarkmode", function()
        app.core:OpenOptions(appName)
    end)
end

function app.addon:OnEnable()
    local icons = LibStub("LibDBIcon-1.0", true)
    if icons then
        icons.RegisterCallback(self, "LibDBIcon_IconCreated", "Refresh")
    end
    self:Refresh()
end

function app.addon:OnDisable()
    local icons = LibStub("LibDBIcon-1.0", true)
    if icons then
        icons.UnregisterCallback(self, "LibDBIcon_IconCreated")
    end
    for _, group in ipairs(app.groups) do
        for _, frame in ipairs(group.frames) do
            frame(restore)
        end
    end
end

-- Runs every frame function of every group, tinting or restoring by the current profile.
function app.addon:Refresh()
    if not self:IsEnabled() then
        return
    end
    local profile = app.db.profile
    for _, group in ipairs(app.groups) do
        local paint = (profile.enabled and profile.groups[group.key]) and tint or restore
        for _, frame in ipairs(group.frames) do
            frame(paint)
        end
    end
end
