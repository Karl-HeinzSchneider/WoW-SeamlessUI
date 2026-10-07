---@type string, SeamlessCore
local _, app = ...

local Panel = app.settings.Panel

-- The generic dialogs are provided by this client's Blizzard_StaticPopup_Game.
local function Confirm(text, callback)
    StaticPopup_Show("GENERIC_CONFIRMATION", nil, nil, { text = "%s", text_arg1 = text, callback = callback })
end

---@param db AceDBObject-3.0
function Panel:Profiles(db)
    local panel = self
    local copySource, deleteSource = "", ""

    local function names(excludeCurrent)
        local result = {}
        for _, name in ipairs(db:GetProfiles()) do
            if not excludeCurrent or name ~= db:GetCurrentProfile() then
                result[#result + 1] = name
            end
        end
        table.sort(result)
        return result
    end

    local function exists(name, excludeCurrent)
        for _, candidate in ipairs(names(excludeCurrent)) do
            if candidate == name then
                return true
            end
        end
        return false
    end

    local function choices(excludeCurrent)
        local result = {}
        if excludeCurrent then
            result[1] = { "", "Select a profile" }
        end
        for _, name in ipairs(names(excludeCurrent)) do
            result[#result + 1] = { name, name }
        end
        return result
    end

    -- No default on these selectors: native Defaults must not switch profiles or perform actions.
    self:Header("Profiles")
    self:Dropdown({
        id = "profiles.current",
        name = "Active profile",
        tooltip = "Profiles apply only to " .. self.title .. ".",
        get = function()
            return db:GetCurrentProfile()
        end,
        set = function(value)
            db:SetProfile(value)
        end,
        options = function()
            return choices(false)
        end,
    })
    self:Button("New profile", "Create", function()
        StaticPopup_Show("GENERIC_INPUT_BOX", nil, nil, {
            text = "%s",
            text_arg1 = "New profile for " .. panel.title,
            maxLetters = 64,
            callback = function(value)
                local name = value:match("^%s*(.-)%s*$")
                if name == "" then
                    return
                end
                if exists(name) then
                    app.logger:chat("Profile '%s' already exists. Select it from Active profile.", name)
                    return
                end
                db:SetProfile(name)
            end,
        })
    end, "Create and switch to a profile with default settings.")
    self:Dropdown({
        id = "profiles.copy",
        name = "Copy from profile",
        get = function()
            if not exists(copySource, true) then
                copySource = ""
            end
            return copySource
        end,
        set = function(value)
            copySource = value
        end,
        options = function()
            return choices(true)
        end,
    })
    local copyButton = self:Button("Copy profile settings", "Copy", function()
        local source, target = copySource, db:GetCurrentProfile()
        if not exists(source, true) then
            return
        end
        Confirm(("Replace %s profile '%s' with settings from '%s'?"):format(panel.title, target, source), function()
            -- A profile can change while the dialog is open; never overwrite a different one.
            if db:GetCurrentProfile() == target and exists(source, true) then
                db:CopyProfile(source)
            end
        end)
    end, "Replace the active profile's settings with another profile's settings.")
    copyButton:AddModifyPredicate(function()
        return exists(copySource, true)
    end)
    copyButton:AddEvaluateStateCVar(self.settings["profiles.copy"]:GetVariable())

    self:Dropdown({
        id = "profiles.delete",
        name = "Profile to delete",
        get = function()
            if not exists(deleteSource, true) then
                deleteSource = ""
            end
            return deleteSource
        end,
        set = function(value)
            deleteSource = value
        end,
        options = function()
            return choices(true)
        end,
    })
    local deleteButton = self:Button("Delete profile", "Delete", function()
        local source = deleteSource
        if not exists(source, true) then
            return
        end
        Confirm(("Delete %s profile '%s'?"):format(panel.title, source), function()
            if exists(source, true) then
                db:DeleteProfile(source)
            end
        end)
    end, "Delete an inactive profile. The active profile cannot be deleted.")
    deleteButton:AddModifyPredicate(function()
        return exists(deleteSource, true)
    end)
    deleteButton:AddEvaluateStateCVar(self.settings["profiles.delete"]:GetVariable())

    self:Button("Reset active profile", "Reset", function()
        local target = db:GetCurrentProfile()
        Confirm(("Reset %s profile '%s' to defaults?"):format(panel.title, target), function()
            if db:GetCurrentProfile() == target then
                db:ResetProfile()
            end
        end)
    end, "Reset all settings in this addon's active profile.")

    -- AceDB callbacks also cover profile changes made through slash commands or other code.
    for _, event in ipairs({
        "OnProfileChanged",
        "OnProfileCopied",
        "OnProfileReset",
        "OnProfileDeleted",
        "OnNewProfile",
    }) do
        db.RegisterCallback(panel, event, "Refresh")
    end
end
