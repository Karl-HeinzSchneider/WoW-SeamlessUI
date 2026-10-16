---@type string, SeamlessUnitframes
local _, app = ...

---@class SeamlessUnitframes.LegacyLayout : AceModule, AceEvent-3.0
local module = {}
local layout = app.addon:NewModule("LegacyLayout", module, "AceEvent-3.0")
app.legacyLayout = layout

-- All bookkeeping is private. Never replace a Blizzard function, assign a mixin
-- member, or write layout/state fields onto a protected frame.
local regions, textures, frames = {}, {}, {}
local writing, scheduled, initialized, enabled, applied = false, false, false, false, false
local warnings = {}
local regionMethods = {
    "GetWidth",
    "GetHeight",
    "GetNumPoints",
    "GetPoint",
    "SetWidth",
    "SetHeight",
    "SetSize",
    "SetPoint",
    "SetAllPoints",
    "ClearAllPoints",
}

local function Readable(value)
    return not canaccessvalue or canaccessvalue(value)
end

function module:Warn(context, reason)
    local key = context .. ": " .. reason
    if not warnings[key] then
        warnings[key] = true
        app.logger:warn("Legacy unit frames: %s; skipping this operation", key)
    end
end

function module:CheckRegion(region, context, methods)
    if not Readable(region) then
        self:Warn(context, "inaccessible region")
        return false
    end
    if region == nil or (type(region) ~= "table" and type(region) ~= "userdata") then
        self:Warn(context, "missing or invalid region")
        return false
    end
    if type(region.IsForbidden) == "function" and region:IsForbidden() then
        self:Warn(context, "forbidden region")
        return false
    end
    for _, name in ipairs(methods or {}) do
        if type(region[name]) ~= "function" then
            self:Warn(context, "missing method " .. name)
            return false
        end
    end
    return true
end

-- Validate every nested path before applying a frame's geometry. A client change
-- or an incompletely initialized frame should produce a useful warning, not a nil call.
function module:CheckPaths(frame, context, paths)
    for _, path in ipairs(paths) do
        local value = frame
        for key in path:gmatch("[^.]+") do
            if not self:CheckRegion(value, context .. "." .. path) then
                return false
            end
            value = value[key]
        end
        if not self:CheckRegion(value, context .. "." .. path, { "GetParent" }) then
            return false
        end
    end
    return true
end

local function Points(region)
    local count = region:GetNumPoints()
    if not Readable(count) then
        layout:Warn("anchor snapshot", "inaccessible point count")
        return nil
    end
    if type(count) ~= "number" then
        layout:Warn("anchor snapshot", "invalid point count")
        return nil
    end
    local points = {}
    for i = 1, count do
        local point = { region:GetPoint(i) }
        for field = 1, 5 do
            if not Readable(point[field]) then
                layout:Warn("anchor snapshot", "inaccessible point component")
                return nil
            end
        end
        if type(point[1]) ~= "string" then
            layout:Warn("anchor snapshot", "invalid point name")
            return nil
        end
        points[i] = point
    end
    return points
end

local function Request()
    if writing or scheduled or not enabled then
        return
    end
    scheduled = true
    C_Timer.After(0, function()
        scheduled = false
        layout:Refresh()
    end)
end

