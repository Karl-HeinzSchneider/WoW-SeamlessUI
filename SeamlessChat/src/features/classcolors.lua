---@type string, SeamlessChat
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Class colored names: every player name in the chat in its class color, for all chat types at
-- once. The game has this per chat type (chat settings) plus an overriding CVar,
-- chatClassColorOverride: "0" colors every name, "1" none, anything else leaves it to the types.
-- This sets it to "0" while enabled and restores the previous value when disabled.
---@class SeamlessChat.ClassColors : SeamlessChat.Feature
local module = {}

---@class SeamlessChat.ClassColorSettings : SeamlessChat.FeatureSettings
app.features:New("classColors", module)

-- The CVar's value before this feature changed it (account-wide, like the CVar).
---@class SeamlessChat.DB.Global
---@field classColorOverrideBefore string?

local CVAR = "chatClassColorOverride"
local ALL_COLORED = "0"

function module:OnEnable()
    local current = C_CVar.GetCVar(CVAR)
    if current ~= ALL_COLORED then
        app.db.global.classColorOverrideBefore = current
        C_CVar.SetCVar(CVAR, ALL_COLORED)
    end
end

function module:OnDisable()
    local before = app.db.global.classColorOverrideBefore
    if before then
        C_CVar.SetCVar(CVAR, before)
        app.db.global.classColorOverrideBefore = nil
    end
end
