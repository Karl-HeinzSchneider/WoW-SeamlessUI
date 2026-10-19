---@type string, SeamlessDarkmode
local _, app = ...

-- Keep the last color requested by the UI, including changes while darkmode is active.
local tracked = setmetatable({}, { __mode = "k" })
local backdrops = setmetatable({}, { __mode = "k" })
local auraBorders = setmetatable({}, { __mode = "k" })
local writing = false
local watchedRoots = setmetatable({}, { __mode = "k" })

local decorationKeys = {
    "FrameTexture",
    "AlternatePowerFrameTexture",
    "VehicleFrameTexture",
    "Texture",
    "Background",
    "Bg",
    "TitleBg",
    "TitleBackground",
    "SlotArt",
    "SlotBackground",
    "TopLeftCorner",
    "TopRightCorner",
    "BottomLeftCorner",
    "BottomRightCorner",
    "TopEdge",
    "BottomEdge",
    "LeftEdge",
    "RightEdge",
    "Center",
    "BorderTexture",
}
-- Forbidden/restricted objects can occur in ordinary frame fields and child lists.
-- Check access before even querying their type; restrictions can change after discovery.
local function accessible(object)
    local kind = type(object)
    if kind ~= "table" and kind ~= "userdata" then
        return false
    end
    if object.CanBeAccessedInContext and not object:CanBeAccessedInContext() then
        return false
    end
    return not object.IsForbidden or not object:IsForbidden()
end

local function active(category)
    return app.running and app.db.profile.enabled and app.db.profile.categories[category]
end

local function sameColor(r, g, b, a, currentR, currentG, currentB, currentA)
    -- The engine stores floats; avoid rewriting a tint due to round-trip precision.
    return math.abs(currentR - r) < 0.000001
        and math.abs(currentG - g) < 0.000001
        and math.abs(currentB - b) < 0.000001
        and math.abs(currentA - a) < 0.000001
end

local function paint(texture, state)
    if not accessible(texture) then
        return
    end
    local color = active(state.category) and app.db.profile.color or state.original
    local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
    local a = state.original[4]
    local currentR, currentG, currentB, currentA = texture:GetVertexColor()
    if sameColor(r, g, b, a, currentR, currentG, currentB, currentA) then
        return
    end
    writing = true
    texture:SetVertexColor(r, g, b, a)
    writing = false
end

local function track(texture, category)
    if not accessible(texture) or not texture.IsObjectType or not texture:IsObjectType("Texture") then
        return
    end
    if not active(category) and not tracked[texture] then
        return
    end
    local state = tracked[texture]
    if state then
        return
    end
    if not state then
        state = { category = category, original = { texture:GetVertexColor() } }
        tracked[texture] = state
        hooksecurefunc(texture, "SetVertexColor", function(region, r, g, b, a)
            if writing or not accessible(region) then
                return
            end
            state.original[1], state.original[2], state.original[3], state.original[4] = r, g, b, a or 1
            if active(state.category) then
                paint(region, state)
            end
        end)
    end
    paint(texture, state)
end

-- Match decorative art only. Status highlights, portraits, icons and bar fills stay readable.
local function decorative(texture)
    if not accessible(texture) then
        return false
    end
    local atlas = texture.GetAtlas and texture:GetAtlas()
    local path = texture:GetTexture()
    local name = (atlas or (type(path) == "string" and path) or ""):lower()
    if
        name:find("highlight")
        or name:find("glow")
        or name:find("flash")
        or name:find("mask")
        or name:find("status")
        or name:find("stealable")
        or name:find("debuff")
        or name:find("absorb")
        or name:find("heal")
        or name:find("threat")
        or name:find("dispel")
        or name:find("enchant")
    then
        return false
    end
    return name:find("border")
        or name:find("corner")
        or name:find("edge")
        or name:find("minimap%-frame")
        or name:find("gryphon")
        or name:find("ui%-hud%-unitframe.*portraiton$")
        or name:find("ui%-hud%-unitframe.*portraiton%-classresource$")
        or name:find("ui%-hud%-actionbar%-iconframe%-slot")
        or name == "ui-hud-actionbar-iconframe"
end

local function paintBackdrop(frame, state)
    if not accessible(frame) then
        return
    end
    local color = active(state.category) and app.db.profile.color or state.original
    local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
    local a = state.original[4]
    local currentR, currentG, currentB, currentA = frame:GetBackdropBorderColor()
    if sameColor(r, g, b, a, currentR, currentG, currentB, currentA) then
        return
    end
    writing = true
    frame:SetBackdropBorderColor(r, g, b, a)
    writing = false
end