local function Watch(region)
    if not layout:CheckRegion(region, "layout snapshot", regionMethods) then
        return nil
    end
    local state = regions[region]
    local points = Points(region)
    if state then
        if not points then
            state.points = nil
        end
        return state
    end
    state = { width = region:GetWidth(), height = region:GetHeight(), points = points }
    if region.GetJustifyH then
        state.justify = region:GetJustifyH()
    end
    if region.GetDrawLayer then
        state.layer = { region:GetDrawLayer() }
        hooksecurefunc(region, "SetDrawLayer", function()
            if not writing then
                state.layer = { region:GetDrawLayer() }
                Request()
            end
        end)
    end
    if type(region.GetFrameLevel) == "function" and type(region.SetFrameLevel) == "function" then
        state.frameLevel = region:GetFrameLevel()
        hooksecurefunc(region, "SetFrameLevel", function()
            if not writing then
                state.frameLevel = region:GetFrameLevel()
                Request()
            end
        end)
    end
    regions[region] = state
    for _, method in ipairs({ "SetWidth", "SetHeight", "SetSize" }) do
        hooksecurefunc(region, method, function()
            if not writing then
                if method ~= "SetHeight" then
                    state.width = region:GetWidth()
                end
                if method ~= "SetWidth" then
                    state.height = region:GetHeight()
                end
                Request()
            end
        end)
    end
    hooksecurefunc(region, "ClearAllPoints", function()
        if not writing then
            state.points = {}
            Request()
        end
    end)
    hooksecurefunc(region, "SetPoint", function(_, point)
        if writing then
            return
        end
        local points = Points(region)
        if not Readable(point) or not points then
            state.points = nil
            layout:Warn("anchor update", "inaccessible point data")
            return
        end
        if not state.points then
            -- Do not invent missing native anchors after a secret update. A
            -- native ClearAllPoints/SetAllPoints will establish a fresh baseline.
            Request()
            return
        end
        -- Record the native point, without accidentally recording other anchors
        -- left by our layout. ClearAllPoints starts a new native anchor list.
        for _, actual in ipairs(points) do
            if actual[1] == point then
                for i, previous in ipairs(state.points) do
                    if previous[1] == point then
                        table.remove(state.points, i)
                        break
                    end
                end
                state.points[#state.points + 1] = actual
                break
            end
        end
        Request()
    end)
    hooksecurefunc(region, "SetAllPoints", function()
        if not writing then
            state.points = Points(region)
            Request()
        end
    end)
    if region.SetJustifyH then
        hooksecurefunc(region, "SetJustifyH", function(_, justify)
            if not writing then
                state.justify = justify
                Request()
            end
        end)
    end
    return state
end

-- Called only outside combat; individual properties are restored only when we
-- changed them. Native updates continue to replace their saved values.
function module:Edit(region, changes)
    if not self:CheckRegion(region, "geometry region", regionMethods) then
        return
    end
    if changes.justify and not self:CheckRegion(region, "text alignment", { "GetJustifyH", "SetJustifyH" }) then
        return
    end
    if changes.layer and not self:CheckRegion(region, "texture layer", { "GetDrawLayer", "SetDrawLayer" }) then
        return
    end
    if changes.frameLevel and not self:CheckRegion(region, "frame stacking", { "GetFrameLevel", "SetFrameLevel" }) then
        return
    end
    local state = Watch(region)
    if not state then
        return
    end
    state.owned = state.owned or {}
    local wasWriting = writing
    writing = true
    if changes.width and Readable(state.width) then
        state.owned.width = true
        region:SetWidth(changes.width)
    end
    if changes.height and Readable(state.height) then
        state.owned.height = true
        region:SetHeight(changes.height)
    end
    if changes.point and state.points then
        state.owned.points = true
        region:ClearAllPoints()
        region:SetPoint(unpack(changes.point))
    end
    if changes.justify then
        state.owned.justify = true
        region:SetJustifyH(changes.justify)
    end
    if changes.layer then
        state.owned.layer = true
        region:SetDrawLayer(unpack(changes.layer))
    end
    if changes.frameLevel and Readable(state.frameLevel) then
        state.owned.frameLevel = true
        region:SetFrameLevel(changes.frameLevel)
    end
    writing = wasWriting
end

function module:GetAtlas(texture)
    local state = textures[texture]
    return state and state.overridden and (state.legacyAtlas or state.atlas) or texture:GetAtlas()
end

local function ReadableCoords(...)
    local coords = { ... }
    if #coords == 0 then
        return nil
    end
    for _, value in ipairs(coords) do
        if not Readable(value) then
            return nil
        end
    end
    return coords
end

local function WatchTexture(texture)
    if not layout:CheckRegion(texture, "texture discovery") then
        return
    end
    if textures[texture] or not texture.SetAtlas then
        return
    end
    if
        not layout:CheckRegion(
            texture,
            "atlas texture",
            { "GetAtlas", "GetWidth", "GetHeight", "SetTexture", "SetTexCoord" }
        )
    then
        return
    end
    local atlas = texture:GetAtlas()
    if not Readable(atlas) then
        atlas = nil
    end
    local state = { atlas = atlas }
    if type(texture.GetTexCoord) == "function" then
        state.nativeCoords = ReadableCoords(texture:GetTexCoord())
    end
    textures[texture] = state
    local info = atlas and C_Texture.GetAtlasInfo(atlas)
    -- Status-bar fill sizes may be secret even outside combat. Check access
    -- before equality; never infer atlas sizing from a secret dimension.
    local width, height = texture:GetWidth(), texture:GetHeight()
    state.useSize = info ~= nil
        and Readable(width)
        and Readable(height)
        and Readable(info.width)
        and Readable(info.height)
        and width == info.width
        and height == info.height
    hooksecurefunc(texture, "SetAtlas", function(_, name, useSize, _, resetTexCoords)
        if not writing then
            state.atlas, state.useSize, state.overridden, state.legacyAtlas = name, useSize, false, nil
            if resetTexCoords then
                state.nativeCoords = nil
            end
            -- SetAtlas's C implementation can resize without calling Lua SetSize.
            local regionState = regions[texture]
            if regionState and useSize then
                regionState.width, regionState.height = texture:GetWidth(), texture:GetHeight()
            end
            Request()
        end
    end)
    hooksecurefunc(texture, "SetTexture", function()
        if not writing then
            -- A raw replacement belongs to the client or another addon.
            state.atlas, state.overridden, state.legacyAtlas, state.nativeCoords = nil, false, nil, nil
            Request()
        end
    end)
    hooksecurefunc(texture, "SetTexCoord", function(_, ...)
        if not writing then
            state.nativeCoords = ReadableCoords(...)
        end
    end)
end

local function Scan(frame)
    if not layout:CheckRegion(frame, "frame discovery", { "GetChildren", "GetRegions" }) then
        return false
    end
    if frames[frame] then
        for _, child in ipairs({ frame:GetChildren() }) do
            Scan(child)
        end
        return true
    end
    frames[frame] = true
    for _, region in ipairs({ frame:GetRegions() }) do
        WatchTexture(region)
    end
    if frame.GetStatusBarTexture then
        local texture = frame:GetStatusBarTexture()
        if texture then
            WatchTexture(texture)
            if textures[texture] then
                textures[texture].bar = frame
            end
        end
        if frame.SetStatusBarAtlas then
            hooksecurefunc(frame, "SetStatusBarAtlas", function(_, atlas)
                if not writing then
                    local current = frame:GetStatusBarTexture()
                    if current then
                        WatchTexture(current)
                        local state = textures[current]
                        if state then
                            state.bar = frame
                            state.atlas, state.overridden, state.legacyAtlas = atlas, false, nil
                        end
                    end
                    Request()
                end
            end)
        end
        hooksecurefunc(frame, "SetStatusBarTexture", function()
            if not writing then
                local current = frame:GetStatusBarTexture()
                if current then
                    WatchTexture(current)
                    local state = textures[current]
                    if state then
                        state.bar = frame
                        state.atlas, state.overridden, state.legacyAtlas = current:GetAtlas(), false, nil
                        state.useSize = false
                    end
                end
                Request()
            end
        end)
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        Scan(child)
    end
    return true
end

local function Roots()
    local roots = app.unitFrames:All()
    for i = 1, MAX_BOSS_FRAMES or 5 do
        local boss = _G["Boss" .. i .. "TargetFrame"]
        if boss then
            roots[#roots + 1] = boss
        end
    end
    return roots
end

local function SetArtwork(texture, state, data, atlas)
    local bar = state.bar
    if bar then
        if not layout:CheckRegion(bar, "status-bar artwork", { "GetStatusBarTexture", "SetStatusBarTexture" }) then
            return false
        end
        if bar:GetStatusBarTexture() ~= texture then
            layout:Warn("status-bar artwork", "fill texture was replaced")
            return false
        end
        if data and not data[8] then
            layout:Warn("status-bar artwork", "no standalone fill for " .. atlas)
            return false
        end
    end
    local wasWriting = writing
    writing = true
    local success
    if bar then
        -- Let the status bar own all fill UVs. Raw sheet coordinates on its
        -- Texture are overwritten by native redraws, including secret values.
        success = bar:SetStatusBarTexture(data and data[8] or atlas)
    elseif data then
        texture:SetTexture(data[1])
        texture:SetTexCoord(data[4], data[5], data[6], data[7])
    else
        texture:SetAtlas(atlas, false, nil, true)
    end
    writing = wasWriting
    if success == false then
        layout:Warn("status-bar artwork", "client rejected fill " .. atlas)
        return false
    end
    return true
end

-- Health colors must change the logical atlas without putting sheet UVs back
-- onto a bar that is currently rendering a standalone legacy fill.
function module:SetHealthAtlas(texture, atlas)
    local state = textures[texture]
    if state and state.overridden and state.bar and app.db.profile.layout == "legacy" then
        if InCombatLockdown() then
            Request()
            return false
        end
        local data = app.legacyAtlases[atlas:lower()]
        if not SetArtwork(texture, state, data, atlas) then
            return false
        end
        local nativeBase = state.atlas:gsub("%-[Ss][Tt][Aa][Tt][Uu][Ss]$", "")
        state.atlas = atlas:lower():sub(-7) == "-status" and nativeBase .. "-Status" or nativeBase
        state.legacyAtlas = atlas
        return true
    end
    texture:SetAtlas(atlas, false, nil, true)
    return true
end

local function ApplyTextures()
    for texture, state in pairs(textures) do
        local data = state.atlas and app.legacyAtlases[state.atlas:lower()]
        if data and Watch(texture) then
            state.legacyAtlas = nil
            state.overridden = SetArtwork(texture, state, data, state.atlas)
            if state.overridden and state.useSize and not state.bar then
                layout:Edit(texture, { width = data[2], height = data[3] })
            end
        end
    end
end

-- The new client also changed which atlas some states select (not just the
-- atlas contents). Keep that choice separate from the client's restore value.
function module:Art(texture, atlas, useSize, preserveStatus)
    if not texture then
        return
    end
    WatchTexture(texture)
    local state = textures[texture]
    if not state then
        self:Warn("art override", "texture could not be observed")
        return
    end
    if not state.atlas then
        -- Respect a raw texture replacement owned by another addon.
        return
    end
    if preserveStatus and state.atlas and state.atlas:lower():sub(-7) == "-status" then
        local white = atlas .. "-Status"
        if app.legacyAtlases[white:lower()] or C_Texture.GetAtlasInfo(white) then
            atlas = white
        end
    end
    local data = app.legacyAtlases[atlas:lower()]
    if not Watch(texture) then
        return
    end
    state.overridden = SetArtwork(texture, state, data, atlas)
    if not state.overridden then
        return
    end
    state.legacyAtlas = atlas
    if useSize and not state.bar then
        local info = not data and C_Texture.GetAtlasInfo(atlas)
        if data or info then
            self:Edit(texture, { width = data and data[2] or info.width, height = data and data[3] or info.height })
        end
    end
end

local function Restore()
    local wasWriting = writing
    writing = true
    local restoreTextures = {}
    for texture, state in pairs(textures) do
        if state.overridden and layout:CheckRegion(texture, "atlas restoration", { "SetAtlas" }) then
            restoreTextures[#restoreTextures + 1] = { texture, state }
            state.overridden = false
            state.legacyAtlas = nil
        end
    end
    -- Retire every logical legacy override before invoking client setters, whose
    -- secure post-hooks can synchronously ask the color module for another atlas.
    for _, entry in ipairs(restoreTextures) do
        local texture, state = entry[1], entry[2]
        if state.bar and layout:CheckRegion(state.bar, "status-bar restoration", { "SetStatusBarTexture" }) then
            state.bar:SetStatusBarTexture(state.atlas)
        else
            texture:SetAtlas(state.atlas, state.useSize, nil, true)
            if state.nativeCoords then
                texture:SetTexCoord(unpack(state.nativeCoords))
            end
        end
    end
    for region, state in pairs(regions) do
        local owned = state.owned
        if owned and layout:CheckRegion(region, "geometry restoration", regionMethods) then
            if owned.width and Readable(state.width) then
                region:SetWidth(state.width)
            end
            if owned.height and Readable(state.height) then
                region:SetHeight(state.height)
            end
            if owned.points and state.points then
                region:ClearAllPoints()
                for _, point in ipairs(state.points) do
                    region:SetPoint(unpack(point))
                end
            end
            if owned.justify then
                region:SetJustifyH(state.justify)
            end
            if owned.layer then
                region:SetDrawLayer(unpack(state.layer))
            end
            if owned.frameLevel and Readable(state.frameLevel) then
                region:SetFrameLevel(state.frameLevel)
            end
            state.owned = nil
        end
    end
    writing = wasWriting
    if type(layout.HideLegacyBackgrounds) == "function" then
        layout:HideLegacyBackgrounds()
    else
        layout:Warn("restoration", "geometry module is missing HideLegacyBackgrounds")
    end
    applied = false
end

local function Initialize()
    if initialized then
        return
    end
    initialized = true
    for _, name in ipairs({
        "UnitFrame_Initialize",
        "PlayerFrame_ToPlayerArt",
        "PlayerFrame_ToVehicleArt",
        "PlayerFrame_UpdatePlayerNameTextAnchor",
        "PlayerFrame_UpdateHealthBarVisuals",
        "PlayerFrame_UpdateManaBarVisuals",
        "PlayerFrame_UpdateFlashTextureVisuals",
        "PlayerFrame_UpdateStatusTextureVisuals",
        "PlayerFrame_UpdatePvPStatus",
    }) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, Request)
        end
    end
end

function module:Refresh()
    if not enabled or not app.db then
        return
    end
    local legacy = app.db.profile.layout == "legacy"
    -- Includes profile changes, disable/restore, visibility, vehicle and
    -- classification updates. Never resize/reanchor protected children in combat.
    if InCombatLockdown() then
        return
    end
    if not legacy then
        if applied then
            Restore()
            app.healthColor:Refresh()
        end
        return
    end
    if type(self.ApplyGeometry) ~= "function" then
        self:Warn("refresh", "geometry module is missing ApplyGeometry")
        return
    end
    Initialize()
    local roots = Roots()
    local readyRoots = {}
    for _, frame in ipairs(roots) do
        if Scan(frame) and Watch(frame) then
            readyRoots[#readyRoots + 1] = frame
        end
        if regions[frame] and not regions[frame].hookedRoot then
            -- Hook instance methods, not shared mixin tables. Late-created party
            -- and ToT frames are discovered by UnitFrame_Initialize / group events.
            regions[frame].hookedRoot = true
            for _, name in ipairs({ "CheckClassification", "UpdateArt", "UpdateNameTextAnchors", "Show", "SetShown" }) do
                if type(frame[name]) == "function" then
                    hooksecurefunc(frame, name, Request)
                end
            end
        end
    end
    applied = true
    -- Apply art before explicit geometry: some masks have deliberate size overrides.
    ApplyTextures()
    self:ApplyGeometry(readyRoots)
    app.healthColor:Refresh()
end

function module:OnEnable()
    enabled = true
    for _, event in ipairs({
        "PLAYER_REGEN_ENABLED",
        "PLAYER_ENTERING_WORLD",
        "GROUP_ROSTER_UPDATE",
        "ADDON_LOADED",
        "UNIT_FACTION",
        "UNIT_FLAGS",
        "PLAYER_FLAGS_CHANGED",
    }) do
        self:RegisterEvent(event, Request)
    end
    self:Refresh()
end

function module:OnDisable()
    -- The addon is normally disabled through AddOns + reload. If another addon
    -- disables this module in combat, retain a restore event until it is safe.
    if InCombatLockdown() and applied then
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        waiter:SetScript("OnEvent", function(self)
            if enabled and app.db.profile.layout == "legacy" then
                layout:Refresh()
            else
                Restore()
            end
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
        end)
    elseif applied then
        Restore()
    end
    enabled = false
end

function module:OnProfileRefresh()
    Request()
end
