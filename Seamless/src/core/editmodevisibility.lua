---@type string, SeamlessCore
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local lastRead = {}
local refresh
local enterScheduled = false

local function restoreEditMode()
    if not refresh or not refresh.finished or not refresh.layoutUpdated or refresh.scheduled then
        return
    end
    refresh.scheduled = true
    C_Timer.After(0, function()
        refresh.scheduled = false
        if InCombatLockdown() then
            return
        end
        local ok, err = pcall(function()
            if not EditModeManagerFrame:IsEditModeActive() then
                ShowUIPanel(EditModeManagerFrame)
            end
        end)
        app.logger:debug(
            L["Edit Mode visibility: refresh stage=%s success=%s error=%s"],
            "restore",
            tostring(ok),
            tostring(err)
        )
        refresh = nil
    end)
end

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
    if refresh or not pending or not next(pending) or not canApply() then
        return
    end
    local lib = LibStub("LibEditModeOverride-1.0")
    local loaded, loadError = pcall(lib.LoadLayouts, lib)
    if not loaded then
        app.logger:warn("%s", loadError)
        return
    end
    refresh = { finished = false, layoutUpdated = false }
    local written = {}
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
            written[setting] = value
        else
            app.logger:warn("%s", err)
        end
    end
    if not next(written) then
        refresh = nil
        return
    end
    local applied, applyError = pcall(lib.ApplyChanges, lib)
    app.logger:debug(
        L["Edit Mode visibility: refresh stage=%s success=%s error=%s"],
        "apply",
        tostring(applied),
        tostring(applyError)
    )
    if not applied then
        app.logger:warn("%s", applyError)
        refresh = nil
        return
    end
    -- A setter succeeding is insufficient: only retire choices after the batch
    -- refresh succeeds and its saved value can be read back through the library.
    for setting, value in pairs(written) do
        local ok, saved = pcall(lib.GetGlobalSetting, lib, setting)
        if ok and saved == (value and 1 or 0) and pending[setting] == value then
            pending[setting] = nil
        end
    end
    refresh.finished = true
    restoreEditMode()
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
    if refresh then
        return
    end
    -- Leave the native entry stack before the library cycles Edit Mode.
    if not enterScheduled then
        enterScheduled = true
        C_Timer.After(0, function()
            enterScheduled = false
            applyPending("LibEditMode.enter")
        end)
    end
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
        restoreEditMode()
        applyPending(event)
    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" and refresh then
        refresh.layoutUpdated = true
        restoreEditMode()
    end
end)
