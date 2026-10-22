---@type string, SeamlessUnitframes
local _, app = ...
local module = app.legacyLayout
local backgrounds = {}
local targetVisuals = {}
local redirectedMasks = {}
local P = "UI-HUD-UnitFrame-"

local function Equal(value, expected)
    return module:Readable(value) and value == expected
end

local function Flag(value)
    return module:Readable(value) and value and true or false
end

local function Point(region, point, relative, relativePoint, x, y, width, height, justify)
    if not module:CheckRegion(relative, "fixed anchor") then
        return
    end
    module:Edit(
        region,
        { point = { point, relative, relativePoint, x, y }, width = width, height = height, justify = justify }
    )
end

local function PvP(icon, parent, side, x, legacy)
    if InCombatLockdown() then
        return
    end
    if not module:CheckRegion(icon, "PvP icon", { "IsShown" }) then
        return
    end
    Point(icon, "TOP", parent, side, x, legacy and -50 or -65)
    if not legacy then
        return
    end
    if not module:CheckRegion(parent, "PvP background", { "CreateTexture" }) then
        return
    end
    local background = backgrounds[icon]
    if not background then
        background = parent:CreateTexture(nil, "OVERLAY", nil, side == "TOPLEFT" and 3 or -1)
        if not module:CheckRegion(background, "PvP circle", { "SetAtlas", "SetScale", "SetPoint", "SetShown" }) then
            return
        end
        background:SetAtlas(P .. "SmallCircle", true)
        background:SetScale(0.8)
        backgrounds[icon] = background
        -- A new circle follows the frame's Hide PvP icon setting.
        if app.pvpIcon then
            app.pvpIcon:Refresh()
        end
    end
    Point(background, "TOP", parent, side, x, -50)
    local shown = icon:IsShown()
    if module:Readable(shown) then
        background:SetShown(shown)
    end
    Point(icon, "CENTER", background, "CENTER", 0, 0)
end

local powerNames = { MANA = "Mana", RAGE = "Rage", FOCUS = "Focus", ENERGY = "Energy", RUNIC_POWER = "RunicPower" }
-- Full atlas overrides in the client's PowerBarColorUtil.lua.
local powerAtlases = {
    LUNAR_POWER = "Unit_Druid_AstralPower_Fill",
    MAELSTROM = "Unit_Shaman_Maelstrom_Fill",
    INSANITY = "Unit_Priest_Insanity_Fill",
    FURY = "Unit_DemonHunter_Fury_Fill",
    PAIN = "_DemonHunter-DemonicPainBar",
    EBON_MIGHT = "Unit_Evoker_EbonMight_Fill",
}
local function Power(bar, family, unit, alternate, previewPowerType)
    if not module:Readable(unit) or type(unit) ~= "string" then
        module:Warn("power artwork", "inaccessible unit token")
        return
    end
    local _, token, altR = UnitPowerType(unit)
    if previewPowerType then
        token, altR = previewPowerType, nil
    end
    if not module:Readable(token) then
        module:Warn("power artwork", "inaccessible power type")
        return
    end
    local fullAtlas = powerAtlases[token]
    if fullAtlas then
        module:Bar(bar, fullAtlas)
        return
    end
    local element = powerNames[token]
    if not element then
        -- UnitFrameManaBar_UpdateType uses Mana (or its tintable variant) when
        -- the power definition has no resource-specific atlas element.
        if not module:Readable(altR) then
            module:Warn("power artwork", "inaccessible fallback color")
            return
        end
        element = altR and "Mana-Status" or "Mana"
    end
    local suffix = alternate and powerNames[token] and (element == "Mana" or element == "Energy") and "-ClassResource"
        or ""
    module:Bar(bar, P .. family .. suffix .. "-Bar-" .. element)
end

