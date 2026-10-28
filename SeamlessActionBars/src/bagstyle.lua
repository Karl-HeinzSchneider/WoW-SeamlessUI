---@type string, SeamlessActionBars
local _, app = ...

-- This module stays disabled until the profile explicitly opts in. No native hooks,
-- events, masks or frame mutations are installed by loading the file.
local module = app.addon:NewModule("BagStyle")
module:SetEnabledState(false)
local active, installed, changing = false, false, false
local buttons, hooked, masks = {}, {}, {}
local barState
local events

local function points(region)
    local result = {}
    for index = 1, region:GetNumPoints() do
        result[index] = { region:GetPoint(index) }
    end
    return result
end

local function setPoints(region, anchors)
    region:ClearAllPoints()
    for _, anchor in ipairs(anchors) do
        region:SetPoint(unpack(anchor))
    end
end

local function capture(region)
    return {
        points = points(region),
        width = region:GetWidth(),
        height = region:GetHeight(),
        alpha = region:GetAlpha(),
    }
end

local function restore(region, state)
    region:SetSize(state.width, state.height)
    setPoints(region, state.points)
    region:SetAlpha(state.alpha)
end

local function textures(button)
    return {
        button:GetNormalTexture(),
        button:GetPushedTexture(),
        button:GetHighlightTexture(),
        button.SlotHighlightTexture,
    }
end

local function captureTextures(button, state)
    state.textures = {}
    for _, texture in ipairs(textures(button)) do
        local saved = capture(texture)
        saved.atlas = texture:GetAtlas()
        saved.texture = texture:GetTexture()
        saved.coords = { texture:GetTexCoord() }
        saved.rotation = texture:GetRotation()
        state.textures[texture] = saved
    end
end

local function skin(button)
    local backpack = button == MainMenuBarBackpackButton
    local reagent = button == CharacterReagentBag0Slot
    local keyring = button == KeyRingButton
    local equipped = backpack or keyring or GetInventoryItemTexture("player", button:GetID()) ~= nil
    local border = backpack and "bag-main"
        or reagent and (equipped and "bag-reagent-border" or "bag-reagent-border-empty")
        or (equipped and "bag-border" or "bag-border-empty")
    local highlight = backpack and "bag-main-highlight" or "bag-border-highlight"
    for index, texture in ipairs(textures(button)) do
        texture:ClearAllPoints()
        texture:SetAllPoints(button)
        texture:SetAtlas(index <= 2 and border or highlight)
        texture:SetRotation(0)
    end
    button:SetSize(backpack and 48 or 30, backpack and 48 or 30)
    if backpack then
        button.icon:SetAlpha(0)
    else
        button.icon:ClearAllPoints()
        button.icon:SetAllPoints(button)
        if keyring then
            button.icon:SetTexture("Interface\\Icons\\ui-hud-actionbar-keyring")
            button.icon:SetTexCoord(0, 1, 0, 1)
        end
    end
end

local function prepare(button)
    if buttons[button] then
        return
    end
    local state = capture(button)
    state.shown = button:IsShown()
    state.icon = capture(button.icon)
    state.icon.texture = button.icon:GetTexture()
    state.icon.atlas = button.icon:GetAtlas()
    state.icon.coords = { button.icon:GetTexCoord() }
    state.masked = {}
    buttons[button] = state
    captureTextures(button, state)
    if button ~= MainMenuBarBackpackButton then
        local mask = masks[button]
        if not mask then
            mask = button:CreateMaskTexture()
            mask:SetTexture(
                "Interface\\CharacterFrame\\TempPortraitAlphaMask",
                "CLAMPTOBLACKADDITIVE",
                "CLAMPTOBLACKADDITIVE"
            )
            mask:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
            mask:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
            masks[button] = mask
        end
        for _, key in ipairs({ "icon", "searchOverlay", "ItemContextOverlay" }) do
            local texture = button[key]
            if texture then
                if button.SquareMask then
                    -- Only remove a mask when this texture actually owns it.
                    for index = 1, texture:GetNumMaskTextures() do
                        if texture:GetMaskTexture(index) == button.SquareMask then
                            state.masked[texture] = true
                            texture:RemoveMaskTexture(button.SquareMask)
                            break
                        end
                    end
                end
                texture:AddMaskTexture(mask)
            end
        end
    end
    if not hooked[button] then
        hooked[button] = true
        hooksecurefunc(button, "UpdateTextures", function()
            if active and buttons[button] and (not InCombatLockdown() or not button:IsProtected()) then
                captureTextures(button, buttons[button])
                if button == KeyRingButton and (button.bagAtlas or button.bagIcon) then
                    buttons[button].icon.texture = button.icon:GetTexture()
                    buttons[button].icon.atlas = button.icon:GetAtlas()
                    buttons[button].icon.coords = { button.icon:GetTexCoord() }
                end
                skin(button)
            end
        end)
    end
