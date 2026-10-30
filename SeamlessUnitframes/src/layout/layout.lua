---@type string, SeamlessUnitframes
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessUnitframes.LegacyLayout : AceModule, AceEvent-3.0
local module = {}
local layout = app.addon:NewModule("LegacyLayout", module, "AceEvent-3.0")
app.legacyLayout = layout
local lib = app.core:GetEditModeLibrary()

-- Definitions own atlas names and geometry. Never snapshot live rendering state:
-- even out of combat GetAtlas/GetPoint/GetWidth can return secret values.
local warnings, bindings, hooked, artwork = {}, {}, {}, {}
local knownRoots = {}
local anchors = {}
local painted, watchedBars, watchedFills, watchedArt = {}, {}, {}, {}
local visualBars = {}
local lossColored = false
local enabled, applied, writing, initialized = false, false, false, false
local legacyMode = false
local roundedMode = false
local openingFrames, openingSeen = {}, {}

function module:Readable(value)
    return not canaccessvalue or canaccessvalue(value)
end

function module:Warn(context, reason)
    local message = context .. ": " .. reason
    if not warnings[message] then
        warnings[message] = true
        app.logger:warn(L["Beta unit frames: %s; skipping this operation"], message)
    end
end

function module:CheckRegion(region, context, methods)
    if not self:Readable(region) then
        self:Warn(context, "inaccessible region")
        return false
    end
    if region == nil or (type(region) ~= "table" and type(region) ~= "userdata") then
        self:Warn(context, "missing region")
        return false
    end
    local forbiddenMethod = region.IsForbidden
    if not self:Readable(forbiddenMethod) then
        self:Warn(context, "inaccessible forbidden check")
        return false
    end
    if type(forbiddenMethod) == "function" then
        local forbidden = region:IsForbidden()
        if not self:Readable(forbidden) or forbidden then
            self:Warn(context, "forbidden or inaccessible region")
            return false
        end
    end
    for _, name in ipairs(methods or {}) do
        local method = region[name]
        if not self:Readable(method) or type(method) ~= "function" then
            self:Warn(context, "missing or inaccessible method " .. name)
            return false
        end
    end
    return true
end

function module:CheckPaths(frame, context, paths)
    for _, path in ipairs(paths) do
        local value = frame
        for key in path:gmatch("[^.]+") do
            if not self:CheckRegion(value, context .. "." .. path) then
                return false
            end
            value = value[key]
        end
        if not self:CheckRegion(value, context .. "." .. path) then
            return false
        end
    end
    return true
end

-- Remember only our own fixed anchor writes. Native setters invalidate the
-- cache without reading their arguments or any possibly secret render state.
local function AnchorState(region)
    local state = anchors[region]
    if not state then
        state = { revision = 0 }
        anchors[region] = state
        for _, name in ipairs({ "SetPoint", "ClearAllPoints", "SetAllPoints", "SetParent" }) do
            if layout:Readable(region[name]) and type(region[name]) == "function" then
                hooksecurefunc(region, name, function()
                    state.point = nil
                    state.revision = state.revision + 1
                end)
            end
        end
    end
    return state
end

local function SameAnchor(left, right)
    if not left or #left ~= #right then
        return false
    end
    for index = 1, #right do
        if left[index] ~= right[index] then
            return false
        end
    end
    return true
end

function module:Edit(region, changes)
    if not self:CheckRegion(region, "fixed geometry") then
        return
    end
    if InCombatLockdown() then
        if not self:CheckRegion(region, "combat geometry", { "IsProtected" }) then
            return
        end
        local protected = region:IsProtected()
        if not self:Readable(protected) or protected then
            return
        end
    end
    local function Call(name, ...)
        if self:CheckRegion(region, "fixed geometry", { name }) then
            region[name](region, ...)
            return true
        end
    end
    if changes.width then
        Call("SetWidth", changes.width)
    end
    if changes.height then
        Call("SetHeight", changes.height)
    end
    if changes.point then
        local state = AnchorState(region)
        if not SameAnchor(state.point, changes.point) then
            local revision = state.revision
            local cleared = Call("ClearAllPoints")
            local placed = Call("SetPoint", unpack(changes.point))
            -- Extra setter callbacks mean a nested native update changed the
            -- region during our write; leave it uncached so repair can retry.
            if cleared and placed and state.revision == revision + 2 then
                state.point = { unpack(changes.point) }
            end
        end
    end
    if changes.justify then
        Call("SetJustifyH", changes.justify)
    end
    if changes.layer then
        Call("SetDrawLayer", unpack(changes.layer))
    end
