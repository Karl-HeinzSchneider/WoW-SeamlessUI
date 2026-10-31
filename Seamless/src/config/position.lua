---@type string, SeamlessCore
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---Build a reusable Position section from the same get/set contract as Edit Mode.
---@param spec SeamlessCore.EditModePosition
---@return table position
---@return table size
function app.addon:GetPositionOptions(spec)
    local args = {}
    local function disabled()
        return InCombatLockdown() or (spec.disabled and spec.disabled()) or false
    end
    local function option(key, name, order, kind)
        local row = {
            type = kind,
            name = name,
            order = order,
            disabled = disabled,
            get = function()
                return spec.get(key)
            end,
            set = function(_, value)
                if not disabled() then
                    spec.set(key, value)
                end
            end,
            default = spec.default and function()
                return spec.default(key)
            end,
            -- Edit Mode draws these from the same spec in its shared Position section.
            editModeHidden = true,
        }
        args[key] = row
        return row
    end
    local points = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
    local labels = {
        L["Top left"],
        L["Top"],
        L["Top right"],
        L["Left"],
        L["Center"],
        L["Right"],
        L["Bottom left"],
        L["Bottom"],
        L["Bottom right"],
    }
    local values = {}
    for i, point in ipairs(points) do
        values[point] = labels[i]
    end
    for i, key in ipairs({ "point", "relativePoint" }) do
        local row = option(key, i == 1 and L["Anchor"] or L["AnchorParent"], i, "select")
        row.values, row.sorting = values, points
    end
    local frame = option("relativeTo", L["AnchorFrame"], 3, "select")
    local function choices()
        return type(spec.anchorFrames) == "function" and spec.anchorFrames() or spec.anchorFrames or {}
    end
    frame.values = function()
        local result = {}
        for _, entry in ipairs(choices()) do
            result[entry.value] = entry.text
        end
        return result
    end
    frame.sorting = function()
        local result = {}
        for _, entry in ipairs(choices()) do
            result[#result + 1] = entry.value
        end
        return result
    end
    for i, key in ipairs({ "x", "y" }) do
        local row = option(key, i == 1 and L["X"] or L["Y"], i + 3, "range")
        -- Page declarations load before AceDB. Resolve bounds only when a control reads them,
        -- so profile switches and offsets beyond the screen also get the correct range.
        local function extent()
            local screen = math.ceil(key == "x" and UIParent:GetWidth() or UIParent:GetHeight())
            return math.max(screen, math.ceil(math.abs(spec.get(key) or 0)))
        end
        row.min = function()
            return -extent()
        end
        row.max = extent
        row.step = 1
    end
    -- Scale is a disabled placeholder with nothing behind it. A frame that supports a scale
    -- replaces this row with its own in the Size group.
    local scaleRow = {
        type = "range",
        name = L["Scale"],
        order = 0,
        min = 0.5,
        max = 2,
        step = 0.01,
        get = function()
            return 1
        end,
        set = function() end,
        disabled = function()
            return true
        end,
        editModeHidden = true,
    }
    if spec.reset then
        args.reset = {
            type = "execute",
            name = L["Reset to default position"],
            order = 7,
            editModeHidden = true,
            disabled = function()
                return disabled() or (spec.isDefault and spec.isDefault()) or false
            end,
            func = function()
                if not args.reset.disabled() then
                    spec.reset()
                end
            end,
        }
    end
    -- Edit Mode shows both groups as its shared Position and Size sections (editmodepages.lua).
    return { type = "group", inline = true, name = L["Position"], order = 10, args = args, editModePosition = spec }, {
        type = "group",
        inline = true,
        name = L["Size"],
        order = 11,
        args = { scale = scaleRow },
        editModeSize = true,
    }
end

---Native Position and Size groups use the active layout and its storage tooltip.
---@param getFrame fun(): table?
---@return table position
---@return table size
function app.addon:GetNativePositionOptions(getFrame)
    local service = self:GetFramePositionService()
    local keys = { x = "offsetX", y = "offsetY" }
    local anchorFrames = {}
    local function warn(ok, err)
        if not ok and err then
            app.logger:warn("%s", err)
        end
    end
    local group, size = self:GetPositionOptions({
        default = function(key)
            local values = service:GetDefault(getFrame())
            return values and values[keys[key] or key]
        end,
        isDefault = function()
            return service:IsDefault(getFrame())
        end,
        reset = function()
            warn(service:ResetToDefault(getFrame()))
        end,
        disabled = function()
            return not service:CanEdit(getFrame())
        end,
        get = function(key)
            local values = service:Read(getFrame())
            return values and values[keys[key] or key] or (keys[key] and 0 or nil)
        end,
        set = function(key, value)
            local frame = getFrame()
            local values = service:Read(frame)
            if not values then
                return
            end
            values[keys[key] or key] = value
            warn(service:Apply(frame, values))
        end,
        anchorFrames = function()
            -- Disabled dropdowns still generate their menus; do not inspect protected
            -- anchor chains during combat just to populate those menu labels.
            if not InCombatLockdown() then
                anchorFrames = service:GetAnchorFrames(getFrame())
            end
            return anchorFrames
        end,
    })
    group.layoutStored = true
    size.layoutStored = true
    return group, size
end