local function Player(frame, old)
    if
        not module:CheckPaths(frame, "Player", {
            "PlayerFrameContainer.FrameTexture",
            "PlayerFrameContainer.VehicleFrameTexture",
            "PlayerFrameContainer.AlternatePowerFrameTexture",
            "PlayerFrameContainer.FrameFlash",
            "PlayerFrameContainer.PlayerPortraitMask",
            "PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar",
            "PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBarMask",
            "PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar.ManaBarMask",
            "PlayerFrameContent.PlayerFrameContentMain.StatusTexture",
        })
    then
        return
    end
    local main = frame.PlayerFrameContent.PlayerFrameContentMain
    local art = frame.PlayerFrameContainer
    local container = main.HealthBarsContainer
    local health, mana = container.HealthBar, main.ManaBarArea.ManaBar
    if not module:Readable(frame.unit) then
        module:Warn("Player", "inaccessible art state")
        return
    end
    local vehicle = Equal(frame.unit, "vehicle")
    local alternate = type(PlayerFrame_GetAlternatePowerBar) == "function" and Flag(PlayerFrame_GetAlternatePowerBar())
    local healthOnly = Flag(UNIT_FRAME_SHOW_HEALTH_ONLY)
    module:Art(
        art.FrameTexture,
        healthOnly and "plunderstorm-ui-hud-unitframe-player-portraiton" or P .. "Player-PortraitOn",
        true
    )
    module:Art(art.VehicleFrameTexture, P .. "Player-PortraitOn-Vehicle", true)
    module:Art(art.AlternatePowerFrameTexture, P .. "Player-PortraitOn-ClassResource", true)
    module:Art(art.PlayerPortraitMask, P .. "Player-Portrait-Mask")
    module:Edit(art.PlayerPortraitMask, { width = 60, height = 60 })
    module:Bar(health, P .. "Player-PortraitOn-Bar-Health", true)
    module:Bar(container.PlayerFrameTempMaxHealthLoss, P .. "Player-PortraitOn-Bar-TempHPLoss")
    module:Art(
        container.HealthBarMask,
        old and healthOnly and not vehicle and "plunderstorm-ui-hud-unitframe-player-portraiton-bar-health-mask"
            or P .. "Player-PortraitOn-Bar-Health-Mask"
    )
    module:Art(
        mana.ManaBarMask,
        alternate and not vehicle and "Unit_BarMask" or P .. "Player-PortraitOn-Bar-Mana-Mask",
        not (old and vehicle)
    )
    Power(mana, "Player-PortraitOn", frame.unit, alternate and not vehicle)
    local nameX = vehicle and 96 or 88
    local nameY = -27
    if LOCALE_zhCN or LOCALE_zhTW then
        nameX = vehicle and 92 or 85
        nameY = LOCALE_zhCN and -26 or -27
    end
    Point(
        PlayerName,
        old and "TOPLEFT" or "CENTER",
        main,
        "TOPLEFT",
        old and nameX or 149,
        old and nameY or -37,
        old and 96 or 116,
        nil,
        old and "LEFT" or "CENTER"
    )
    local height = old and (healthOnly and 32 or (vehicle and 20 or 19)) or 20
    Point(
        container,
        "TOPLEFT",
        main,
        "TOPLEFT",
        old and (vehicle and 91 or 85) or 87,
        old and (vehicle and -40 or -41) or -46,
        old and vehicle and 118 or 124,
        old and height or 15
    )
    Point(health, "TOPLEFT", container, "TOPLEFT", 0, old and 0 or 3, 124, height)
    Point(
        container.HealthBarMask,
        "TOPLEFT",
        old and vehicle and container or health,
        "TOPLEFT",
        old and vehicle and -8 or -2,
        6,
        nil,
        old and (healthOnly and 37 or 31) or 32
    )
    Point(
        mana,
        "TOPLEFT",
        main.ManaBarArea,
        "TOPLEFT",
        old and (vehicle and 91 or 85) or 87,
        -61,
        old and vehicle and 118 or 124,
        10
    )
    module:Edit(mana.ManaBarMask, { width = old and vehicle and 121 or 128 })
    local flashAtlas = old and vehicle and P .. "Player-PortraitOn-Vehicle-InCombat"
        or (
            old and healthOnly and "plunderstorm-ui-hud-unitframe-player-portraiton-incombat"
            or P .. (alternate and "Player-PortraitOn-ClassResource-InCombat" or "Player-PortraitOn-InCombat")
        )
    module:Art(art.FrameFlash, flashAtlas, true)
    module:Art(
        main.StatusTexture,
        P .. (old and vehicle and "Player-PortraitOn-Vehicle-Status" or "Player-PortraitOn-Status"),
        true
    )
    Point(
        art.FrameFlash,
        "CENTER",
        art,
        "CENTER",
        old and (vehicle and -3.5 or (healthOnly and -1 or (alternate and -2 or -1.5))) or 0,
        old and ((healthOnly or alternate) and 0.5 or 1) or 0
    )
    Point(
        main.StatusTexture,
        "TOPLEFT",
        art,
        "TOPLEFT",
        old and (vehicle and 11 or 18) or 17,
        old and vehicle and -8 or -14
    )
    if
        module:CheckPaths(
            frame,
            "Player contextual art",
            { "PlayerFrameContent.PlayerFrameContentContextual.AttackIcon" }
        )
    then
        module:Edit(
            frame.PlayerFrameContent.PlayerFrameContentContextual.AttackIcon,
            { layer = { "OVERLAY", old and 2 or 3 } }
        )
    end
    PvP(main.PvpBackgroundIcon, main, "TOPLEFT", old and 20 or 22, old)
    Point(
        PlayerPVPTimerText,
        "RIGHT",
        old and backgrounds[main.PvpBackgroundIcon] or main.PvpBackgroundIcon,
        "LEFT",
        2,
        0
    )
