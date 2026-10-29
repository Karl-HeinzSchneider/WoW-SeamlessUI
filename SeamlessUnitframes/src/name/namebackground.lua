---@type string, SeamlessUnitframes
local _, app = ...

---@class SeamlessUnitframes.NameBackground : AceModule, AceEvent-3.0
local module = {}
app.nameBackground = app.addon:NewModule("NameBackground", module, "AceEvent-3.0") --[[@as SeamlessUnitframes.NameBackground]]

-- Every skin uses the native reputation texture. Alpha preserves its native visibility and tint.
---@type table<Texture, boolean>
local hidden = {}
---@type table<Texture, boolean>
local hooked = {}

local function ShouldHide(key)
    return app.addon:IsEnabled() and app.db.profile.unitFrames[key].hideNameBackground
end

local function HookBackground(background, key)
    if hooked[background] then
        return
    end
    hooked[background] = true
    local applying = false
    local function Repair()
        if applying or not ShouldHide(key) then
            return
        end
        applying = true
        background:SetAlpha(0)
        hidden[background] = true
        applying = false
    end
    -- Native reaction updates can restore opacity when the unit changes. Repair only this
    -- texture, synchronously, without inspecting possibly secret color/alpha arguments.
    hooksecurefunc(background, "SetAlpha", Repair)
    hooksecurefunc(background, "SetVertexColor", Repair)
end

function module:Refresh()
    for _, key in ipairs({ "target", "focus" }) do
        local frame = key == "target" and TargetFrame or FocusFrame
        local content = frame and frame.TargetFrameContent
        local main = content and content.TargetFrameContentMain
        local background = main and main.ReputationColor
        if background then
            HookBackground(background, key)
            if ShouldHide(key) then
                background:SetAlpha(0)
                hidden[background] = true
            elseif hidden[background] then
                background:SetAlpha(1)
                hidden[background] = nil
            end
        end
    end
end

function module:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
    self:Refresh()
end

function module:OnDisable()
    self:Refresh()
end

function module:OnProfileRefresh()
    self:Refresh()
end
