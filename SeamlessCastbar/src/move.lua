---@type string, SeamlessCastbar
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Moves the target and focus cast bars with Edit Mode. The client places them under their unit
-- frames in each bar's AdjustPosition; a post-hook anchors the bar to an addon-owned frame that
-- LibEditMode moves instead. The bars are not protected, so this works in combat and taints
-- nothing: no client method is called or replaced, and the unit frames keep their own anchors.

local lib = app.core:GetEditModeLibrary()

-- Edit Mode names and the positions Reset Position returns to.
local specs = {
    target = { name = L["Target cast bar"], default = { point = "CENTER", x = 250, y = -150 } },
    focus = { name = L["Focus cast bar"], default = { point = "CENTER", x = -250, y = -150 } },
}

-- Frames the AnchorFrame dropdown offers.
local anchorFrames = {
    { text = L["UIParent"], value = "UIParent" },
    { text = L["Player frame"], value = "PlayerFrame" },
    { text = L["Target frame"], value = "TargetFrame" },
    { text = L["Focus frame"], value = "FocusFrame" },
}

---@type table<string, Frame>
local anchors = {}
-- Bars currently anchored to ours.
---@type table<StatusBar, boolean>
local attached = {}

local function settings(key)
    return app.db.profile[key].move
end

local function moving(key)
    return app.addon:IsEnabled() and settings(key).enabled == true
end

-- The active layout's stored position, or nil before the bar has one there.
local function storedPosition(key)
    local name = lib:GetActiveLayoutName()
    return name and settings(key).layouts[name]
end

local function currentPosition(key)
    local position = storedPosition(key) or specs[key].default
    return {
        point = position.point,
        relativePoint = position.relativePoint or position.point,
        relativeTo = position.relativeTo or "UIParent",
        x = position.x,
        y = position.y,
    }
end

local function relativeFrame(name)
    for _, entry in ipairs(anchorFrames) do
        if entry.value == name and type(_G[name]) == "table" then
            return _G[name]
        end
    end
    return UIParent
end

-- Where the client's AdjustPosition places the bar without Target of Target or aura rows, as a
-- start position. Read from the unit frame, never from the bar: once the client anchors the bar
-- to the aura rows, its geometry is secret.
local function capturePosition(key, bar)
    local name = lib:GetActiveLayoutName()
    local parent = bar:GetParent()
    local parentName = parent and parent:GetName()
    if not name or not parentName then
        return
    end
    settings(key).layouts[name] = {
        point = "TOPLEFT",
        relativeTo = parentName,
        relativePoint = "BOTTOMLEFT",
        x = parent.smallSize and 38 or 43,
        y = parent.smallSize and 3 or 5,
    }
end

---Put the bar back under its unit frame. Its own points cannot be read and saved: once the client
---anchors it to the aura rows, even their number is secret. So this is the client's spot without
---aura rows (with Target of Target, lower), until its next AdjustPosition puts it exactly.
---@param bar StatusBar
function app.RestoreMove(bar)
    if not attached[bar] then
        return
    end
    attached[bar] = nil
    local parent = bar:GetParent()
    local x, y = parent.smallSize and 38 or 43, parent.smallSize and 3 or 5
    if parent.haveToT then
        y = parent.smallSize and -48 or -46
    end
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", x, y)
end

-- The bar's size in UIParent's units for the anchor, or nil while it is secret.
local function barSize(bar)
    local width, height, scale = bar:GetWidth(), bar:GetHeight(), bar:GetEffectiveScale()
    if not (app.Known(width) and app.Known(height) and app.Known(scale)) then
        return
    end
    local ratio = scale / UIParent:GetEffectiveScale()
    return math.max(width * ratio, 20), math.max(height * ratio, 8)
end

---Anchor the bar to its Edit Mode frame while moving is on, or restore the client's points.
---@param bar StatusBar
---@param placed boolean? the client has just set the bar's points (AdjustPosition)
function app.UpdateMove(bar, placed)
    local key = app.BarKey(bar)
    local anchor = key and anchors[key]
    if not anchor then
        return
    end
    if placed then
        attached[bar] = nil
    end
    if not moving(key) then
        app.RestoreMove(bar)
        anchor:Hide()
        return
    end
    if not storedPosition(key) then
        capturePosition(key, bar)
    end
    attached[bar] = true
    local position = currentPosition(key)
    local width, height = barSize(bar)
    if width then
        anchor:SetSize(width, height)
    end
    anchor:ClearAllPoints()
    anchor:SetPoint(position.point, relativeFrame(position.relativeTo), position.relativePoint, position.x, position.y)
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", anchor, "CENTER")
    anchor:SetShown(lib:IsInEditMode())
end

local function refresh()
    app.addon:Refresh()
    app.core:RefreshOptions(appName)
end

local function createAnchor(key)
    local spec = specs[key]
    local anchor = CreateFrame("Frame", nil, UIParent)
    anchor:SetSize(150, 10)
    anchor:SetClampedToScreen(true)
    anchor:Hide()
    lib:AddFrame(anchor, function(_, layoutName, point, x, y)
        if moving(key) and layoutName then
            settings(key).layouts[layoutName] = { point = point, x = x, y = y }
            -- Reset Position does not refresh the dialog itself; keep the Position values current.
            lib:RefreshFrameSettings(anchor)
            app.addon:Refresh()
        end
    end, spec.default, spec.name)
    lib:AddFrameSettings(
        anchor,
        app.core:GetEditModePositionSettings({
            get = function(positionKey)
                return currentPosition(key)[positionKey]
            end,
            set = function(positionKey, value)
                local name = lib:GetActiveLayoutName()
                if not name or not moving(key) then
                    return
                end
                local current = currentPosition(key)
                current[positionKey] = value
                settings(key).layouts[name] = current
                app.addon:Refresh()
            end,
            anchorFrames = anchorFrames,
        })
    )
    anchors[key] = anchor
end

local registered = false

-- Called once from OnEnable, after the bars are known.
function app.RegisterMove()
    if registered then
        return
    end
    registered = true
    local options = {}
    for _, key in ipairs({ "target", "focus" }) do
        createAnchor(key)
        options[#options + 1] = {
            key = key,
            type = "toggle",
            name = specs[key].name,
            get = function()
                return settings(key).enabled
            end,
            set = function(value)
                settings(key).enabled = value
                EventRegistry:TriggerEvent("EditModeExternal.hideDialog")
                refresh()
            end,
        }
    end
    app.core:RegisterEditModeOptions(appName .. ".Move", {
        section = "frames",
        enabled = function()
            return app.addon:IsEnabled()
        end,
        options = options,
    })
    for _, event in ipairs({ "enter", "exit", "layout" }) do
        lib:RegisterCallback(event, function()
            app.addon:Refresh()
        end)
    end
    local function forEachLayouts(callback)
        for _, profile in pairs(app.db.profiles) do
            for key in pairs(specs) do
                local move = profile[key] and profile[key].move
                if move and move.layouts then
                    callback(move.layouts)
                end
            end
        end
    end
    lib:RegisterCallback("create", function(name, _, sourceName)
        forEachLayouts(function(layouts)
            local source = sourceName and layouts[sourceName]
            if source then
                layouts[name] = CopyTable(source)
            end
        end)
    end)
    lib:RegisterCallback("rename", function(oldName, newName)
        forEachLayouts(function(layouts)
            layouts[newName], layouts[oldName] = layouts[oldName], nil
        end)
    end)
    lib:RegisterCallback("delete", function(name)
        forEachLayouts(function(layouts)
            layouts[name] = nil
        end)
    end)
end