end

local function PredictionVisuals(source, visual, old, nativeMask, visualMask)
    if InCombatLockdown() then
        return
    end
    local owner, mask = old and visual or source, old and visualMask or nativeMask
    for _, key in ipairs({ "MyHealPredictionBar", "OtherHealPredictionBar", "HealAbsorbBar", "TotalAbsorbBar" }) do
        local segment = source[key]
        if module:CheckRegion(segment, "target prediction", { "SetParent", "SetAllPoints", "SetStatusBar" }) then
            segment:SetParent(owner)
            segment:SetStatusBar(owner)
            segment:ClearAllPoints()
            segment:SetAllPoints(owner)
            for _, textureKey in ipairs({ "Fill", "TiledFillOverlay" }) do
                local texture = segment[textureKey]
                if module:Readable(texture) and texture then
                    texture:RemoveMaskTexture(old and nativeMask or visualMask)
                    texture:AddMaskTexture(mask)
                end
            end
            local fillMask = segment.FillMask
            if module:CheckRegion(fillMask, "target prediction mask", { "SetPoint" }) then
                redirectedMasks[fillMask] = old
                if not redirectedMasks[segment] then
                    redirectedMasks[segment] = true
                    local redirecting = false
                    hooksecurefunc(fillMask, "SetPoint", function(_, point, relative, ...)
                        if
                            not redirecting
                            and redirectedMasks[fillMask]
                            and module:Readable(relative)
                            and relative == source:GetStatusBarTexture()
                        then
                            redirecting = true
                            -- Forward native offsets, including secrets, without reading them.
                            fillMask:SetPoint(point, visual:GetStatusBarTexture(), ...)
                            redirecting = false
                        end
                    end)
                end
            end
        end
    end
    for _, key in ipairs({ "OverAbsorbGlow", "OverHealAbsorbGlow" }) do
        local glow = source[key]
        if module:CheckRegion(glow, "target absorb glow", { "SetParent", "ClearAllPoints", "SetPoint" }) then
            glow:SetParent(owner)
            glow:ClearAllPoints()
            if key == "OverAbsorbGlow" then
                glow:SetPoint("TOPLEFT", owner, "TOPRIGHT", -7, 0)
                glow:SetPoint("BOTTOMLEFT", owner, "BOTTOMRIGHT", -7, 0)
            else
                glow:SetPoint("BOTTOMRIGHT", owner, "BOTTOMLEFT", 7, 0)
                glow:SetPoint("TOPRIGHT", owner, "TOPLEFT", 7, 0)
            end
        end
    end
