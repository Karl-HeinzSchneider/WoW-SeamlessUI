---@type string, SeamlessCore
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local lastRead = {}

local function traceRead(setting, source, value)
    local state = source .. ":" .. tostring(value)
    if lastRead[setting] ~= state then
        lastRead[setting] = state
        app.logger:debug(
            L["Edit Mode visibility: read setting=%s source=%s value=%s"],
            tostring(setting),
            source,
            tostring(value)
        )
    end
end

local function pendingSettings()
    if not app.db then
        return nil
    end
    app.db.global.editModeVisibilityPending = app.db.global.editModeVisibilityPending or {}
    return app.db.global.editModeVisibilityPending
end

local function canApply()
    return not InCombatLockdown() and EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
end

local function applyPending(source)
    local pending = pendingSettings()
    local count = 0
    for _ in pairs(pending or {}) do
        count = count + 1
    end
    app.logger:debug(
        L["Edit Mode visibility: flush source=%s pending=%s database=%s active=%s combat=%s"],
        tostring(source),
        tostring(count),
        tostring(app.db ~= nil),
        tostring(EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()),
        tostring(InCombatLockdown())
    )
    if not pending or not next(pending) or not canApply() then
        return
    end
    local lib = LibStub("LibEditModeOverride-1.0")
    for setting, value in pairs(pending) do
        app.logger:debug(
            L["Edit Mode visibility: applying setting=%s value=%s"],
            tostring(setting),
            tostring(value and 1 or 0)
        )
        local ok, err = pcall(lib.SetGlobalSetting, lib, setting, value and 1 or 0)
        app.logger:debug(
            L["Edit Mode visibility: result setting=%s success=%s error=%s"],
            tostring(setting),
            tostring(ok),
            tostring(err)
        )
        if ok then
            pending[setting] = nil
        else
            app.logger:warn("%s", err)
        end
    end
end

---Read the pending choice (including false), or the library's saved account value.
---Writes outside Edit Mode wait for the next entry; writes inside apply directly.
---@param setting number EditModeAccountSetting ID.
---@param value? boolean
---@return boolean
function app.addon:EditModeVisibility(setting, value)
    assert(type(setting) == "number", "Edit Mode visibility requires an account-setting ID")
    assert(value == nil or type(value) == "boolean", "Edit Mode visibility requires a boolean")
    local pending = pendingSettings()
    if value ~= nil then
        assert(pending, "Edit Mode visibility requires an initialized database")
        pending[setting] = value
        lastRead[setting] = nil
        app.logger:debug(L["Edit Mode visibility: queued setting=%s value=%s"], tostring(setting), tostring(value))
        applyPending("write")
    end
    if pending and pending[setting] ~= nil then
        traceRead(setting, "pending", pending[setting])
        return pending[setting]
    end
    local saved = LibStub("LibEditModeOverride-1.0"):GetGlobalSetting(setting)
    traceRead(setting, "library", saved)
    return saved == 1
end

app.LibEditMode:RegisterCallback("enter", function()
    applyPending("LibEditMode.enter")
end)
for _, event in ipairs({ "exit", "layout" }) do
    app.LibEditMode:RegisterCallback(event, function()
        app.logger:debug(L["Edit Mode visibility: event=%s"], "LibEditMode." .. event)
    end)
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
events:SetScript("OnEvent", function(_, event)
    app.logger:debug(L["Edit Mode visibility: event=%s"], tostring(event))
    if event == "PLAYER_REGEN_ENABLED" then
        applyPending(event)
    end
end)
