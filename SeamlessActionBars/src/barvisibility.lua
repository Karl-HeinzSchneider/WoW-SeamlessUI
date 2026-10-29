---@type string, SeamlessActionBars
local appName, app = ...

local module = app.addon:NewModule("BarVisibility")
local events = CreateFrame("Frame")
local frames = { microMenu = "MicroMenuContainer", bags = "BagsBar" }
local managed = {}
local active = false
local editing = false

-- Only call visibility methods when a hide option requires a change, or when
-- restoring a frame we changed. Never replace Blizzard methods or hook OnShow.
function app.RefreshBarVisibility()
    if InCombatLockdown() then
        return
    end
    for key, name in pairs(frames) do
        local frame = _G[name]
        local settings = app.db and app.db.profile[key]
        local hide = active and app.addon:IsEnabled() and settings and settings.hidden
        local state = managed[key]
        if frame and hide then
            if not state then
                state = { shown = frame:IsShown(), changed = false }
                managed[key] = state
            end
            if frame:IsShown() ~= editing then
                state.changed = true
                if editing then
                    frame:Show()
                else
                    frame:Hide()
                end
            end
        elseif state and frame then
            if state.changed and frame:IsShown() ~= state.shown then
                if state.shown then
                    frame:Show()
                else
                    frame:Hide()
                end
            end
            managed[key] = nil
        end
    end
    if not active and not next(managed) then
        events:UnregisterAllEvents()
    end
end

function module:OnInitialize()
    local lib = app.core:GetEditModeLibrary()
    for _, event in ipairs({ "enter", "exit" }) do
        lib:RegisterCallback(event, function()
            editing = event == "enter"
            app.RefreshBarVisibility()
        end)
    end
    lib:RegisterCallback("layout", app.RefreshBarVisibility)
end

function module:OnEnable()
    active = true
    editing = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() or false
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    app.RefreshBarVisibility()
end

function module:OnDisable()
    active = false
    events:UnregisterAllEvents()
    -- Keep restoration alive if the addon is disabled during combat.
    if next(managed) then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    app.RefreshBarVisibility()
end

events:SetScript("OnEvent", app.RefreshBarVisibility)

function app.BarHiddenOption(key, name, order)
    return {
        type = "toggle",
        name = name,
        order = order,
        default = false,
        get = function()
            return app.db.profile[key].hidden
        end,
        set = function(_, value)
            app.db.profile[key].hidden = value
            app.RefreshBarVisibility()
            app.core:RefreshOptions(appName)
        end,
    }
end
