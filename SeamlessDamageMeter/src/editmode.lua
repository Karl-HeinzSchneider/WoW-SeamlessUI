---@type string, SeamlessDamageMeter
local _, app = ...

local lib = LibStub("EditModeExpanded-1.0")
local SCALE_SETTING = 16 -- EditModeExpanded's FrameSize setting.

function app:IsEditingWindows()
    return EditModeManagerFrame and EditModeManagerFrame.editModeActive and not InCombatLockdown()
end

local function CurrentLayout(db)
    local layout = EditModeManagerFrame:GetActiveLayoutInfo()
    if not layout then
        return db
    end
    local key = layout.layoutType .. "-" .. layout.layoutName
    if layout.layoutType == Enum.EditModeLayoutType.Character then
        local name, realm = UnitFullName("player")
        if name and realm then
            key = layout.layoutType .. "-" .. name .. "-" .. realm .. "-" .. layout.layoutName
        end
    end
    db.profiles = db.profiles or {}
    db.profiles[key] = db.profiles[key] or { settings = {} }
    return db.profiles[key]
end

function app:SyncWindowEditMode(frame)
    if InCombatLockdown() or not EditModeManagerFrame then
        return
    end
    frame.syncingEditMode = true
    local config = frame.config
    config.editMode = config.editMode or { settings = {} }
    if not lib:IsRegistered(frame) then
        lib:RegisterFrame(frame, "Seamless Damage " .. frame.windowID, config.editMode)
        lib:RegisterResizable(frame, 50, 200, 5)
        lib:SetDontResize(frame) -- Keep collapsed headers at their actual height.
        hooksecurefunc(frame, "SetPoint", function()
            if
                frame.config
                and not InCombatLockdown()
                and not frame.positioning
                and not frame.syncingEditMode
                and not frame.applyingLayout
            then
                app:SaveWindowPosition(frame, true)
                app.core:RefreshOptions("SeamlessDamageMeter")
            end
        end)
        hooksecurefunc(frame, "SetScaleOverride", function()
            if frame.config and not InCombatLockdown() and not frame.syncingEditMode then
                if frame:GetScale() ~= app:GetWindowSetting(frame.config, "scale") then
                    frame.config.overrides.scale = frame:GetScale()
                end
                app:SaveWindowPosition(frame, true)
                app.core:RefreshOptions("SeamlessDamageMeter")
            end
        end)
        if not app.editModeHooked then
            app.editModeHooked = true
            hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
                if not InCombatLockdown() then
                    app:RebuildWindows()
                end
            end)
        end
    end
    -- RegisterFrame does not rebind an already registered frame. These exposed library
    -- tables (EME minor 121) let pooled frames follow AceDB profile switches/resets.
    lib.baseFramesDB[frame.system] = config.editMode
    frame:SetScale(self:GetWindowSetting(config, "scale"))
    self:PositionWindow(frame)
    local db = CurrentLayout(config.editMode)
    lib.framesDB[frame.system] = db
    -- Seed new layouts and reset previews when a slot is activated/deactivated.
    -- Otherwise preserve the player's Expanded checkbox choice for this layout.
    if config.editMode.windowEnabled ~= config.enabled then
        for _, layout in pairs(config.editMode.profiles or {}) do
            layout.enabled = config.enabled
        end
        db.enabled = config.enabled
        config.editMode.windowEnabled = config.enabled
    end
    config.editMode.enabled = config.enabled
    frame.EMEdisabledByDefault = not config.enabled
    db.settings = db.settings or {}
    db.x, db.y = frame:GetRect()
    db.defaultX, db.defaultY = db.x, db.y
    db.defaultScale = frame:GetScale()
    db.settings[SCALE_SETTING] = frame:GetScale() * 100
    if db.enabled == nil then
        db.enabled = config.enabled
    end
    if db.clamped == nil then
        db.clamped = 1
    end
    frame.EMECheckButtonFrame:SetChecked(db.enabled)
    -- EME moves with matching anchor points; retain our independent anchor points by
    -- converting its resulting screen position back to the meter's X/Y overrides.
    frame.EMEanchorTo, frame.EMEanchorPoint = frame.anchorTarget or UIParent, "BOTTOMLEFT"
    frame.syncingEditMode = nil
    if not self:IsEditingWindows() then
        frame:SetMovable(true)
    end
end

function app:WindowShouldBeShown(frame)
    if self:IsEditingWindows() and lib:IsRegistered(frame) then
        return lib:IsFrameEnabled(frame)
    end
    return self.addon:IsEnabled() and frame.config.enabled and not frame.config.hidden
end
