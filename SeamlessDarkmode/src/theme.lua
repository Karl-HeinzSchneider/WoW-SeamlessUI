---@type string, SeamlessDarkmode
local _, app = ...

-- Keep the last color requested by the UI, including changes while darkmode is active.
local tracked = setmetatable({}, { __mode = "k" })
local backdrops = setmetatable({}, { __mode = "k" })
local auraBorders = setmetatable({}, { __mode = "k" })
local writing = false

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

local function paint(texture, state)
    if not accessible(texture) then
        return
    end
    writing = true
    if active(state.category) then
        local color = app.db.profile.color
        texture:SetVertexColor(color.r, color.g, color.b, state.original[4])
    else
        texture:SetVertexColor(unpack(state.original))
    end
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
    if not state then
        state = { category = category, original = { texture:GetVertexColor() } }
        tracked[texture] = state
        hooksecurefunc(texture, "SetVertexColor", function(region, r, g, b, a)
            if writing or not accessible(region) then
                return
            end
            state.original = { r, g, b, a or 1 }
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
    writing = true
    if active(state.category) then
        local color = app.db.profile.color
        frame:SetBackdropBorderColor(color.r, color.g, color.b, state.original[4])
    else
        frame:SetBackdropBorderColor(unpack(state.original))
    end
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
                    state.original = { r, g, b, a or 1 }
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
            border:SetShown(active(category) and true or false)
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

function app.addon:Refresh()
    if not app.running or not app.db then
        return
    end
    -- Avoid creating or traversing protected UI while combat updates it.
    if InCombatLockdown() then
        return
    end
    local seen = {}
    for _, category in ipairs(app.categories) do
        for _, name in ipairs(category.roots) do
            scan(_G[name], category.key, seen, 0)
        end
        if category.key == "bags" then
            for i = 1, 13 do
                scan(_G["ContainerFrame" .. i], category.key, seen, 0)
            end
        elseif category.key == "chat" then
            for i = 1, NUM_CHAT_WINDOWS or 10 do
                local name = "ChatFrame" .. i
                for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
                    track(_G[name .. suffix], category.key)
                end
                scan(_G[name], category.key, seen, 0)
                scan(_G["ChatFrame" .. i .. "Tab"], category.key, seen, 0)
            end
        elseif category.key == "windows" then
            for name in pairs(UIPanelWindows or {}) do
                scan(_G[name], category.key, seen, 0)
            end
        end
    end
    for texture, state in pairs(tracked) do
        paint(texture, state)
    end
end
