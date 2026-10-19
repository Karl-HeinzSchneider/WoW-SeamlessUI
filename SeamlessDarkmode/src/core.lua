---@type string, SeamlessDarkmode
local appName, app = ...

app.core = LibStub("AceAddon-3.0"):GetAddon("Seamless")
app.addon = LibStub("AceAddon-3.0"):NewAddon(appName, "AceConsole-3.0")

-- A texture's color before it was first tinted, restored when darkmode is switched off.
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
    local defaults = { enabled = true, color = { r = 0.22, g = 0.22, b = 0.22 } }
    app.db = LibStub("AceDB-3.0"):New("SeamlessDarkmodeDB", { profile = defaults }, true)
    app.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
    app.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
    app.db.RegisterCallback(self, "OnProfileReset", "Refresh")
    self:RegisterChatCommand("seamlessdarkmode", function()
        app.core:OpenOptions(appName)
    end)
end

function app.addon:OnEnable()
    self:Refresh()
end

function app.addon:OnDisable()
    for _, frame in ipairs(app.frames) do
        frame(restore)
    end
end

-- Runs every frame function, tinting or restoring by the current profile.
function app.addon:Refresh()
    if not self:IsEnabled() then
        return
    end
    local paint = app.db.profile.enabled and tint or restore
    for _, frame in ipairs(app.frames) do
        frame(paint)
    end
end
