---@type string, SeamlessUI
local appName, app = ...

local lib = app.core:GetEditModeLibrary()

-- NewModule returns a new object (a passed table would only be its prototype); define methods
-- on the module itself so file-level callbacks can use AceModule methods such as IsEnabled.
---@class SeamlessUI.Framerate : AceModule
local module = app.addon:NewModule("Framerate") --[[@as SeamlessUI.Framerate]]
app.framerate = module

-- The client anchors FramerateFrame here (parented to WorldFrame) and never moves it again.
local DEFAULT_POINT, DEFAULT_X, DEFAULT_Y = "BOTTOMRIGHT", -2, 2
local mover
local active = false
local anchored = false
local previewing = false
local shownBeforePreview = false

local function Settings()
    return app.db.profile.framerate
end

local function IsMovable()
    return active and Settings().movable
end

local function RefreshOptions()
    app.core:RefreshOptions(appName)
    app.core:RefreshEditModeOptions()
    if mover then
        lib:RefreshFrameSettings(mover)
    end
end

-- Core owned this toggle under Tweaks before; move each Core profile's value once.
local function MigrateCoreSetting()
    local core = app.core.db
    if not core then
        return
    end
    for name, profile in pairs(core.profiles) do
        local tweaks = profile.tweaks
        if tweaks and tweaks.showFramerateOnStartup ~= nil then
            if tweaks.showFramerateOnStartup then
                local target = app.db.profiles[name] or {}
                app.db.profiles[name] = target
                target.framerate = target.framerate or {}
                target.framerate.showOnStartup = true
            end
            tweaks.showFramerateOnStartup = nil
        end
    end
end

-- The mover lives in UIParent like other Edit Mode systems; FramerateFrame stays in WorldFrame
-- so it remains visible with the interface hidden. Sizes convert between the two scales.
local function FitMover()
    local width, height = FramerateFrame:GetSize()
    local ratio = FramerateFrame:GetEffectiveScale() / mover:GetEffectiveScale()
    -- Only grow: the counter's text width changes constantly and must not shift the anchor.
    mover:SetSize(math.max(mover:GetWidth(), width * ratio, 1), math.max(mover:GetHeight(), height * ratio, 1))
end

local function PositionMover()
    local settings = Settings()
    mover:ClearAllPoints()
    mover:SetPoint(settings.point, UIParent, settings.point, settings.x, settings.y)
end

local function EnsureMover()
    if mover then
        return
    end
    mover = CreateFrame("Frame", nil, UIParent)
    mover:SetClampedToScreen(true)
    mover:Hide()
    FitMover()
    FramerateFrame:HookScript("OnSizeChanged", function()
        FitMover()
    end)
    lib:AddFrame(mover, function(_, _, point, x, y)
        local settings = Settings()
        settings.point, settings.x, settings.y = point, x, y
    end, { point = DEFAULT_POINT, x = DEFAULT_X, y = DEFAULT_Y }, "Framerate")
    lib:AddFrameSettings(mover, {
        {
            name = "Show on startup",
            kind = lib.SettingType.Checkbox,
            default = false,
            get = function()
                return Settings().showOnStartup
            end,
            set = function(_, value)
                Settings().showOnStartup = value
                RefreshOptions()
            end,
        },
    })
end

---Reapply anchoring and the Edit Mode preview from the current profile.
function module:Refresh()
    if IsMovable() then
        EnsureMover()
        PositionMover()
        mover:Show()
        FramerateFrame:ClearAllPoints()
        FramerateFrame:SetPoint("BOTTOMRIGHT", mover, "BOTTOMRIGHT")
        anchored = true
    else
        if mover then
            mover:Hide()
        end
        if anchored then
            FramerateFrame:ClearAllPoints()
            FramerateFrame:SetPoint(DEFAULT_POINT, WorldFrame, DEFAULT_POINT, DEFAULT_X, DEFAULT_Y)
            anchored = false
        end
    end
    -- Show the counter while it can be moved; restore the player's choice afterward.
    local preview = IsMovable() and lib:IsInEditMode()
    if preview and not previewing then
        shownBeforePreview = FramerateFrame:IsShown()
        FramerateFrame:Show()
    elseif previewing and not preview then
        FramerateFrame:SetShown(shownBeforePreview)
    end
    previewing = preview
end

---@param key "movable"|"showOnStartup"
---@param value boolean
function module:Set(key, value)
    Settings()[key] = value
    if key == "movable" and not value then
        EventRegistry:TriggerEvent("EditModeExternal.hideDialog")
    end
    self:Refresh()
    RefreshOptions()
end

function module:OnInitialize()
    MigrateCoreSetting()
end

function module:OnEnable()
    active = true
    self:Refresh()
    -- Apply only at startup so normal framerate keybinds remain in control afterward.
    if Settings().showOnStartup then
        FramerateFrame:Show()
    end
end

function module:OnDisable()
    active = false
    self:Refresh()
end

function module:OnProfileRefresh()
    self:Refresh()
    RefreshOptions()
end

app.core:RegisterEditModeOptions(appName, {
    order = 50,
    enabled = function()
        return app.db and module:IsEnabled()
    end,
    options = {
        {
            key = "movable",
            type = "toggle",
            name = "FPS Display",
            get = function()
                return Settings().movable
            end,
            set = function(value)
                module:Set("movable", value)
            end,
        },
    },
})

lib:RegisterCallback("enter", function()
    module:Refresh()
end)
lib:RegisterCallback("exit", function()
    module:Refresh()
end)
