---@type string, SeamlessCore
local appName, app = ...

local config = app.config
local registry = LibStub("AceConfigRegistry-3.0")
local dialog = LibStub("AceConfigDialog-3.0")
local gui = LibStub("AceGUI-3.0")
local registered = {}

-- Feed the existing options table at its original path. AceConfig retains
-- inherited accessors, validation, confirmations, profiles and dynamic groups.
local function registerPage(id, parent, name, key, group)
    local info = { key, appName = name, type = "group", option = group }
    app.addon:RegisterConfigCategory(id, {
        name = group.name,
        parent = parent,
        order = group.order,
        hidden = function()
            if type(group.hidden) == "function" then
                return group.hidden(info)
            end
            return group.hidden == true
        end,
        create = function(page)
            local widget = gui:Create("SimpleGroup")
            page.optionsWidget = widget
            widget.frame:SetParent(page)
            widget.frame:SetFrameStrata("HIGH")
            widget.frame:SetFrameLevel(page:GetFrameLevel() + 1)
            widget.frame:ClearAllPoints()
            widget.frame:SetPoint("TOPLEFT")
            widget:SetWidth(page:GetWidth())
            widget.frame:HookScript("OnSizeChanged", function(_, _, height)
                page:SetHeight(math.max(1, height))
            end)
        end,
        refresh = function(page)
            dialog:Open(name, page.optionsWidget, key)
        end,
    })
end

function config:RegisterOptions(name, spec, groups)
    registered[name] = true
    -- Tweaks is a legacy Blizzard child panel, but belongs to Core in our tree.
    if name == appName .. "Tweaks" then
        registerPage(appName .. ":tweaks", appName, name, "general", {
            name = spec.title,
            order = 100,
        })
        return
    end
    app.addon:RegisterConfigCategory(name, {
        name = spec.title,
        header = true,
        order = name == appName and 0 or 100,
    })
    for key, group in pairs(groups) do
        registerPage(name .. ":" .. key, name, name, key, group)
    end
end

-- Registry notifications include external refreshes and profile changes. Defer
-- rebuilding controls until the current widget callback has finished.
registry.RegisterCallback(config, "ConfigTableChange", function(_, name)
    if not registered[name] or config.refreshPending or not config.frame or not config.frame:IsShown() then
        return
    end
    config.refreshPending = true
    C_Timer.After(0, function()
        config.refreshPending = nil
        if config.frame and config.frame:IsShown() then
            config:Refresh()
        end
    end)
end)