end

local function TargetVisual(frame, main, old)
    if frame ~= TargetFrame and frame ~= FocusFrame then
        return main.HealthBarsContainer
    end
    local visual = targetVisuals[frame]
    if old and not visual and not InCombatLockdown() then
        -- Ordinary frames have no secure template or protected children. They
        -- inherit visibility and scale, but are never anchors for protected bars.
        visual = CreateFrame("Frame", nil, main)
        visual.HealthBar = CreateFrame("StatusBar", nil, visual)
        visual.TempMaxHealthLoss = CreateFrame("StatusBar", nil, visual)
        visual.HealthBarMask = visual:CreateMaskTexture(nil, "ARTWORK")
        for _, key in ipairs({ "HealthBar", "TempMaxHealthLoss" }) do
            local bar = visual[key]
            bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
            -- Match TargetFrame.xml so native prediction segments remain above
            -- the health fill after their parent moves to the visual bar.
            module:Edit(bar:GetStatusBarTexture(), { layer = { "BACKGROUND", 0 } })
            bar:GetStatusBarTexture():AddMaskTexture(visual.HealthBarMask)
            module:MirrorBar(main.HealthBarsContainer[key], bar, key == "HealthBar", frame.unit)
        end
        -- Keep native SetText/status logic and fonts. These regions are not
        -- protected frames; anchor them once to the stable visual container.
        targetVisuals[frame] = visual
    end
    if old and visual then
        for _, key in ipairs({ "HealthBarText", "LeftText", "RightText", "DeadText", "UnconsciousText" }) do
            local text = main.HealthBarsContainer[key]
            if module:CheckRegion(text, "target health text") then
                if not InCombatLockdown() and module:CheckRegion(text, "target text owner", { "SetParent" }) then
                    text:SetParent(visual.HealthBar)
                end
                local side = key == "LeftText" and "LEFT" or (key == "RightText" and "RIGHT" or "CENTER")
                Point(text, side, visual, side, key == "LeftText" and 2 or (key == "RightText" and -5 or 0), 0)
            end
        end
    elseif not old and visual then
        for _, key in ipairs({ "HealthBarText", "LeftText", "RightText", "DeadText", "UnconsciousText" }) do
            local side = key == "LeftText" and "LEFT" or (key == "RightText" and "RIGHT" or "CENTER")
            if module:CheckRegion(main.HealthBarsContainer[key], "native target text owner", { "SetParent" }) then
                main.HealthBarsContainer[key]:SetParent(main.HealthBarsContainer)
            end
            Point(
                main.HealthBarsContainer[key],
                side,
                main.HealthBarsContainer,
                side,
                key == "LeftText" and 2 or (key == "RightText" and -5 or 0),
                0
            )
        end
    end
    if visual then
        PredictionVisuals(
            main.HealthBarsContainer.HealthBar,
            visual.HealthBar,
            old,
            main.HealthBarsContainer.HealthBarMask,
            visual.HealthBarMask
        )
    end
    return old and visual or main.HealthBarsContainer
end