end

function module:IsWriting()
    return writing
end

local function WatchBar(bar, texture)
    if
        not layout:CheckRegion(bar, "named bar hooks", { "GetStatusBarTexture", "SetStatusBarTexture" })
        or not layout:CheckRegion(texture, "named fill hook", { "SetAtlas" })
    then
        return false
    end
    -- Only named bars; ignore setter arguments, which may be secret. A native
    -- replacement invalidates our own last-write cache without reading texture state.
    if not watchedBars[bar] then
        watchedBars[bar] = true
        hooksecurefunc(bar, "SetStatusBarTexture", function()
            if not writing then
                if not layout:CheckRegion(bar, "bar artwork update", { "GetStatusBarTexture" }) then
                    return
                end
                local fill = bar:GetStatusBarTexture()
                if layout:Readable(fill) and fill ~= nil then
                    painted[fill] = nil
                end
            end
        end)
    end
    if not watchedFills[texture] then
        watchedFills[texture] = true
        hooksecurefunc(texture, "SetAtlas", function()
            if not writing then
                painted[texture] = nil
            end
        end)
    end
    return true
end

-- Static copies of the target mask pixels reflected by the atlas generator.
-- Keep mask UVs increasing: reflected UVs can clip the entire live fill.
local reflectedMasks = {
    ["ui-hud-unitframe-target-portraiton-bar-health-mask"] = "uiunitframetargethealthmask.blp",
    ["ui-hud-unitframe-target-portraiton-bar-mana-mask"] = "uiunitframetargetmanamask.blp",
}

local function Paint(texture, atlas, useSize, bar, mirror)
    mirror = legacyMode and mirror or false
    if not layout:Readable(atlas) or type(atlas) ~= "string" then
        layout:Warn("fixed artwork", "invalid atlas definition")
        return false
    end
    if not layout:CheckRegion(texture, "fixed artwork", { "SetAtlas", "SetTexture", "SetTexCoord" }) then
        return false
    end
    if bar and not WatchBar(bar, texture) then
        return false
    end
    local visual = bar and visualBars[bar]
    if visual and legacyMode then
        Paint(visual:GetStatusBarTexture(), atlas, false, visual)
        texture:SetAlpha(0)
    end
    local last = painted[texture]
    if
        last
        and last.atlas == atlas
        and last.legacy == legacyMode
        and last.mirror == mirror
        and last.useSize == useSize
    then
        return true
    end
    local data = legacyMode and app.legacyAtlases[atlas:lower()] or nil
    artwork[texture] = { atlas = atlas, useSize = useSize, bar = bar, mirror = mirror }
    local previous = writing
    writing = true
    if bar then
        if not layout:CheckRegion(bar, "fixed bar artwork", { "SetStatusBarTexture" }) then
            writing = previous
            return false
        end
        if data and not data[8] then
            writing = previous
            layout:Warn(atlas, "standalone fill missing")
            return false
        end
        -- The native bar setter accepts atlas names as well as file paths.
        -- Standalone files let the engine own fill UVs at every health/power value.
        local success = bar:SetStatusBarTexture(data and (mirror and data[9] or data[8]) or atlas)
        if not layout:Readable(success) or success == false then
            writing = previous
            layout:Warn(atlas, "client rejected status-bar artwork")
            return false
        end
    elseif data then
        local mask = mirror and reflectedMasks[atlas:lower()]
        if mask then
            texture:SetTexture("Interface/AddOns/SeamlessUnitframes/assets/legacy/masks/" .. mask)
            texture:SetTexCoord(0, 1, 0, 1)
        else
            texture:SetTexture(data[1])
            texture:SetTexCoord(mirror and data[5] or data[4], mirror and data[4] or data[5], data[6], data[7])
        end
        if useSize then
            layout:Edit(texture, { width = data[2], height = data[3] })
        end
    else
        texture:SetAtlas(atlas, useSize or false, nil, true)
    end
    painted[texture] = { atlas = atlas, legacy = legacyMode, mirror = mirror, useSize = useSize }
    writing = previous
    return true
end

