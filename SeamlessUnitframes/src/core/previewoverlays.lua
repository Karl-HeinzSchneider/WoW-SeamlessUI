---@type string, SeamlessUnitframes
local appName, app = ...

local lib = app.core:GetEditModeLibrary()
local keys = { "player", "target", "focus", "pet" }
local P = "UI-HUD-UnitFrame-"

---@class SeamlessUnitframes.PreviewOverlays : AceModule
---@field frames table<string, Frame>
local module = { frames = {} }
app.previewOverlays = app.addon:NewModule("PreviewOverlays", module)

local function Readable(value)
    return (not canaccessvalue or canaccessvalue(value)) and value ~= nil
end

local function Place(region, parent, point, relativePoint, x, y, width, height)
    region:ClearAllPoints()
    region:SetPoint(point, parent, relativePoint, x, y)
    if width then
        region:SetSize(width, height)
    end
end

local function Texture(parent, layer)
    return parent:CreateTexture(nil, layer or "BACKGROUND")
end

local function Create(key)
    -- No native unit-frame templates, scripts, unit bindings or parent propagation. These visual-only
    -- UIParent children never participate in native frame updates or Edit Mode selection.
    local frame = CreateFrame("Frame", appName .. app.unitFrames:Get(key).frameName .. "Preview", UIParent)
    frame:Hide()
    frame:EnableMouse(false)
    frame:SetSize(key == "pet" and 120 or 232, key == "pet" and 49 or 100)
    frame.unit = "player"
    frame.portrait = Texture(frame)
    frame.Portrait = frame.portrait
    frame.PortraitMask = frame:CreateMaskTexture()
    frame.PortraitMask:SetAtlas(key == "player" and P .. "Player-Portrait-Mask" or "CircleMask")
    frame.PortraitMask:SetAllPoints(frame.portrait)
    frame.portrait:AddMaskTexture(frame.PortraitMask)
    frame.FrameTexture = Texture(frame, "BORDER")
    frame.FrameTexture:SetPoint("CENTER")
    frame.ReputationColor = Texture(frame, "ARTWORK")
    local content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints(frame)
    frame.Content = content
    frame.name = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.Name = frame.name
    -- Opaque backing keeps a shorter VIP name from revealing live text below it.
    frame.NameBacking = Texture(frame)
    frame.NameBacking:SetColorTexture(0, 0, 0, 1)
    frame.NameBacking:SetAllPoints(frame.name)
    frame.LevelBackground = Texture(content, "OVERLAY")
    frame.LevelBackground:SetAtlas(P .. "SmallCircle", true)
    frame.LevelText = content:CreateFontString(nil, "OVERLAY", "WhiteLargeNumberFont")
    frame.LevelText:SetPoint("CENTER", frame.LevelBackground, "CENTER")
    for _, kind in ipairs({ "Health", "Mana" }) do
        local bar = CreateFrame("StatusBar", nil, frame)
        bar.unit, bar.unitFrame, bar.lockColor = "player", frame, true
        bar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
        bar.Background = Texture(bar)
        bar.Background:SetColorTexture(0, 0, 0, 1)
        bar.Background:SetAllPoints(bar)
        local mask = bar:CreateMaskTexture()
        bar:GetStatusBarTexture():AddMaskTexture(mask)
        bar.Background:AddMaskTexture(mask)
        bar[kind .. "BarMask"] = mask
        mask:SetPoint("TOPLEFT", kind == "Health" and -26 or -27, kind == "Health" and 3 or 4)
        bar.Text = content:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        bar.Text:SetPoint("CENTER", bar, "CENTER")
        frame[kind .. "Bar"] = bar
    end
    frame.healthbar = frame.HealthBar
    module.frames[key] = frame
    return frame
end

-- Reproduce only the selection artwork on our own surface. The native selection
-- retains all mouse, drag, snapping and settings behavior underneath this visual.
local selectionLayout = {
    TopRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = 8 },
    TopLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = 8 },
    BottomLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = -8 },
    BottomRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = -8 },
    TopEdge = { atlas = "_%s-NineSlice-EdgeTop" },
    BottomEdge = { atlas = "_%s-NineSlice-EdgeBottom" },
    LeftEdge = { atlas = "!%s-NineSlice-EdgeLeft" },
    RightEdge = { atlas = "!%s-NineSlice-EdgeRight" },
    Center = { atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8 },
}

