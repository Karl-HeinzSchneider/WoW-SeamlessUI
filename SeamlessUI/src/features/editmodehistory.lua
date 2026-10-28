---@type string, SeamlessUI
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessUI.EditModeHistory : AceModule, AceEvent-3.0
local module = app.addon:NewModule("EditModeHistory", "AceEvent-3.0") --[[@as SeamlessUI.EditModeHistory]]
app.editModeHistory = module
module:SetEnabledState(false)
local lib = app.core:GetEditModeLibrary()
local position = app.core:GetFramePositionService()
local LIMIT = 25
local history, baseline = {}, {}
local window, list, undo, status, scroll
local active, restoring, elapsed = false, false, 0

local function equal(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not equal(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end
local function copy(value)
    return type(value) == "table" and CopyTable(value) or value
end
local function disabled(source)
    return type(source.disabled) == "function" and source.disabled() or source.disabled == true
end

function module:GetSources()
    local sources = app.core:GetEditModeHistorySources()
    local manager = EditModeManagerFrame
    for _, frame in ipairs(manager.registeredSystemFrames or {}) do
        local info = manager:GetActiveLayoutSystemInfo(frame.system, frame.systemIndex)
        if info then
            sources[#sources + 1] = {
                frame = frame,
                key = "native:position",
                name = L["Dragged"],
                disabled = function()
                    return not position:CanEdit(frame)
                end,
                get = function()
                    local current = manager:GetActiveLayoutSystemInfo(frame.system, frame.systemIndex)
                    return {
                        anchorInfo = current.anchorInfo,
                        anchorInfo2 = current.anchorInfo2,
                        isInDefaultPosition = current.isInDefaultPosition,
                    }
                end,
                set = function(value)
                    return position:Apply(frame, CopyTable(value.anchorInfo), value)
                end,
            }
            for _, setting in ipairs(info.settings or {}) do
                local id = setting.setting
                local display = frame.settingDisplayInfoMap and frame.settingDisplayInfoMap[id]
                sources[#sources + 1] = {
                    frame = frame,
                    key = "native:setting:" .. id,
                    name = display and display.name or L["Settings changed"],
                    disabled = function()
                        return not position:CanEdit(frame)
                    end,
                    get = function()
                        return frame:GetSettingValue(id)
                    end,
                    set = function(value)
                        if not position:CanEdit(frame) then
                            return false
                        end
                        manager:OnSystemSettingChange(frame, id, value)
                        local current = manager:GetActiveLayoutSystemInfo(frame.system, frame.systemIndex)
                        frame:SetHasActiveChanges(not equal(current, frame.savedSystemInfo))
                        manager:CheckForSystemActiveChanges()
                        return true
                    end,
                }
            end
        end
    end
    return sources
end

function module:Render()
    if not window then
        return
    end
    for index = 1, LIMIT do
        local label = list.labels[index]
        local entry = history[#history - index + 1]
        label:SetText(entry and entry.text or "")
        label:SetShown(entry ~= nil)
    end
    list:SetHeight(math.max(1, #history * 24))
    scroll:SetVerticalScroll(0)
    undo:SetEnabled(#history > 0 and not InCombatLockdown())
    status:SetText(#history == 0 and L["No changes yet"] or "")
end

-- Sample after mouse release: a drag or slider gesture is one transaction, including
-- mirrored settings and dependent frames. No intermediate drag positions enter history.
function module:Sample(reset)
    if restoring or not active or InCombatLockdown() or (not reset and IsMouseButtonDown("LeftButton")) then
        return
    end
    local nextBaseline, changes = {}, {}
    for _, source in ipairs(self:GetSources()) do
        local frame, key = source.frame, source.key
        local value = copy(source.get())
        nextBaseline[frame] = nextBaseline[frame] or {}
        nextBaseline[frame][key] = { value = value }
        local previous = baseline[frame] and baseline[frame][key]
        if not reset and previous and not equal(value, previous.value) then
            changes[#changes + 1] = { source = source, value = previous.value }
        end
    end
    baseline = nextBaseline
    if #changes > 0 then
        local source = changes[1].source
        for _, change in ipairs(changes) do
            if change.source.key ~= "position" and change.source.key ~= "native:position" then
                source = change.source
                break
            end
        end
        local frame = source.frame
        local name = source.frameName
            or frame.GetSystemName and frame:GetSystemName()
            or frame.editModeName
            or frame:GetName()
            or L["Unknown"]
        history[#history + 1] = { changes = changes, text = string.format(L["%s: %s"], name, source.name) }
        if #history > LIMIT then
            table.remove(history, 1)
        end
        self:Render()
    end
end

function module:Undo()
    if not active or restoring or InCombatLockdown() or IsMouseButtonDown("LeftButton") then
        return
    end
    self:Sample()
    local entry = history[#history]
    if not entry then
        return
    end
    for _, change in ipairs(entry.changes) do
        if disabled(change.source) then
            status:SetText(L["This change cannot be undone right now."])
            return
        end
    end
    local rollback = {}
    for _, change in ipairs(entry.changes) do
        rollback[#rollback + 1] = { source = change.source, value = copy(change.source.get()) }
    end
    restoring = true
    local ok, result = pcall(function()
        for index = #entry.changes, 1, -1 do
            local change = entry.changes[index]
            if change.source.set(copy(change.value)) == false then
                return false
            end
        end
        for _, change in ipairs(entry.changes) do
            if not equal(change.source.get(), change.value) then
                return false
            end
        end
        return true
    end)
    if not ok or not result then
        -- A later setter may refuse after an earlier setter succeeded. Put the
        -- transaction back before retaining it for another attempt.
        for _, change in ipairs(rollback) do
            pcall(change.source.set, copy(change.value))
        end
    end
    restoring = false
    self:Sample(true)
    if ok and result then
        table.remove(history)
        self:Render()
        app.core:RefreshEditModeOptions()
    else
        status:SetText(L["This change cannot be undone right now."])
    end
end

function module:CreateWindow()
    if window then
        return
    end
    window = CreateFrame("Frame", "SeamlessUIEditModeHistory", UIParent)
    window:Hide()
    window:SetFrameStrata("DIALOG")
    window:SetSize(260, 265)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    local border = CreateFrame("Frame", nil, window, "DialogBorderTranslucentTemplate")
    border:SetAllPoints()
    border:SetFrameLevel(window:GetFrameLevel())
    local title = window:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOP", 0, -16)
    title:SetText(L["Edit Mode history"])
    scroll = CreateFrame("ScrollFrame", nil, window, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 15, -40)
    scroll:SetSize(220, 144)
    list = CreateFrame("Frame", nil, scroll)
    list:SetSize(220, 1)
    list.labels = {}
    scroll:SetScrollChild(list)
    for index = 1, LIMIT do
        local label = list:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 0, -(index - 1) * 24)
        label:SetSize(220, 24)
        label:SetJustifyH("LEFT")
        list.labels[index] = label
    end
    status = window:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    status:SetPoint("BOTTOM", 0, 44)
    status:SetWidth(230)
    undo = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    undo:SetPoint("BOTTOM", 0, 14)
    undo:SetSize(220, 24)
    undo:SetText(L["Undo last change"])
    undo:SetScript("OnClick", function()
        self:Undo()
    end)
    window:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            elapsed = 0
            self:Sample()
        end
    end)
end

function module:Reset()
    history, baseline = {}, {}
    active = self:IsEnabled() and lib:IsInEditMode() and not InCombatLockdown()
    if active and EditModeManagerFrame then
        self:CreateWindow()
        window:ClearAllPoints()
        window:SetPoint("TOPRIGHT", EditModeManagerFrame, "TOPLEFT", -8, 0)
        self:Sample(true)
        window:Show()
    elseif window then
        window:Hide()
    end
    self:Render()
end
function module:OnEnable()
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "Reset")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Reset")
    self:Reset()
end
function module:OnDisable()
    self:UnregisterAllEvents()
    self:Reset()
end
function module:OnProfileRefresh()
    if not IsLoggedIn() then
        self:SetEnabledState(app.db.profile.editModeHistory)
    elseif app.db.profile.editModeHistory then
        self:Enable()
        self:Reset()
    else
        self:Disable()
    end
end
for _, event in ipairs({ "enter", "exit", "layout" }) do
    lib:RegisterCallback(event, function()
        active = false
        if window then
            window:Hide()
        end
        C_Timer.After(0, function()
            module:Reset()
        end)
    end)
end
