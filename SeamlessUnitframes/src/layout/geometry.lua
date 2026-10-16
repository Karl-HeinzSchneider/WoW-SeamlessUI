---@type string, SeamlessUnitframes
local _, app = ...

local module = app.legacyLayout
local backgrounds = {}

local function Point(region, point, relative, relativePoint, x, y, width, height, justify)
    module:Edit(region, {
        point = { point, relative, relativePoint, x, y },
        width = width,
        height = height,
        justify = justify,
    })
end

local function PvP(icon, parent, relativePoint, x)
    if not icon then
        return
    end
    local background = backgrounds[icon]
    if not background then
        background = parent:CreateTexture(nil, "OVERLAY", nil, relativePoint == "TOPLEFT" and 3 or -1)
        background:SetAtlas("UI-HUD-UnitFrame-SmallCircle", true)
        background:SetScale(0.8)
        background:SetPoint("TOP", parent, relativePoint, x, -50)
        backgrounds[icon] = background
    end
    background:SetShown(icon:IsShown())
    Point(icon, "CENTER", background, "CENTER", 0, 0)
end

local function Player(frame)
    local main = frame.PlayerFrameContent.PlayerFrameContentMain
    local contextual = frame.PlayerFrameContent.PlayerFrameContentContextual
    if contextual and contextual.AttackIcon then
        module:Edit(contextual.AttackIcon, { layer = { "OVERLAY", 2 } })
    end
    local container = main.HealthBarsContainer
    local health = container.HealthBar
    local mana = main.ManaBarArea.ManaBar
    local vehicle = frame.unit == "vehicle"
    local alternate = PlayerFrame_GetAlternatePowerBar()
    local healthOnly = UNIT_FRAME_SHOW_HEALTH_ONLY
    local nameX = vehicle and 96 or 88
    local nameY = -27
    if LOCALE_zhCN or LOCALE_zhTW then
        nameX = vehicle and 92 or 85
        nameY = LOCALE_zhCN and -26 or -27
    end
    Point(PlayerName, "TOPLEFT", PlayerName:GetParent(), "TOPLEFT", nameX, nameY, 96, nil, "LEFT")
    local height = healthOnly and 32 or (vehicle and 20 or 19)
    Point(
        container,
        "TOPLEFT",
        container:GetParent(),
        "TOPLEFT",
        vehicle and 91 or 85,
        vehicle and -40 or -41,
        vehicle and 118 or 124,
        height
    )
    Point(health, "TOPLEFT", container, "TOPLEFT", 0, 0, nil, height)
    Point(
        container.HealthBarMask,
        "TOPLEFT",
        vehicle and container or health,
        "TOPLEFT",
        vehicle and -8 or -2,
        6,
        nil,
        healthOnly and 37 or 31
    )
    Point(mana, "TOPLEFT", mana:GetParent(), "TOPLEFT", vehicle and 91 or 85, -61, vehicle and 118 or 124, 10)
    module:Edit(mana.ManaBarMask, { width = vehicle and 121 or 128 })
    local flash = frame.PlayerFrameContainer.FrameFlash
    local flashAtlas = vehicle and "UI-HUD-UnitFrame-Player-PortraitOn-Vehicle-InCombat"
        or (
            healthOnly and "plunderstorm-ui-hud-unitframe-player-portraiton-incombat"
            or (
                alternate and "UI-HUD-UnitFrame-Player-PortraitOn-ClassResource-InCombat"
                or "UI-HUD-UnitFrame-Player-PortraitOn-InCombat"
            )
        )
    module:Art(flash, flashAtlas, true)
    module:Art(
        main.StatusTexture,
        vehicle and "UI-HUD-UnitFrame-Player-PortraitOn-Vehicle-Status" or "UI-HUD-UnitFrame-Player-PortraitOn-Status",
        true
    )
    if not vehicle and healthOnly then
        module:Art(container.HealthBarMask, "plunderstorm-ui-hud-unitframe-player-portraiton-bar-health-mask")
    end
    local flashX = vehicle and -3.5 or (healthOnly and -1 or (alternate and -2 or -1.5))
    local flashY = (healthOnly or alternate) and 0.5 or 1
    Point(flash, "CENTER", flash:GetParent(), "CENTER", flashX, flashY)
    Point(main.StatusTexture, "TOPLEFT", flash:GetParent(), "TOPLEFT", vehicle and 11 or 18, vehicle and -8 or -14)
    PvP(main.PvpBackgroundIcon, main, "TOPLEFT", 20)
    local background = backgrounds[main.PvpBackgroundIcon]
    if background then
        Point(PlayerPVPTimerText, "RIGHT", background, "LEFT", 2, 0)
    end
end