local function Target(frame, old)
    if
        not module:CheckPaths(frame, "Target/Focus/Boss", {
            "TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar",
            "TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBarMask",
            "TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.TempMaxHealthLoss",
            "TargetFrameContent.TargetFrameContentMain.Name",
            "TargetFrameContent.TargetFrameContentMain.ReputationColor",
            "TargetFrameContent.TargetFrameContentMain.ManaBar.RightText",
            "TargetFrameContent.TargetFrameContentMain.ManaBar.ManaBarMask",
            "TargetFrameContent.TargetFrameContentContextual",
            "TargetFrameContainer.FrameTexture",
            "TargetFrameContainer.Flash",
        })
    then
        return
    end
    local main = frame.TargetFrameContent.TargetFrameContentMain
    local art = frame.TargetFrameContainer
    if not module:Readable(frame.unit) or type(frame.unit) ~= "string" then
        module:Warn("Target", "inaccessible unit")
        return
    end
    local container = TargetVisual(frame, main, old)
    if not container then
        return
    end
    local classification = UnitClassification(frame.unit)
    if not module:Readable(classification) then
        module:Warn("Target", "inaccessible classification")
        -- Camelot uses the full health bar for every classification. Retain a
        -- valid fixed layout when the client withholds the target classification.
        classification = "normal"
    end
    local minus = classification == "minus"
    local rare = classification == "rare" or classification == "rareelite"
    local family = old and minus and "Target-MinusMob-PortraitOn" or "Target-PortraitOn"
    module:Art(
        art.FrameTexture,
        P .. (minus and "Target-MinusMob-PortraitOn" or (rare and "Target-Rare-PortraitOn" or "Target-PortraitOn")),
        true
    )
    module:Art(art.Flash, P .. (minus and "Target-MinusMob-PortraitOn-InCombat" or "Target-PortraitOn-InCombat"), true)
    local boss = UnitIsBossMob(frame.unit)
    if module:Readable(boss) and (boss or rare or classification == "elite") then
        local decoration = boss and "Boss-Gold-Winged" or (rare and "Boss-Rare-Silver-Winged" or "Boss-Gold")
        module:Art(art.BossPortraitFrameTexture, P .. "Target-PortraitOn-" .. decoration, true)
    end
    module:Art(main.ReputationColor, P .. "Target-PortraitOn-Type", true)
    -- Source bindings own the selected health tint; Paint mirrors that same
    -- binding into the visual without replacing a white fill with green first.
    module:Bar(main.HealthBarsContainer.HealthBar, P .. family .. "-Bar-Health", true)
    module:Bar(main.HealthBarsContainer.TempMaxHealthLoss, P .. family .. "-Bar-TempHPLoss")
    module:Art(container.HealthBarMask, P .. family .. "-Bar-Health-Mask", true)
    module:Art(main.ManaBar.ManaBarMask, P .. "Target-PortraitOn-Bar-Mana-Mask", true)
    Power(main.ManaBar, "Target-PortraitOn", frame.unit)
    Point(
        main.Name,
        "TOPLEFT",
        main.ReputationColor,
        "TOPRIGHT",
        old and -133 or -126,
        old and -1 or -4,
        117,
        nil,
        old and "LEFT" or "CENTER"
    )
    Point(main.ReputationColor, "TOPRIGHT", main, "TOPRIGHT", old and -75 or -82, old and -25 or -26)
    Point(
        container,
        "BOTTOMRIGHT",
        art,
        "LEFT",
        old and (minus and 148 or 149) or 147,
        old and (minus and -1 or -10) or -9,
        old and minus and 125 or 126,
        old and (minus and 12 or 20) or 15
    )
    Point(
        container.HealthBar,
        "TOPLEFT",
        container,
        "TOPLEFT",
        0,
        old and 0 or 3,
        old and minus and 125 or 126,
        old and minus and 12 or 20
    )
    Point(container.HealthBarMask, "TOPLEFT", container, "TOPLEFT", -1, old and (minus and 2 or 6) or 9)
    Point(
        container.TempMaxHealthLoss,
        "TOPLEFT",
        container,
        "TOPLEFT",
        0,
        0,
        old and minus and 125 or 126,
        old and minus and 12 or 20
    )
    -- The mana bar is protected: anchoring it to our visual would protect that
    -- visual as well. Use the equivalent fixed native-art anchor in Legacy.
    if old then
        Point(main.ManaBar, "TOPRIGHT", art, "LEFT", minus and 156 or 157, minus and -2 or -11, 134, 10)
    else
        Point(main.ManaBar, "TOPRIGHT", container, "BOTTOMRIGHT", 4, -1, 134, 10)
    end
    Point(main.ManaBar.RightText, "RIGHT", main.ManaBar, "RIGHT", old and -13 or -3, 0)
    local flashParent = art
    if not old and module:CheckPaths(TargetFrame, "native target flash anchor", { "TargetFrameContainer" }) then
        flashParent = TargetFrame.TargetFrameContainer
    end
    Point(art.Flash, "CENTER", flashParent, "CENTER", old and 0 or -1, old and 2 or 1)
    PvP(
        frame.TargetFrameContent.TargetFrameContentContextual.PvpBackgroundIcon,
        frame.TargetFrameContent.TargetFrameContentContextual,
        "TOPRIGHT",
        old and -23 or -24,
        old
    )
    if Equal(frame.isBossFrame, true) then
        module:Art(art.FrameTexture, P .. "Target-Boss-Small-PortraitOff", true)
        module:Art(art.Flash, P .. "Target-Boss-Small-PortraitOff-InCombat", true)
        module:Art(main.ReputationColor, P .. "Target-Boss-Small-PortraitOff-Type", true)
        module:Bar(container.HealthBar, P .. "Target-Boss-Small-PortraitOff-Bar-Health", true)
        module:Art(container.HealthBarMask, P .. "Party-PortraitOff-Bar-Health-Mask", true)
        module:Art(main.ManaBar.ManaBarMask, P .. "Party-PortraitOff-Bar-Mana-Mask", true)
        Power(main.ManaBar, "Target-Boss-Small-PortraitOff", frame.unit)
        Point(art.Flash, "CENTER", art, "CENTER", -12, 2)
        Point(main.ReputationColor, "TOPRIGHT", main, "TOPRIGHT", -86, -32)
        Point(main.Name, "TOPLEFT", main.ReputationColor, "TOPRIGHT", -56, -1, 55, nil, "CENTER")
        Point(container, "BOTTOMRIGHT", art, "LEFT", 145, -6, 84, 10)
        module:Edit(container.HealthBar, { width = 84, height = 10 })
        Point(container.HealthBarMask, "TOPLEFT", main, "TOPLEFT", 40, -43)
        Point(main.ManaBar, "TOPRIGHT", container, "BOTTOMRIGHT", 0, -1, 84, 7)
        Point(main.ManaBar.RightText, "RIGHT", main.ManaBar, "RIGHT", -5, 0)
        Point(main.ManaBar.ManaBarMask, "TOPLEFT", main, "TOPLEFT", 40, -52)
    end