local function UpdateSelection(frame, real)
    local native = real.Selection
    local visual = frame.SelectionVisual
    local shown = Readable(native) and native:IsShown()
    if not Readable(shown) or not shown then
        visual:Hide()
        return false
    end
    visual:SetAllPoints(native)
    local selected = native:IsSelected()
    local kit = Readable(selected) and selected and "editmode-actionbar-selected" or "editmode-actionbar-highlight"
    if visual.kit ~= kit then
        NineSliceUtil.ApplyLayout(visual, selectionLayout, kit)
        visual.kit = kit
    end
    local hover = native.MouseOverHighlight
    local hovered = Readable(hover) and hover:IsShown()
    visual.Hover:SetShown(Readable(hovered) and hovered or false)
    local label = native.Label
    local labelShown = Readable(label) and label:IsShown()
    local text = Readable(labelShown) and labelShown and label:GetText()
    visual.Label:SetText(Readable(text) and text or "")
    visual.Label:SetShown(Readable(labelShown) and labelShown or false)
    visual:Show()
    return true
end

local function CreateSelection(frame)
    local visual = CreateFrame("Frame", nil, frame, "NineSliceCodeTemplate")
    visual:EnableMouse(false)
    visual.Hover = CreateFrame("Frame", nil, visual, "NineSliceCodeTemplate")
    visual.Hover:EnableMouse(false)
    visual.Hover:SetAllPoints(visual)
    NineSliceUtil.ApplyLayout(visual.Hover, selectionLayout, "editmode-actionbar-highlight")
    visual.Hover:SetBlendMode("ADD")
    visual.Hover:SetAlpha(0.4)
    visual.Hover:Hide()
    visual.Label = visual:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    visual.Label:SetAllPoints(visual)
    frame.SelectionVisual = visual
    -- One owned stack above native unit art and native selections. The matching
    -- selection surface always draws over the VIP, independent of native strata.
    for index, region in ipairs({ frame, frame.HealthBar, frame.ManaBar, frame.Content, visual, visual.Hover }) do
        region:EnableMouse(false)
        region:SetFrameStrata("MEDIUM")
        region:SetFrameLevel(2000 + index)
        region:SetFixedFrameStrata(true)
        region:SetFixedFrameLevel(true)
    end
    return frame
end

local function Geometry(frame, key, character)
    local layout = app.legacyLayout
    local old = app.db.profile.layout == "legacy"
    local player, pet = key == "player", key == "pet"
    local family = pet and "TargetofTarget-PortraitOn" or (player and "Player-PortraitOn" or "Target-PortraitOn")
    layout:Art(frame.FrameTexture, P .. family, true)
    if pet then
        Place(frame.portrait, frame, "TOPLEFT", "TOPLEFT", 5, -5, 37, 37)
        layout:ApplyToTPreview(frame, character.powerType)
    else
        Place(
            frame.portrait,
            frame,
            player and "TOPLEFT" or "TOPRIGHT",
            player and "TOPLEFT" or "TOPRIGHT",
            player and 24 or -26,
            -19,
            player and 60 or 58,
            player and 60 or 58
        )
        local health, mana = frame.HealthBar, frame.ManaBar
        local x, y =
            player and (old and 85 or 87) or (old and 23 or 21), player and (old and -41 or -43) or (old and -40 or -41)
        Place(health, frame, "TOPLEFT", "TOPLEFT", x, y, player and 124 or 126, player and (old and 19 or 20) or 20)
        Place(
            mana,
            frame,
            "TOPLEFT",
            "TOPLEFT",
            player and x or (old and 23 or 17),
            player and -61 or (old and -61 or -60),
            player and 124 or 134,
            10
        )
        layout:Bar(health, P .. family .. "-Bar-Health", true)
        layout:ApplyPreviewPower(mana, family, character.powerType)
        layout:Art(health.HealthBarMask, P .. family .. "-Bar-Health-Mask", true)
        layout:Art(mana.ManaBarMask, P .. family .. "-Bar-Mana-Mask", true)
        Place(health.HealthBarMask, health, "TOPLEFT", "TOPLEFT", player and -2 or -1, 6)
        if player then
            health.HealthBarMask:SetHeight(old and 31 or 32)
            mana.ManaBarMask:SetWidth(128)
        end
        Place(mana.ManaBarMask, mana, "TOPLEFT", "TOPLEFT", player and -2 or -61, player and 2 or 3)
        if player then
            Place(
                frame.name,
                frame,
                old and "TOPLEFT" or "CENTER",
                "TOPLEFT",
                old and 88 or 149,
                old and -27 or -37,
                old and 96 or 116,
                12
            )
        else
            layout:Art(frame.ReputationColor, P .. "Target-PortraitOn-Type", true)
            Place(frame.ReputationColor, frame, "TOPRIGHT", "TOPRIGHT", old and -75 or -82, old and -25 or -26)
            frame.ReputationColor:SetVertexColor(
                character.reaction <= 4 and 1 or 0,
                character.reaction >= 4 and 1 or 0,
                0
            )
            Place(
                frame.name,
                frame.ReputationColor,
                "TOPLEFT",
                "TOPRIGHT",
                old and -133 or -126,
                old and -1 or -4,
                117,
                12
            )
        end
        frame.name:SetJustifyH(old and "LEFT" or "CENTER")
    end
    frame.ReputationColor:SetShown(not player and not pet)
    local mode = app.db.profile.unitFrames[key].levelDisplay
    local levelScale = mode == "smaller" and 0.7 or 1
    frame.LevelBackground:SetScale(levelScale)
    Place(
        frame.LevelBackground,
        frame,
        "CENTER",
        player and "BOTTOMLEFT" or "BOTTOMRIGHT",
        (player and 32.5 or -32.5) / levelScale,
        26.5 / levelScale
    )
    frame.LevelBackground:SetShown(not pet and mode ~= "hidden" and character.level ~= nil)
    frame.LevelText:SetScale(levelScale)
    frame.LevelText:SetText(character.level or "")
    frame.LevelText:SetShown(not pet and mode ~= "hidden" and character.level ~= nil)
