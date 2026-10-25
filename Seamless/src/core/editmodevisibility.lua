---@type string, SeamlessCore
local _, app = ...

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

local function applyPending()
    local pending = pendingSettings()
    if not pending or not next(pending) or not canApply() then
        return
    end
    local lib = LibStub("LibEditModeOverride-1.0")
    for setting, value in pairs(pending) do
        local ok, err = pcall(lib.SetGlobalSetting, lib, setting, value and 1 or 0)
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
        applyPending()
    end
    if pending and pending[setting] ~= nil then
        return pending[setting]
    end
    return LibStub("LibEditModeOverride-1.0"):GetGlobalSetting(setting) == 1
end

app.LibEditMode:RegisterCallback("enter", applyPending)
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", applyPending)