local function Target(frame)
    local main = frame.TargetFrameContent.TargetFrameContentMain
    local contextual = frame.TargetFrameContent.TargetFrameContentContextual
    local container = main.HealthBarsContainer
    local health = container.HealthBar
    -- Classification may be secret on future clients. Never branch on a secret.
    local classification = UnitClassification(frame.unit)
    local minus = (not canaccessvalue or canaccessvalue(classification)) and classification == "minus"
    local atlasPrefix = minus and "UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Bar-"
        or "UI-HUD-UnitFrame-Target-PortraitOn-Bar-"
    module:Art(health.HealthBarTexture, atlasPrefix .. "Health", true, true)
    module:Art(container.TempMaxHealthLoss.TempMaxHealthLossTexture, atlasPrefix .. "TempHPLoss", true)
    module:Art(container.HealthBarMask, atlasPrefix .. "Health-Mask", true)
    Point(main.Name, "TOPLEFT", main.ReputationColor, "TOPRIGHT", -133, -1, 117, nil, "LEFT")
    Point(main.ReputationColor, "TOPRIGHT", main, "TOPRIGHT", -75, -25)
    Point(
        container,
        "BOTTOMRIGHT",
        frame.TargetFrameContainer,
        "LEFT",
        minus and 148 or 149,
        minus and -1 or -10,
        minus and 125 or 126,
        minus and 12 or 20
    )
    Point(health, "TOPLEFT", container, "TOPLEFT", 0, 0)
    Point(container.HealthBarMask, "TOPLEFT", container, "TOPLEFT", -1, minus and 2 or 6)
    Point(main.ManaBar, "TOPRIGHT", container, "BOTTOMRIGHT", 8, -1, 134)
    Point(main.ManaBar.RightText, "RIGHT", main.ManaBar, "RIGHT", -13, 0)
    Point(frame.TargetFrameContainer.Flash, "CENTER", frame.TargetFrameContainer, "CENTER", 0, 2)
    PvP(contextual.PvpBackgroundIcon, contextual, "TOPRIGHT", -23)
end

local function Small(frame, pet)
    local name = pet and PetName or frame.Name
    local portrait = pet and PetPortrait or frame.Portrait
    local health = pet and PetFrameHealthBar or frame.HealthBar
    local mana = pet and PetFrameManaBar or frame.ManaBar
    Point(name, "TOPLEFT", portrait, "TOPRIGHT", 2, 0, nil, nil, "LEFT")
    if pet then
        Point(health, "BOTTOMLEFT", portrait, "RIGHT", 2, -3.5)
        Point(PetAttackModeTexture, "TOPLEFT", frame, "TOPLEFT", 0, 1)
        Point(PetFrameFlash, "TOPLEFT", frame, "TOPLEFT", 1, 0)
    else
        Point(health, "BOTTOMRIGHT", frame, "RIGHT", -6, -2.5)
    end
    Point(pet and PetFrameHealthBarMask or health.HealthBarMask, "TOPLEFT", health, "TOPLEFT", -29, 3)
    Point(mana, "TOPLEFT", health, "BOTTOMLEFT", -4, -1, 74, 7)
end

local function Party(frame)
    local vehicle = frame.state == "vehicle"
    local character = frame.frameType == "CharacterFrameOn"
    local healthOnly = not vehicle and not character and UNIT_FRAME_SHOW_HEALTH_ONLY
    local container = frame.HealthBarContainer
    local mana = frame.ManaBar
    local nameY = (LOCALE_zhCN or LOCALE_zhTW) and -4 or -6
    Point(frame.Name, "TOPLEFT", frame, "TOPLEFT", vehicle and 49 or 46, nameY, vehicle and 56 or 57)
    Point(frame.PartyMemberOverlay.RoleIcon, "TOPRIGHT", frame.PartyMemberOverlay, "TOPRIGHT", -5, -5)
    Point(frame.Flash, "TOPLEFT", frame, "TOPLEFT", vehicle and -4 or 1, vehicle and 4 or -2)
    Point(frame.PartyMemberOverlay.Status, "TOPLEFT", frame, "TOPLEFT", vehicle and -3 or 1, vehicle and 3 or -2)
    Point(
        container,
        "TOPLEFT",
        frame,
        "TOPLEFT",
        vehicle and 48 or (healthOnly and 43 or 45),
        vehicle and -18 or (healthOnly and -16 or -19),
        vehicle and 67 or (healthOnly and 74 or 70),
        healthOnly and 30 or nil
    )
    module:Edit(container.HealthBar, { height = healthOnly and 30 or (vehicle and nil or 10) })
    Point(
        container.HealthBarMask,
        "TOPLEFT",
        container,
        "TOPLEFT",
        vehicle and -30 or (healthOnly and -27 or -29),
        healthOnly and 4 or 3
    )
    Point(
        mana,
        "TOPLEFT",
        frame,
        "TOPLEFT",
        vehicle and 45 or (character and 46 or 41),
        vehicle and -29 or -30,
        vehicle and 70 or (character and 69 or 74)
    )
    Point(
        mana.ManaBarMask,
        "TOPLEFT",
        frame,
        "TOPLEFT",
        vehicle and 16 or (character and 17 or 14),
        character and -28 or (vehicle and -25 or -26),
        character and 128 or nil,
        character and 9 or nil
    )
end

function module:ApplyGeometry(roots)
    for _, frame in ipairs(roots) do
        if frame == PlayerFrame then
            Player(frame)
        elseif frame.TargetFrameContent then
            Target(frame)
        elseif frame == PetFrame then
            Small(frame, true)
        elseif frame == TargetFrameToT or frame == FocusFrameToT then
            Small(frame, false)
        elseif frame.HealthBarContainer and frame.PartyMemberOverlay then
            Party(frame)
        end
    end
    if ComboFrame and TargetFrame then
        Point(ComboFrame, "CENTER", TargetFrame:GetPortrait(), "CENTER", 0, 2)
    end
end

function module:HideLegacyBackgrounds()
    for _, background in pairs(backgrounds) do
        background:Hide()
    end
end