local function scan(frame, category, seen, depth)
    if not accessible(frame) or seen[frame] or depth > 16 or not frame.GetRegions then
        return
    end
    seen[frame] = true
    if frame.GetBackdrop and frame:GetBackdrop() and frame.GetBackdropBorderColor then
        local state = backdrops[frame]
        if not state and active(category) then
            state = { category = category, original = { frame:GetBackdropBorderColor() } }
            backdrops[frame] = state
            hooksecurefunc(frame, "SetBackdropBorderColor", function(owner, r, g, b, a)
                if not writing and accessible(owner) then
                    state.original[1], state.original[2], state.original[3], state.original[4] = r, g, b, a or 1
                    if active(state.category) then
                        paintBackdrop(owner, state)
                    end
                end
            end)
        end
    end
    local isBar = frame.IsObjectType and frame:IsObjectType("StatusBar")
    for _, key in ipairs(decorationKeys) do
        local region = frame[key]
        -- Generic Texture/Background/Center fields can also contain portraits or bar fills.
        if accessible(region) and region.IsObjectType and region:IsObjectType("Texture") then
            if key ~= "Texture" and key ~= "Background" and key ~= "Center" or decorative(region) then
                track(region, category)
            end
        end
    end
    if frame.GetNormalTexture and (category == "actionbars" or category == "bags") then
        local normal = frame:GetNormalTexture()
        if normal and decorative(normal) then
            track(normal, category)
        end
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        if
            accessible(region)
            and region:IsObjectType("Texture")
            and (not isBar or region ~= frame:GetStatusBarTexture())
            and decorative(region)
        then
            -- Action-button Border is the quality/proc indicator, not its metal surround.
            if
                not (category == "actionbars" and region == frame.Border)
                and region ~= frame.IconBorder
                and region ~= frame.iconBorder
                and region ~= frame.DebuffBorder
                and region ~= frame.DispelBorder
            then
                track(region, category)
            end
        end
    end
    -- Aura buttons have no neutral surround in the client. Reuse existing action-button art.
    if category == "auras" and accessible(frame.Icon) and frame.DebuffBorder and frame.CreateTexture then
        local border = auraBorders[frame]
        if not border and active(category) then
            border = frame:CreateTexture(nil, "OVERLAY", nil, -1)
            border:SetAllPoints(frame.Icon)
            border:SetAtlas("UI-HUD-ActionBar-IconFrame-Border")
            auraBorders[frame] = border
        end
        if accessible(border) then
            local show = active(category) and true or false
            if border:IsShown() ~= show then
                border:SetShown(show)
            end
            track(border, category)
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        scan(child, category, seen, depth + 1)
    end
    if backdrops[frame] then
        paintBackdrop(frame, backdrops[frame])
    end
end

function app:Restore()
    for texture, state in pairs(tracked) do
        paint(texture, state)
    end
    for frame, state in pairs(backdrops) do
        paintBackdrop(frame, state)
    end
    for _, border in pairs(auraBorders) do
        if accessible(border) then
            border:Hide()
        end
    end
end

-- Discovery only runs for a category affected by a lifecycle event. Existing textures
-- are already hooked; scanning never repaints the global tracked set.
function app:DiscoverCategory(key)
    if not app.running or InCombatLockdown() then
        return
    end
    local seen = {}
    local function root(frame, category)
        if not accessible(frame) then
            return
        end
        if frame.HookScript and not watchedRoots[frame] then
            watchedRoots[frame] = true
            frame:HookScript("OnShow", function()
                app.addon:QueueDiscovery(category)
            end)
        end
        if active(category) then
            scan(frame, category, seen, 0)
        end
    end
    for _, category in ipairs(app.categories) do
        if category.key == key then
            for _, name in ipairs(category.roots) do
                root(_G[name], key)
            end
            if key == "bags" then
                for i = 1, 13 do
                    root(_G["ContainerFrame" .. i], key)
                end
            end
            return
        end
    end
end

-- Full refresh is reserved for enable, profile changes and explicit options edits.
function app.addon:Refresh()
    if not app.running or not app.db then
        return
    end
    if InCombatLockdown() then
        self.refreshPending = true
        return
    end
    self.refreshPending = nil
    for _, category in ipairs(app.categories) do
        app:DiscoverCategory(category.key)
    end
    for texture, state in pairs(tracked) do
        paint(texture, state)
    end
    for frame, state in pairs(backdrops) do
        paintBackdrop(frame, state)
    end
    for _, border in pairs(auraBorders) do
        if accessible(border) then
            local show = active("auras") and true or false
            if border:IsShown() ~= show then
                border:SetShown(show)
            end
        end
    end
end