end

local function Small(frame, pet, old, previewPowerType)
    local name, portrait = pet and PetName or frame.Name, pet and PetPortrait or frame.Portrait
    local health, mana = pet and PetFrameHealthBar or frame.HealthBar, pet and PetFrameManaBar or frame.ManaBar
    if not module:CheckRegion(health, "Pet/ToT health") or not module:CheckRegion(mana, "Pet/ToT mana") then
        return
    end
    module:Art(pet and PetFrameTexture or frame.FrameTexture, P .. "TargetofTarget-PortraitOn", true)
    module:Bar(health, P .. "TargetofTarget-PortraitOn-Bar-Health", true)
    Power(mana, "TargetofTarget-PortraitOn", frame.unit, nil, previewPowerType)
    module:Art(pet and PetFrameHealthBarMask or health.HealthBarMask, P .. "Party-PortraitOn-Bar-Health-Mask", true)
    module:Art(pet and PetFrameManaBarMask or mana.ManaBarMask, P .. "Party-PortraitOn-Bar-Mana-Mask", true)
    Point(name, "TOPLEFT", portrait, "TOPRIGHT", 2, old and 0 or -1, 68, nil, old and "LEFT" or "CENTER")
    if pet then
        module:Art(PetFrameFlash, P .. "TargetofTarget-PortraitOn-InCombat", true)
        module:Art(PetAttackModeTexture, P .. "TargetofTarget-PortraitOn-Status", true)
        Point(health, "BOTTOMLEFT", portrait, "RIGHT", old and 2 or 3, old and -3.5 or -4, 70, 10)
        Point(PetAttackModeTexture, "TOPLEFT", frame, "TOPLEFT", 0, old and 1 or 0)
        Point(PetFrameFlash, "TOPLEFT", frame, "TOPLEFT", old and 1 or 0, 0)
    else
        Point(health, "BOTTOMRIGHT", frame, "RIGHT", old and -6 or -5, old and -2.5 or -3, 70, 10)
    end
    Point(pet and PetFrameHealthBarMask or health.HealthBarMask, "TOPLEFT", health, "TOPLEFT", old and -29 or -26, 3)
    Point(mana, "TOPLEFT", health, "BOTTOMLEFT", old and -4 or -2, old and -1 or -2, 74, 7)