-- A native target status bar explicitly inherits SecureFrameTemplate. Its
-- Camelot update can resize it in combat, but an addon cannot undo that resize.
-- Mirror setters into an ordinary visual bar instead; values may be secret and
-- are forwarded verbatim, never inspected or used in layout arithmetic.
function module:MirrorBar(source, visual, health, unit)
    visualBars[source] = visual
    hooksecurefunc(source, "SetMinMaxValues", function(_, ...)
        visual:SetMinMaxValues(...)
    end)
    hooksecurefunc(source, "SetValue", function(_, ...)
        visual:SetValue(...)
    end)
    hooksecurefunc(source, "SetStatusBarColor", function(_, ...)
        visual:SetStatusBarColor(...)
    end)
    if health then
        -- Max-health-loss updates shrink the live bar through this setter.
        hooksecurefunc(source, "SetWidth", function(_, ...)
            visual:SetWidth(...)
        end)
    end
    hooksecurefunc(source, "SetAlpha", function(_, ...)
        visual:SetAlpha(...)
    end)
    hooksecurefunc(source, "Show", function()
        visual:SetShown(legacyMode)
    end)
    hooksecurefunc(source, "Hide", function()
        visual:Hide()
    end)
    hooksecurefunc(source, "SetShown", function(_, shown)
        visual:SetShown(legacyMode and shown)
    end)
    if health then
        visual:SetMinMaxValues(0, UnitHealthMax(unit))
        visual:SetValue(UnitHealth(unit))
        -- Target-family fills carry their own green/yellow gradient. A green
        -- tint would remove its red component until a later color reset.
        visual:SetStatusBarColor(1, 1, 1)
    else
        visual:SetFillStyle(Enum.StatusBarFillStyle.Reverse)
        visual:SetMinMaxValues(0, 1)
        visual:SetValue(0)
        visual:SetStatusBarColor(1, 1, 1)
    end
end

function module:ShowVisualBars(legacy)
    for source, visual in pairs(visualBars) do
        visual:SetShown(legacy and source:IsShown())
        source:GetStatusBarTexture():SetAlpha(legacy and 0 or 1)
    end
end

function module:Art(texture, atlas, useSize, mirror)
    if not Paint(texture, atlas, useSize, nil, mirror) then
        return false
    end
    if not watchedArt[texture] then
        watchedArt[texture] = true
        hooksecurefunc(texture, "SetAtlas", function()
            if writing then
                return
            end
            painted[texture] = nil
            local definition = artwork[texture]
            if legacyMode and definition then
                -- Rebind old artwork before the native call returns, including
                -- in combat. Do not resize/reanchor protected regions in combat.
                Paint(texture, definition.atlas, not InCombatLockdown() and definition.useSize, nil, definition.mirror)
            end
        end)
    end
    return true
end

-- Only explicitly listed bars are bound. No children, regions, or runtime atlas
-- names are enumerated, stored, compared, lowercased, or used as table keys.
function module:Bar(bar, atlas, health, mirror)
    if not self:CheckRegion(bar, "named bar", { "GetStatusBarTexture", "SetStatusBarTexture" }) then
        return
    end
    local texture = bar:GetStatusBarTexture()
    if not self:CheckRegion(texture, "named bar fill") then
        return
    end
    local previous = bindings[texture]
    if health and previous and previous.atlas == atlas .. "-Status" then
        -- A geometry refresh must not turn an already tinted health fill green
        -- only for the color refresh below to replace it with white again.
        atlas = previous.atlas
    end
    bindings[texture] = { atlas = atlas, bar = bar, mirror = mirror }
    Paint(texture, atlas, false, bar, mirror)
end

-- The rounded player uses the full target geometry only in ordinary player art.
-- Vehicle, alternate-power and health-only presentations retain their Beta layout.
function module:IsRoundedPlayer(frame)
    if not roundedMode then
        return false
    end
    local unit = frame.unit
    if not self:Readable(unit) or unit ~= "player" then
        return false
    end
    local alternate = type(PlayerFrame_GetAlternatePowerBar) == "function" and PlayerFrame_GetAlternatePowerBar()
    return self:Readable(alternate)
        and not alternate
        and self:Readable(UNIT_FRAME_SHOW_HEALTH_ONLY)
        and not UNIT_FRAME_SHOW_HEALTH_ONLY
end

