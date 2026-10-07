---@type string, SeamlessChat
local _, app = ...

---@class SeamlessChat.Input : AceModule
---@field ready boolean?
local module = {}
app.input = app.addon:NewModule("Input", module) --[[@as SeamlessChat.Input]]

local history = {}
local selected = {}

local function remember(editBox, text)
    if (issecretvalue and issecretvalue(text)) or type(text) ~= "string" or text == "" then
        return
    end
    local command = text:match("^(/%S+)")
    if command and IsSecureCmd(command) then
        return -- Recalling secure slash commands with SetText can block them in combat.
    end
    local lines = history[editBox]
    lines[#lines + 1] = text
    if #lines > editBox:GetHistoryLines() then
        table.remove(lines, 1)
    end
    selected[editBox] = #lines + 1
end

local function onArrowPressed(editBox, key)
    if IsAltKeyDown() or (AutoCompleteBox and AutoCompleteBox:IsShown()) then
        return
    end
    local lines = history[editBox]
    if #lines == 0 then
        return
    end
    local index = selected[editBox]
    if key == "UP" then
        index = math.max(1, index - 1)
    elseif key == "DOWN" then
        if index > #lines then
            editBox:SetText("")
            return
        end
        index = math.min(#lines, index + 1)
    else
        return
    end
    selected[editBox] = index
    local text = lines[index]
    editBox:SetText(text)
    editBox:SetCursorPosition(#text)
end

-- Enable plain arrow keys and the configured history size in default chat edit boxes.
-- CHAT_FRAMES includes the temporary whisper windows open at the time of refresh.
local function updateEditBoxes()
    local persist = app.db.profile.persistInputHistory
    local saved = app.db.char.inputHistory
    if persist then
        if type(saved) ~= "table" then
            saved = {}
            app.db.char.inputHistory = saved
        end
    else
        app.db.char.inputHistory = nil
    end

    for _, name in ipairs(CHAT_FRAMES) do
        local editBox = _G[name .. "EditBox"]
        if editBox then
            local chatFrame = _G[name]
            local key = chatFrame and not chatFrame.isTemporary and name or nil
            if not history[editBox] then
                local lines = {}
                local stored = persist and key and saved[key]
                if type(stored) == "table" then
                    for _, text in ipairs(stored) do
                        if type(text) == "string" and text ~= "" then
                            lines[#lines + 1] = text
                        end
                    end
                end
                history[editBox] = lines
                selected[editBox] = 1
                hooksecurefunc(editBox, "AddHistoryLine", remember)
                editBox:HookScript("OnArrowPressed", onArrowPressed)
            end
            if editBox:GetAltArrowKeyMode() then
                editBox:SetAltArrowKeyMode(false)
            end
            local limit = app.db.profile.inputHistoryLines
            if editBox:GetHistoryLines() ~= limit then
                editBox:SetHistoryLines(limit)
            end
            local lines = history[editBox]
            while #lines > limit do
                table.remove(lines, 1)
            end
            if persist and key then
                saved[key] = lines
            end
            selected[editBox] = #lines + 1
        end
    end
end

function module:OnInitialize()
    local function afterSettingsLoaded()
        -- SETTINGS_LOADED activates/deactivates Blizzard's chat edit boxes, including
        -- protected gamepad focus changes. Wait until every handler has returned before
        -- adding history hooks or changing the edit boxes' native input settings.
        C_Timer.After(0, function()
            self.ready = true
            if self:IsEnabled() then
                self:Refresh()
            end
        end)
    end
    if IsLoggedIn() then
        -- Also support loading the addon after the login events have already fired.
        afterSettingsLoaded()
    else
        EventUtil.RegisterOnceFrameEventAndCallback("SETTINGS_LOADED", afterSettingsLoaded)
    end
end

function module:OnEnable()
    self:Refresh()
end

function module:OnProfileRefresh()
    if self.ready then
        self:Refresh()
    end
end

function module:Refresh()
    if self.ready then
        updateEditBoxes()
    end
end