end

-- The Edit Mode stand-ins use the same fixed ToT geometry and artwork.
function module:ApplyToTPreview(frame, powerType)
    Small(frame, false, app.db.profile.layout == "legacy", powerType)
end

local function Party(frame, old)
    if
        not module:CheckPaths(frame, "Party", {
            "Name",
            "HealthBarContainer.HealthBar",
            "HealthBarContainer.HealthBarMask",
            "ManaBar.ManaBarMask",
            "PartyMemberOverlay.RoleIcon",
            "PartyMemberOverlay.Status",
            "Flash",
            "Texture",
            "VehicleTexture",
        })
    then
        return
    end
    if not module:Readable(frame.state) or not module:Readable(frame.frameType) then
        module:Warn("Party", "inaccessible art style")
        return
    end
    local vehicle = Equal(frame.state, "vehicle")
    local character = Equal(frame.frameType, "CharacterFrameOn")
    local healthOnly = old and not vehicle and not character and Flag(UNIT_FRAME_SHOW_HEALTH_ONLY)
    local family = vehicle and "Party-PortraitOn-Vehicle"
        or (character and "CharacterFrameOnParty-PortraitOn" or "Party-PortraitOn")
    local container, mana, overlay = frame.HealthBarContainer, frame.ManaBar, frame.PartyMemberOverlay
    module:Art(
        frame.Texture,
        healthOnly and "plunderstorm-UI-HUD-UnitFrame-Party-PortraitOn"
            or P .. (character and "CharacterFrameOnParty-PortraitOn" or "Party-PortraitOn"),
        true
    )
    module:Art(frame.VehicleTexture, P .. "Party-PortraitOn-Vehicle", true)
    module:Art(frame.Flash, P .. family .. "-InCombat", true)
    module:Art(overlay.Status, P .. family .. "-Status", true)
    module:Bar(container.HealthBar, P .. family .. "-Bar-Health", true)
    module:Art(
        container.HealthBarMask,
        healthOnly and "plunderstorm-ui-hud-unitframe-party-portraiton-bar-health-mask"
            or P .. family .. "-Bar-Health-Mask",
        true
    )
    module:Art(
        mana.ManaBarMask,
        character and "ui-hud-unitframe-playerframeonparty-portraiton-bar-mana-mask" or P .. family .. "-Bar-Mana-Mask",
        not character
    )
    Power(mana, family, mana.unit)
    local nameY = old and ((LOCALE_zhCN or LOCALE_zhTW) and -4 or -6) or ((LOCALE_zhCN or LOCALE_zhTW) and -6 or -7)
    Point(
        frame.Name,
        "TOPLEFT",
        frame,
        "TOPLEFT",
        old and (vehicle and 49 or 46) or 48,
        nameY,
        vehicle and 56 or (old and 57 or 55)
    )
    Point(overlay.RoleIcon, "TOPRIGHT", overlay, "TOPRIGHT", -5, (old or vehicle) and -5 or -7)
    Point(frame.Flash, "TOPLEFT", frame, "TOPLEFT", vehicle and -4 or 1, vehicle and 4 or (old and -2 or -1))
    Point(
        overlay.Status,
        "TOPLEFT",
        frame,
        "TOPLEFT",
        vehicle and -3 or (old and 1 or -1),
        vehicle and 3 or (old and -2 or -1)
    )
    local width = vehicle and 67 or (healthOnly and 74 or (not old and character and 71 or 70))
    Point(
        container,
        "TOPLEFT",
        frame,
        "TOPLEFT",
        vehicle and 48 or (healthOnly and 43 or (old and 45 or 47)),
        vehicle and (old and -18 or -29) or (healthOnly and -16 or (not old and not character and -20 or -19)),
        width,
        healthOnly and 30 or 10
    )
    module:Edit(container.HealthBar, { width = width, height = healthOnly and 30 or 10 })
    Point(
        container.HealthBarMask,
        "TOPLEFT",
        container,
        "TOPLEFT",
        vehicle and (old and -30 or 16) or (healthOnly and -27 or (old and -29 or (character and -25 or -28))),
        vehicle and not old and -25 or (healthOnly and 4 or 3)
    )
    Point(
        mana,
        "TOPLEFT",
        frame,
        "TOPLEFT",
        vehicle and 45 or (character and (old and 46 or 47) or (old and 41 or 44)),
        vehicle and -29 or (old and -30 or -31),
        vehicle and 70 or (character and (old and 69 or 70) or 74),
        7
    )
    Point(
        mana.ManaBarMask,
        "TOPLEFT",
        frame,
        "TOPLEFT",
        vehicle and 16 or (character and (old and 17 or 19) or (old and 14 or 16)),
        character and -28 or (vehicle and -25 or -26),
        character and 128 or nil,
        character and 9 or nil
    )
    if module:CheckPaths(frame, "Party temporary health loss", { "HealthBarContainer.TempMaxHealthLoss" }) then
        module:Bar(
            container.TempMaxHealthLoss,
            P .. (character and "CharacterFrameOnParty-PortraitOn" or "Player-PortraitOn") .. "-Bar-TempHPLoss"
        )
    end
    -- Party pets are separate named buttons, never traversed as generic children.
    if module:CheckPaths(frame, "Party pet", { "PetFrame.Texture", "PetFrame.Flash", "PetFrame.HealthBar" }) then
        module:Art(frame.PetFrame.Texture, P .. "Party-PortraitOn", true)
        module:Art(frame.PetFrame.Flash, P .. "Party-PortraitOn-InCombat", true)
        module:Bar(frame.PetFrame.HealthBar, P .. "Party-PortraitOn-Bar-Health")
    end
