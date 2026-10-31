-- Read only the literal defaults from page declarations for behavior harnesses that do not
-- load UI modules. config-options.lua separately exercises the complete declarations.
local support = {}
function support.customVisibility(_, id, get, set)
    assert(type(id) == "string" and type(get) == "function" and type(set) == "function")
    return function(value)
        if value ~= nil then
            set(value)
        end
        return get()
    end
end
-- Inert declarations for page-only harnesses; dialog tests exercise the real action bindings.
function support.buttonSection(_, buttons)
    for _, button in ipairs(buttons) do
        button.kind = button.kind or "seamless-button"
    end
    return { kind = "seamless-button-section", options = buttons }
end
function support.positionButton(_, action)
    return { name = action, click = function() end }
end
local function literal(source, first)
    local depth, index = 0, first
    while index <= #source do
        local char = source:sub(index, index)
        if char == '"' or char == "'" then
            local quote = char
            index = index + 1
            while source:sub(index, index) ~= quote do
                if source:sub(index, index) == "\\" then
                    index = index + 1
                end
                index = index + 1
                assert(index <= #source, "Unclosed defaults string")
            end
        elseif source:sub(index, index + 1) == "--" then
            index = source:find("\n", index, true) or #source
        elseif char == "{" then
            depth = depth + 1
        elseif char == "}" then
            depth = depth - 1
            if depth == 0 then
                return source:sub(first, index)
            end
        end
        index = index + 1
    end
    error("Unclosed page defaults")
end
local function merge(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = target[key] or {}
            merge(target[key], value)
        else
            target[key] = value
        end
    end
end
function support.defaults(addon, app)
    local toc = assert(io.open(addon .. "/" .. addon .. ".toc"))
    for line in toc:lines() do
        local file = line:gsub("\\", "/"):match("^(src/options/[^\r]+%.lua)")
        if file then
            local handle = assert(io.open(addon .. "/" .. file))
            local source = handle:read("*a")
            handle:close()
            for _, key in ipairs({ "skinDefaults", "positionDefaults" }) do
                local _, templateStart = source:find("app%." .. key .. "%s*=%s*{")
                if templateStart then
                    app[key] = assert((loadstring or load)("return " .. literal(source, templateStart)))()
                end
            end
            local _, start = source:find("defaults%s*=%s*{")
            if start then
                local defaults = assert((loadstring or load)("return " .. literal(source, start)))()
                merge(app.dbDefaults, defaults)
            end
        end
    end
    toc:close()
    if addon == "SeamlessDamageMeter" then
        app.windowDefaults = app.dbDefaults.profile.windowDefaults
    end
end
function support.pages(addon, app)
    local toc = assert(io.open(addon .. "/" .. addon .. ".toc"))
    app.optionPages = app.optionPages or {}
    for line in toc:lines() do
        local file = line:gsub("\\", "/"):match("^(src/options/[^\r]+%.lua)")
        if file then
            assert(loadfile(addon .. "/" .. file))(addon, app)
        end
    end
    toc:close()
end
-- Core's real settings model and Edit Mode page builder (editmodepages.lua) for a feature
-- harness's mocked core: the feature's pages register lazily from app.optionPages, as the options
-- module does, so Edit Mode rows are exactly what the page declares.
function support.editModePages(core, addonName, pages)
    local coreApp = {
        addon = core,
        config = {
            optionInfo = {},
            NotifyChange = function(_, name)
                if core.RefreshOptions then
                    core:RefreshOptions(name)
                end
            end,
        },
        LibEditMode = {
            SettingType = {
                Header = "seamless-header",
                Option = "seamless-option",
                Position = "seamless-position",
                ButtonSection = "seamless-button-section",
            },
        },
    }
    if not core.GetEditModePositionSetting then
        function core:GetEditModePositionSetting(spec, options)
            return { kind = "seamless-position", name = "Position", position = spec, options = options }
        end
    end
    -- A harness that already prepares its pages keeps its schema instance.
    if not core.PrepareSettingsOptions then
        assert(loadfile("Seamless/src/config/schema.lua"))("Seamless", coreApp)
    end
    assert(loadfile("Seamless/src/config/model.lua"))("Seamless", coreApp)
    assert(loadfile("Seamless/src/core/editmodepages.lua"))("Seamless", coreApp)
    coreApp.options = {
        panels = setmetatable({}, {
            __index = function(panels, name)
                if name ~= addonName then
                    return nil
                end
                local args = {}
                for key, page in pairs(pages.optionPages) do
                    core:PrepareSettingsOptions(page.config)
                    args[key] = page.config
                end
                coreApp.config.optionInfo[name] = function(path)
                    local page = pages.optionPages[path[1]]
                    if page and page.tooltip then
                        return page.tooltip(path)
                    end
                    return page and page.defaults and core:GetOptionDefault(page.defaults.profile, path)
                end
                local panel = { options = { type = "group", args = args } }
                rawset(panels, name, panel)
                return panel
            end,
        }),
    }
    return coreApp
end

---The rows of LibEditMode settings built from a page, in order, keyed by their option's last key.
function support.pageRows(settings)
    local rows, list = {}, {}
    local function add(row)
        list[#list + 1] = row
        rows[row.setting.path[#row.setting.path]] = row
    end
    for _, setting in ipairs(settings) do
        if setting.kind == "seamless-option" then
            add(setting.row)
        elseif setting.kind == "seamless-position" then
            for _, extra in ipairs(setting.options or {}) do
                add(extra.row)
            end
        end
    end
    return rows, list
end
return support
