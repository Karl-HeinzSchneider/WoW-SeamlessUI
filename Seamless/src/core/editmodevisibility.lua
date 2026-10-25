---@type string, SeamlessCore
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local lastRead = {}
local bindings = {}
local applying = false
local enterScheduled = false

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
    if applying or not pending or not next(pending) or not canApply() then
        return
    end
    applying = true
    for setting, value in pairs(pending) do
        app.logger:debug(
            L["Edit Mode visibility: applying setting=%s value=%s"],
            tostring(setting),
            tostring(value and 1 or 0)
        )
        local ok, err = pcall(function()
            local binding =
                assert(bindings[setting], L["No Edit Mode visibility binding for setting %s."]:format(setting))
            binding.set(value)
            assert(binding.get() == value, L["Edit Mode visibility readback mismatch for setting %s."]:format(setting))
        end)
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
    applying = false
end

---Read the pending choice (including false), or the registered visibility binding.
---Writes outside Edit Mode wait for the next entry; writes inside apply directly.
---@param setting number|string Account-setting ID or namespaced custom-frame ID.
---@param value? boolean
---@return boolean
function app.addon:EditModeVisibility(setting, value)
    assert(type(setting) == "number" or type(setting) == "string", "Edit Mode visibility requires a setting ID")
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
    local binding = bindings[setting]
    local saved = binding and binding.get() or false
    traceRead(setting, type(setting) == "number" and "library" or "custom", saved)
    return saved
end

---Register a frame's in-place refresh and return its settings-header callback.
---Registration is safe at file load; the database is read only when the callback runs.
---@param setting number
---@param update fun(value: boolean)
---@return fun(value?: boolean): boolean
function app.addon:GetEditModeVisibility(setting, update)
    assert(type(setting) == "number" and type(update) == "function", "Invalid Edit Mode visibility binding")
    bindings[setting] = {
        get = function()
            return LibStub("LibEditModeOverride-1.0"):GetGlobalSetting(setting) == 1
        end,
        set = function(value)
            LibStub("LibEditModeOverride-1.0"):SetGlobalSetting(setting, value and 1 or 0)
            update(value)
        end,
    }
    return function(value)
        return self:EditModeVisibility(setting, value)
    end
end

---Bind an addon-owned frame to the same persistent queue and Edit Mode guards.
---@param id string Namespaced frame ID.
---@param get fun(): boolean
---@param set fun(value: boolean)
---@return fun(value?: boolean): boolean
function app.addon:GetCustomEditModeVisibility(id, get, set)
    assert(
        type(id) == "string" and id ~= "" and type(get) == "function" and type(set) == "function",
        "Invalid custom visibility binding"
    )
    bindings[id] = { get = get, set = set }
    return function(value)
        return self:EditModeVisibility(id, value)
    end
end
app.LibEditMode:RegisterCallback("enter", function()
    if applying then
        return
    end
    -- Wait until native entry setup has finished, without changing window visibility.
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
        applyPending(event)
    end
end)
