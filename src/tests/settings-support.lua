-- Read only the literal defaults from page declarations for behavior harnesses that do not
-- load UI modules. config-options.lua separately exercises the complete declarations.
local support = {}
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
return support
