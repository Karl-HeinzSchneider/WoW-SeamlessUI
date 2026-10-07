---@type string, SeamlessCore
local _, app = ...

local Panel = app.settings.Panel

StaticPopupDialogs["SEAMLESS_SETTINGS_DETAILS"] = {
    text = "%s",
    button1 = OKAY,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function AcceptInput(dialog, data)
    -- Do not apply text entered for a profile that has since been switched.
    if
        (data.spec.context and data.spec.context() ~= data.context)
        or (data.spec.enabled and not data.spec.enabled())
    then
        return false
    end
    local value = dialog:GetEditBox():GetText()
    local valid = true
    if data.spec.validate then
        valid = data.spec.validate(value)
    end
    if valid ~= true then
        app.logger:chat("%s", type(valid) == "string" and valid or "Invalid value.")
        return true -- keep the dialog open so the user can correct it
    end
    data.setting:SetValue(value)
    data.panel:Refresh()
    return false
end

StaticPopupDialogs["SEAMLESS_SETTINGS_INPUT"] = {
    text = "%s",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(dialog, data)
        local editBox = dialog:GetEditBox()
        editBox:SetMaxLetters(0)
        editBox:SetText(data.setting:GetValue())
        editBox:HighlightText()
        editBox:SetFocus()
    end,
    OnAccept = AcceptInput,
    EditBoxOnEnterPressed = function(editBox)
        local dialog = editBox:GetParent()
        if not AcceptInput(dialog, dialog.data) then
            dialog:Hide()
        end
    end,
    EditBoxOnEscapePressed = function(editBox)
        editBox:GetParent():Hide()
    end,
}

-- Register a real string setting so Defaults/profile refresh still use native Settings semantics.
-- The stock button opens a prefilled native dialog; empty channel labels are valid.
---@param spec SeamlessCore.SettingSpec
function Panel:Input(spec)
    local setting = self:RegisterSetting(spec, Settings.VarType.String)
    local initializer = self:Button(spec.name, "Edit", function()
        StaticPopup_Show("SEAMLESS_SETTINGS_INPUT", spec.name, nil, {
            setting = setting,
            spec = spec,
            panel = self,
            context = spec.context and spec.context(),
        })
    end, function()
        return (spec.tooltip or "") .. "\n\nCurrent value: " .. tostring(setting:GetValue())
    end)
    return self:Configure(initializer, spec)
end

-- Evaluate status and previews when viewed, after the owning module has initialized.
function Panel:Description(name, text)
    local function content()
        return type(text) == "function" and text() or text
    end
    return self:Button(name, "Details", function()
        StaticPopup_Show("SEAMLESS_SETTINGS_DETAILS", content())
    end, content)
end

function Panel:Action(spec, callback, confirmation)
    local function run()
        if spec.enabled and not spec.enabled() then
            return
        end
        callback()
        self:Refresh()
    end
    local initializer = self:Button(spec.name, spec.buttonText or "Run", function()
        if confirmation then
            local context = spec.context and spec.context()
            StaticPopup_Show("GENERIC_CONFIRMATION", nil, nil, {
                text = "%s",
                text_arg1 = confirmation,
                callback = function()
                    if not spec.context or spec.context() == context then
                        run()
                    end
                end,
            })
        else
            run()
        end
    end, spec.tooltip)
    return self:Configure(initializer, spec)
end
