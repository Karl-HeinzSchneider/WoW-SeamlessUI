---@type string, SeamlessCore
local _, app = ...

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, item in pairs(value) do
        result[key] = Copy(item)
    end
    return result
end

---Register a feature's settings under the suite database during its OnInitialize.
---Legacy SavedVariables remain declared for one-way import; an existing namespace always wins.
---@param name string
---@param defaults AceDB.Schema
---@param owner table
---@param refresh string
---@param legacyName? string
---@return AceDBObject-3.0
function app.addon:RegisterAddonDatabase(name, defaults, owner, refresh, legacyName)
    local parent = self.db
    local namespaces = parent.sv.namespaces or {}
    parent.sv.namespaces = namespaces
    if not namespaces[name] then
        local legacy = legacyName and _G[legacyName]
        local saved = type(legacy) == "table" and Copy(legacy) or {}
        local profiles = saved.profiles or {}
        saved.profiles = profiles
        local selected = saved.profileKeys and saved.profileKeys[parent.keys.char] or "Default"
        local current = parent:GetCurrentProfile()
        -- Keep the character's previous settings even when its feature profile had another name.
        if selected ~= current then
            if profiles[current] then
                -- Preserve a same-named inactive legacy profile before seeding the active one.
                local alias = name .. "/" .. current
                while profiles[alias] do
                    alias = alias .. "/"
                end
                profiles[alias] = profiles[current]
            end
            profiles[current] = Copy(profiles[selected] or {})
        end
        saved.profileKeys = nil
        namespaces[name] = saved
        -- Make imported named profiles selectable through the shared Profiles tab.
        for profile in pairs(profiles) do
            parent.profiles[profile] = parent.profiles[profile] or {}
        end
    end
    local db = parent:RegisterNamespace(name, defaults)
    -- Listen on the parent: all namespaces have finished switching/copying/resetting here.
    for _, event in ipairs({ "OnProfileChanged", "OnProfileCopied", "OnProfileReset" }) do
        parent.RegisterCallback(owner, event, function()
            owner[refresh](owner)
        end)
    end
    return db
end