end

function module:RepairTargets(roots)
    for _, frame in ipairs(roots) do
        if
            self:CheckRegion(frame, "combat target root")
            and self:Readable(frame.TargetFrameContent)
            and frame.TargetFrameContent
        then
            Target(frame, true)
        end
    end
end

function module:ApplyGeometry(roots, legacy)
    for _, frame in ipairs(roots) do
        if self:CheckRegion(frame, "layout root") then
            if frame == PlayerFrame then
                Player(frame, legacy)
            elseif frame == PetFrame then
                Small(frame, true, legacy)
            elseif frame == TargetFrameToT or frame == FocusFrameToT then
                Small(frame, false, legacy)
            elseif self:Readable(frame.TargetFrameContent) and frame.TargetFrameContent then
                Target(frame, legacy)
            elseif self:Readable(frame.PartyMemberOverlay) and frame.PartyMemberOverlay then
                Party(frame, legacy)
            end
        end
    end
    if ComboFrame and self:CheckPaths(TargetFrame, "Combo", { "TargetFrameContainer.Portrait" }) then
        Point(ComboFrame, "CENTER", TargetFrame.TargetFrameContainer.Portrait, "CENTER", legacy and 0 or 2, 2)
    end
end

-- The Legacy layout's circle behind a PvP icon, once it was created.
---@param icon Texture
---@return Texture?
function module:PvPBackground(icon)
    return backgrounds[icon]
end

function module:HideLegacyBackgrounds()
    for _, background in pairs(backgrounds) do
        background:Hide()
    end
end