-- Resolve only addon-owned names from known frame families, never GetAtlas().
function module:HealthAtlas(bar, key)
    if not self:CheckRegion(bar, "health color bar", { "GetStatusBarTexture" }) then
        return nil
    end
    local family = key == "player" and (self:IsRoundedPlayer(PlayerFrame) and "Target" or "Player")
        or ((key == "pet" or key == "targettarget" or key == "focustarget") and "TargetofTarget" or "Target")
    if key == "party" then
        local frame = bar.unitFrame
        if not self:CheckRegion(frame, "party health color") then
            return nil
        end
        if not self:Readable(frame.state) or not self:Readable(frame.frameType) then
            self:Warn("party health color", "inaccessible art style")
            return nil
        end
        family = frame.state == "vehicle" and "Party-PortraitOn-Vehicle"
            or (frame.frameType == "CharacterFrameOn" and "CharacterFrameOnParty-PortraitOn" or "Party-PortraitOn")
    else
        if legacyMode and family == "Target" and key ~= "player" then
            local unit = bar.unit
            if self:Readable(unit) and type(unit) == "string" then
                local classification = UnitClassification(unit)
                if not self:Readable(classification) then
                    self:Warn("health color artwork", "inaccessible classification")
                    return nil
                end
                if classification == "minus" then
                    family = "Target-MinusMob"
                end
            end
        end
        family = family .. "-PortraitOn"
    end
    local atlas = "UI-HUD-UnitFrame-" .. family .. "-Bar-Health"
    local texture = bar:GetStatusBarTexture()
    if not self:CheckRegion(texture, "health color fill") then
        return nil
    end
    if not WatchBar(bar, texture) then
        return nil
    end
    bindings[texture] = { atlas = atlas, bar = bar, mirror = key == "player" and self:IsRoundedPlayer(PlayerFrame) }
    return atlas, texture
end

function module:HasHealthStatus(atlas)
    -- These families have a white variant in the exported atlas tables.
    return atlas ~= "UI-HUD-UnitFrame-Party-PortraitOn-Vehicle-Bar-Health"
end

function module:SetHealthAtlas(texture, atlas)
    if not self:Readable(texture) or texture == nil then
        return false
    end
    local binding = bindings[texture]
    if not binding then
        return false
    end
    if Paint(texture, atlas, false, binding.bar, binding.mirror) then
        binding.atlas = atlas
        return true
    end
    return false
end

-- AnimatedHealthLossMixin owns its timings and alpha. Match the selected live
-- fill/tint so its full-width starting frame cannot flash red over a colored bar.
function module:PlayerLoss(color)
    if not legacyMode and not lossColored then
        return
    end
    if
        not self:CheckPaths(PlayerFrame, "Player loss color", {
            "PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.PlayerFrameHealthBarAnimatedLoss",
        })
    then
        return
    end
    local bar =
        PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.PlayerFrameHealthBarAnimatedLoss
    if not self:CheckRegion(bar, "Player loss color", { "SetStatusBarColor" }) then
        return
    end
    local colored = legacyMode and color
    local family = self:IsRoundedPlayer(PlayerFrame) and "Target" or "Player"
    self:Bar(
        bar,
        "UI-HUD-UnitFrame-" .. family .. "-PortraitOn-Bar-Health" .. (colored and "-Status" or ""),
        nil,
        self:IsRoundedPlayer(PlayerFrame)
    )
    if colored then
        bar:SetStatusBarColor(color:GetRGB())
    else
        bar:SetStatusBarColor(1, 0, 0)
    end
    lossColored = colored and true or false
end

local function Request()
    if writing or not enabled then
        return
    end
    -- Repair in the native update's call stack. Waiting one rendered frame lets
    -- new atlas art draw with old coordinates/geometry and causes a rectangle flash.
    layout:Refresh()
end

