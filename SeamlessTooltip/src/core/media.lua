---@type string, SeamlessTooltip
local _, app = ...

local LSM = LibStub("LibSharedMedia-3.0")

-- LibSharedMedia for the features' texture options: `app.media.LSM` for the library itself (its
-- MediaType constants, callbacks), plus the two things every texture option needs.
---@class SeamlessTooltip.Media
local media = {
    LSM = LSM,
}
app.media = media

-- A select's values for one media type: every registered name, shown as itself. Read when the
-- options draw, so textures registered by addons that load later are listed.
---@param mediaType string
---@return fun(): table<string, string>
function media.Values(mediaType)
    return function()
        local values = {}
        for _, name in ipairs(LSM:List(mediaType)) do
            values[name] = name
        end
        return values
    end
end

-- The file for a media name (LibSharedMedia's default when it isn't registered); nil for "None",
-- which LibSharedMedia stores as an empty path.
---@param mediaType string
---@param key string
---@return string?
function media.Fetch(mediaType, key)
    local path = LSM:Fetch(mediaType, key)
    return path ~= "" and path or nil
end