end

function module:Refresh()
    local active = self:IsEnabled() and app.addon:IsEnabled() and lib:IsInEditMode() and not InCombatLockdown()
    for _, key in ipairs(keys) do
        local real = _G[app.unitFrames:Get(key).frameName]
        local frame = self.frames[key]
        local shown = active and Readable(real) and real:IsShown()
        local visible = Readable(shown) and shown
        if visible then
            frame = frame or CreateSelection(Create(key))
            local character = app.previewCharacters:Get(frame, key)
            visible = character ~= nil
            if visible then
                local scale, parentScale = real:GetEffectiveScale(), UIParent:GetEffectiveScale()
                if Readable(scale) and Readable(parentScale) and UpdateSelection(frame, real) then
                    frame:SetScale(scale / parentScale)
                    Place(frame, real, "TOPLEFT", "TOPLEFT", 0, 0)
                    Geometry(frame, key, character)
                    for _, kind in ipairs({ "Health", "Mana" }) do
                        local bar = frame[kind .. "Bar"]
                        local value = kind == "Health" and character.health or character.power
                        local maximum = kind == "Health" and character.healthMax or character.powerMax
                        bar:SetMinMaxValues(0, maximum)
                        bar:SetValue(value)
                        bar:SetStatusBarColor(1, 1, 1)
                        bar.Text:SetText(value .. " / " .. maximum)
                        bar.Text:SetShown(GetCVarBool("statusText"))
                    end
                    SetPortraitTexture(frame.portrait, "player")
                    app.healthColor:ApplyPreview(frame, key)
                    app.nameDisplay:ApplyPreview(frame, key)
                    app.classIcon:ApplyPreview(frame, key)
                    app.portraitDragon:ApplyPreview(frame, key, character)
                else
                    visible = false
                end
            end
        end
        if frame then
            frame:SetShown(visible or false)
        end
    end
end

function module:OnInitialize()
    for _, key in ipairs(keys) do
        CreateSelection(Create(key))
    end
    local driver = CreateFrame("Frame")
    self.driver = driver
    driver:Hide()
    driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    driver:SetScript("OnEvent", function()
        self:Refresh()
    end)
    local elapsed = 0
    driver:SetScript("OnUpdate", function(_, delta)
        -- Keep hover/selection feedback synchronous with the next draw, without
        -- repainting VIP artwork or touching a native script on every frame.
        for key, frame in pairs(self.frames) do
            if frame:IsShown() then
                local real = _G[app.unitFrames:Get(key).frameName]
                if not Readable(real) or not UpdateSelection(frame, real) then
                    frame:Hide()
                end
            end
        end
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            elapsed = 0
            self:Refresh()
        end
    end)
    for _, owner in ipairs({
        app.legacyLayout,
        app.healthColor,
        app.nameDisplay,
        app.classIcon,
        app.levelDisplay,
        app.portraitDragon,
    }) do
        hooksecurefunc(owner, "Refresh", function()
            self:Refresh()
        end)
    end
    lib:RegisterCallback("enter", function()
        driver:Show()
        self:Refresh()
    end)
    lib:RegisterCallback("exit", function()
        driver:Hide()
        self:Refresh()
    end)
end

module.OnEnable = module.Refresh
module.OnDisable = module.Refresh
module.OnProfileRefresh = module.Refresh