end

local function hideDividers()
    if not active then
        return
    end
    for _, pool in ipairs({ BagsBar.HorizontalDividersPool, BagsBar.VerticalDividersPool }) do
        for divider in pool:EnumerateActive() do
            divider:Hide()
        end
    end
end

local function layout()
    if not active or changing or not BagsBar or not MainMenuBarBagManager then
        return
    end
    local combat = InCombatLockdown()
    if combat then
        -- Existing bag buttons are ordinary, unprotected ItemButtons. Keep their
        -- skin/layout synchronized with native combat-time expand changes, but
        -- never initialize a skin or modify protected frames during combat.
        if not barState or BagsBar:IsProtected() or (BagBarExpandToggle and BagBarExpandToggle:IsProtected()) then
            return
        end
        for _, button in MainMenuBarBagManager:EnumerateBagButtons() do
            if not buttons[button] or button:IsProtected() then
                return
            end
        end
    end
    changing = true
    local bar = BagsBar
    if not barState then
        barState = {
            borderAlpha = bar.BorderArt and bar.BorderArt:GetAlpha(),
            hideExpandToggle = bar.hideExpandToggle,
            arrowWidth = bar.bagBarExpandToggleInitialWidth,
            arrowHeight = bar.bagBarExpandToggleInitialHeight,
        }
        if BagBarExpandToggle then
            barState.arrow = capture(BagBarExpandToggle)
            barState.arrow.parent = BagBarExpandToggle:GetParent()
            barState.arrow.shown = BagBarExpandToggle:IsShown()
            -- The native arrow lives inside the collapsible small-bag cluster.
            -- Keep it outside that cluster so it remains available to expand again.
            BagBarExpandToggle:SetParent(bar)
        end
    end
    -- Enable the client's existing expand button and manager, rather than replacing
    -- their click/drag/keybinding handlers. Restore this capability on disable.
    if not combat then
        bar.hideExpandToggle = false
        -- Forever initializes these to zero while its native toggle is hidden. The
        -- native Layout callback also runs through a reference captured before our
        -- hook, so it must have valid dimensions even when our combat guard defers.
        bar.bagBarExpandToggleInitialWidth = 10
        bar.bagBarExpandToggleInitialHeight = 16
    end
    local spacing = app.db.profile.bags.spacing
    local visible, fullLength, count = {}, 0, 0
    for _, button in MainMenuBarBagManager:EnumerateBagButtons() do
        prepare(button)
        skin(button)
        fullLength = fullLength
            + (bar:IsHorizontal() and button:GetWidth() or button:GetHeight())
            + (count > 0 and spacing or 0)
        count = count + 1
        if button:IsShown() then
            visible[#visible + 1] = button
        end
    end
    if bar.BorderArt then
        bar.BorderArt:SetAlpha(0)
    end
    hideDividers()
    local horizontal = bar:IsHorizontal()
    local reverse = horizontal and bar:IsDirectionLeft() or not horizontal and bar:IsDirectionUp()
    local point = horizontal and (reverse and "RIGHT" or "LEFT") or (reverse and "BOTTOM" or "TOP")
    local relativePoint = horizontal and (reverse and "LEFT" or "RIGHT") or (reverse and "TOP" or "BOTTOM")
    local offset = reverse and -spacing or spacing
    local previous = bar
    for _, button in ipairs(visible) do
        button:ClearAllPoints()
        button:SetPoint(
            point,
            previous,
            previous == bar and point or relativePoint,
            previous ~= bar and horizontal and offset or 0,
            previous ~= bar and not horizontal and -offset or 0
        )
        previous = button
        if button == MainMenuBarBackpackButton and BagBarExpandToggle then
            local arrow = BagBarExpandToggle
            arrow:SetSize(horizontal and 10 or 16, horizontal and 16 or 10)
            arrow:ClearAllPoints()
            arrow:SetPoint(point, button, relativePoint)
            arrow:Show()
            arrow:UpdateOrientation()
            previous = arrow
        end
    end
    -- Keep the expanded footprint even while individual bags are hidden. Changing
    -- its length moves the backpack edge when the native bar is center-anchored.
    fullLength = fullLength + (BagBarExpandToggle and 10 or 0)
    bar:SetSize(horizontal and fullLength or 48, horizontal and 48 or fullLength)
    changing = false
end

local function restoreStyle()
    active = false
    if not barState then
        return
    end
    for button, state in pairs(buttons) do
        restore(button, state)
        button:SetShown(state.shown)
        restore(button.icon, state.icon)
        if button == KeyRingButton then
            if state.icon.atlas then
                button.icon:SetAtlas(state.icon.atlas)
            else
                button.icon:SetTexture(state.icon.texture)
            end
            button.icon:SetTexCoord(unpack(state.icon.coords))
        end
        for _, key in ipairs({ "icon", "searchOverlay", "ItemContextOverlay" }) do
            local texture = button[key]
            if texture and masks[button] then
                texture:RemoveMaskTexture(masks[button])
                if state.masked[texture] then
                    texture:AddMaskTexture(button.SquareMask)
                end
            end
        end
        for texture, saved in pairs(state.textures) do
            if saved.atlas then
                texture:SetAtlas(saved.atlas)
            else
                texture:SetTexture(saved.texture)
            end
            texture:SetTexCoord(unpack(saved.coords))
            texture:SetRotation(saved.rotation)
            restore(texture, saved)
        end
    end
    if BagsBar.BorderArt then
        BagsBar.BorderArt:SetAlpha(barState.borderAlpha)
    end
    BagsBar.hideExpandToggle = barState.hideExpandToggle
    BagsBar.bagBarExpandToggleInitialWidth = barState.arrowWidth
    BagsBar.bagBarExpandToggleInitialHeight = barState.arrowHeight
    if barState.arrow then
        BagBarExpandToggle:SetParent(barState.arrow.parent)
        restore(BagBarExpandToggle, barState.arrow)
        BagBarExpandToggle:SetShown(barState.arrow.shown)
    end
    wipe(buttons)
    barState = nil
    BagsBar:Layout()
end

function module:Refresh()
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local enabled = self:IsEnabled() and app.addon:IsEnabled() and app.db.profile.bags.retailStyle
    if not enabled then
        restoreStyle()
        events:UnregisterAllEvents()
        return
    end
    active = true
    if BagsBar and MainMenuBarBagManager and not installed then
        installed = true
        hooksecurefunc(BagsBar, "Layout", layout)
        -- Saved native Layout callbacks bypass our Layout hook but still call this method.
        hooksecurefunc(BagsBar, "UpdateDividers", hideDividers)
        -- OnLoad registered the original Layout function with EventRegistry.
        -- Hooking the table method cannot intercept that saved function. Run
        -- after the manager finishes dispatching the complete expand change.
        hooksecurefunc(MainMenuBarBagManager, "OnExpandBarChanged", layout)
        -- Only the user's toggle owns the preference. Native initialization and
        -- cursor auto-expansion must never overwrite the saved profile value.
        hooksecurefunc(MainMenuBarBagManager, "ToggleExpandBar", function()
            if active and self:IsEnabled() and app.db.profile.bags.retailStyle then
                app.db.profile.bags.expanded = GetCVarBool("expandBagBar")
            end
        end)
    end
    layout()
    if MainMenuBarBagManager and GetCVarBool("expandBagBar") ~= app.db.profile.bags.expanded then
        -- Keep the native CVar in sync too: the existing arrow toggles that CVar.
        SetCVar("expandBagBar", app.db.profile.bags.expanded)
    end
    if MainMenuBarBagManager then
        local expanded = app.db.profile.bags.expanded
        if MainMenuBarBagManager:IsBarUserExpanded() ~= expanded then
            MainMenuBarBagManager:SetExpandBar(expanded)
        else
            -- A matching CVar/manager value does not mean the buttons have been
            -- hidden: Forever skipped that work while hideExpandToggle was true.
            MainMenuBarBagManager:OnExpandBarChanged()
        end
    end
end

function module:OnEnable()
    if not events then
        -- Independent of AceEvent teardown: a disable during combat must still
        -- restore the native frames after combat ends.
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", function()
            module:Refresh()
        end)
    end
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:Refresh()
end

function module:OnDisable()
    self:Refresh()
end

function app.RefreshBagStyle()
    if app.addon:IsEnabled() and app.db.profile.bags.retailStyle then
        if module:IsEnabled() then
            module:Refresh()
        else
            module:Enable()
        end
    elseif module:IsEnabled() then
        module:Disable()
    end
end