local function RequestFrame(frame)
    if writing or not enabled or not layout:Readable(frame) or not frame then
        return
    end
    if not knownRoots[frame] and not app.unitFrames:KeyOf(frame) then
        return
    end
    local manager = EditModeManagerFrame
    if manager and manager:IsEditModeActive() and not lib:IsInEditMode() then
        -- The manager is still setting up native frames. Its EditMode.Enter
        -- event fires synchronously after setup, before the first rendered frame.
        if not openingSeen[frame] then
            openingSeen[frame] = true
            openingFrames[#openingFrames + 1] = frame
        end
        return
    end
    -- A native update invalidates this frame, not every unit frame in the suite.
    -- Keep the repair synchronous so the native art never draws with old geometry.
    layout:Refresh(false, frame)
end

local function Hook(object, name)
    if hooked[object] == nil then
        hooked[object] = {}
    end
    if not hooked[object][name] and layout:Readable(object[name]) and type(object[name]) == "function" then
        hooked[object][name] = true
        -- Ignore all native arguments: they may contain secret strings/numbers.
        hooksecurefunc(object, name, function()
            RequestFrame(object)
        end)
    end
end

local function Initialize()
    if initialized then
        return
    end
    initialized = true
    if type(UnitFrame_Initialize) == "function" then
        hooksecurefunc("UnitFrame_Initialize", RequestFrame)
    end
    if type(UnitFrameManaBar_UpdateType) == "function" then
        hooksecurefunc("UnitFrameManaBar_UpdateType", function(bar)
            if layout:Readable(bar) and (type(bar) == "table" or type(bar) == "userdata") then
                local frame = bar.unitFrame
                if layout:Readable(frame) then
                    RequestFrame(frame)
                end
            end
        end)
    end
    for _, name in ipairs({
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
            hooksecurefunc(name, function()
                RequestFrame(PlayerFrame)
            end)
        end
    end
end

function module:Refresh(restore, frame, selectedRoots)
    if (not enabled and not restore) or not app.db then
        return
    end
    if InCombatLockdown() then
        -- Preserve the active layout even if a profile change is pending. Only
        -- target-family visual regions are repaired; Edit checks protection.
        if enabled and applied and not writing then
            writing = true
            self:RepairTargets(selectedRoots or (frame and { frame } or app.unitFrames:All()))
            writing = false
        end
        return
    end
    local selected = app.db.profile.layout
    local legacy = not restore and (selected == "legacy" or selected == "legacyRounded")
    if not legacy and not applied then
        return
    end
    Initialize()
    legacyMode = legacy
    roundedMode = legacy and selected == "legacyRounded"
    local scoped = frame ~= nil or selectedRoots ~= nil
    local roots = selectedRoots or (frame and { frame } or app.unitFrames:All())
    if not scoped then
        for i = 1, 5 do
            local boss = _G["Boss" .. i .. "TargetFrame"]
            if boss then
                roots[#roots + 1] = boss
            end
        end
    end
    for _, frame in ipairs(roots) do
        if self:CheckRegion(frame, "unit frame") then
            knownRoots[frame] = true
            for _, name in ipairs({
                "CheckClassification",
                "UpdateArt",
                "UpdateHealthBarVisuals",
                "ToPlayerArt",
                "ToVehicleArt",
                "ToCharacterStyleArt",
                "UpdateNameTextAnchors",
                "Show",
                "SetShown",
            }) do
                Hook(frame, name)
            end
        end
    end
    if type(self.ApplyGeometry) ~= "function" then
        self:Warn("refresh", "missing fixed layout definitions")
        return
    end
    local previous = writing
    writing = true
    if not legacy then
        -- Retire every file override, including a temporarily unavailable named
        -- component. These are our own constant definitions, never snapshots.
        for texture, definition in pairs(artwork) do
            Paint(texture, definition.atlas, definition.useSize, definition.bar)
        end
    end
    self:ApplyGeometry(roots, legacy)
    self:ShowVisualBars(legacy)
    writing = previous
    applied = legacy
    if not legacy then
        self:HideLegacyBackgrounds()
    end
    if app.healthColor then
        if scoped then
            for _, root in ipairs(roots) do
                app.healthColor:RefreshFrame(root)
            end
        else
            app.healthColor:Refresh()
        end
    end
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
        "UNIT_DISPLAYPOWER",
    }) do
        self:RegisterEvent(event, Request)
    end
    self:Refresh()
end

function module:OnDisable()
    enabled = false
    openingFrames, openingSeen = {}, {}
    if not applied then
        return
    end
    if InCombatLockdown() then
        -- This is our own event frame; no Blizzard script is replaced or hooked.
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        waiter:SetScript("OnEvent", function(self)
            if not enabled then
                layout:Refresh(true)
            end
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
        end)
    else
        self:Refresh(true)
    end
end

function module:OnProfileRefresh()
    Request()
end

lib:RegisterCallback("enter", function()
    local roots = openingFrames
    openingFrames, openingSeen = {}, {}
    if enabled and #roots > 0 then
        layout:Refresh(false, nil, roots)
    end
end)
lib:RegisterCallback("exit", function()
    openingFrames, openingSeen = {}, {}
end)
