---@type string, SeamlessUI
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessUI.FPSDisplay : AceModule
local module = app.addon:NewModule("FPSDisplay") --[[@as SeamlessUI.FPSDisplay]]
app.fpsDisplay = module

local lib = app.core:GetEditModeLibrary()
local anchor
local keyboard
local visible = false
local nativeFrame, nativeAlpha
local showAnchor = true

function module:EditModeVisibility(value)
    if value ~= nil then
        showAnchor = value
        EventRegistry:TriggerEvent("EditModeExternal.hideDialog")
        self:Refresh()
    end
    return showAnchor
end
-- FramerateFrame's anchor in Blizzard_FramerateFrame/Mainline/FramerateFrame.xml (the client skips
-- the micro menu override): BOTTOMRIGHT, 2 pixels in from the corner.
local defaults = { point = "BOTTOMRIGHT", x = -2, y = 2 }
local display
local UPDATE_INTERVAL = 0.25
local ROW_GAP = 2
local textColor

local function UpdateDisplay()
    local _, _, _, world = GetNetStats()
    world = math.min(world or 0, 999)
    if app.db.profile.fpsDisplay.whiteLatency then
        display.LatencyText:SetTextColor(unpack(textColor))
    elseif world < 100 then
        display.LatencyText:SetTextColor(0.1, 1, 0.1)
    elseif world < 250 then
        display.LatencyText:SetTextColor(1, 0.82, 0)
    else
        display.LatencyText:SetTextColor(1, 0.1, 0.1)
    end
    display.LatencyText:SetFormattedText("%d", world)
    local framerate = math.min(GetFramerate(), 999.9)
    if app.db.profile.fpsDisplay.roundFramerate then
        display.FramerateText:SetFormattedText("%d", math.floor(framerate + 0.5))
    else
        display.FramerateText:SetFormattedText("%.1f", framerate)
    end
end

-- Opt-in suppression owns only alpha. Native Toggle/benchmark visibility and scripts keep
-- running (Blizzard_FramerateFrame/Mainline/FramerateFrame.lua). Restore only our own value,
-- so an intervening alpha change from another addon is not overwritten.
local function RestoreNativeDisplay()
    if nativeFrame then
        if nativeAlpha ~= 0 and nativeFrame:GetAlpha() == 0 then
            nativeFrame:SetAlpha(nativeAlpha)
        end
        nativeFrame, nativeAlpha = nil, nil
    end
end

local function RefreshNativeDisplay()
    if not module:IsEnabled() or not app.db.profile.fpsDisplay.hideBlizzard then
        RestoreNativeDisplay()
        display:UnregisterEvent("ADDON_LOADED")
        return
    end
    if nativeFrame then
        return
    end
    if FramerateFrame then
        nativeFrame, nativeAlpha = FramerateFrame, FramerateFrame:GetAlpha()
        if nativeAlpha ~= 0 then
            nativeFrame:SetAlpha(0)
        end
        display:UnregisterEvent("ADDON_LOADED")
    else
        display:RegisterEvent("ADDON_LOADED")
    end
end

local function RefreshDisplay()
    local latency = app.db.profile.fpsDisplay.showLatency
    display.LatencyLabel:SetShown(latency)
    display.LatencyText:SetShown(latency)
    display:SetHeight(display.rowHeight * (latency and 2 or 1) + (latency and ROW_GAP or 0))
    local scale = display:GetEffectiveScale() / anchor:GetEffectiveScale()
    anchor:SetSize(display:GetWidth() * scale, display:GetHeight() * scale)
    display:SetShown(module:IsEnabled() and (visible or (lib:IsInEditMode() and showAnchor)))
    UpdateDisplay()
    RefreshNativeDisplay()
end

local function CreateDisplay()
    -- Same parent and font as the native counter (Blizzard_FramerateFrame): WorldFrame is not
    -- affected by the UI scale, so a UIParent child would look smaller than the counter.
    display = CreateFrame("Frame", nil, WorldFrame)
    display:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT")
    local function Text(justify)
        local text = display:CreateFontString(nil, "ARTWORK", "SystemFont_Shadow_Med1")
        text:SetJustifyH(justify)
        return text
    end
    display.FramerateLabel = Text("LEFT")
    display.FramerateLabel:SetText(type(FRAMERATE_LABEL) == "string" and FRAMERATE_LABEL or L["FPS:"])
    display.LatencyLabel = Text("LEFT")
    display.LatencyLabel:SetText(L["MS:"])
    display.FramerateText = Text("RIGHT")
    display.LatencyText = Text("RIGHT")
    display.FramerateText:SetText("999.9")
    textColor = { display.FramerateText:GetTextColor() }
    local labelWidth = math.max(display.FramerateLabel:GetStringWidth(), display.LatencyLabel:GetStringWidth())
    local valueWidth = display.FramerateText:GetStringWidth()
    local rowHeight = display.FramerateText:GetStringHeight()
    display.rowHeight = math.ceil(rowHeight)
    display:SetSize(math.ceil(labelWidth + 4 + valueWidth), display.rowHeight)
    display.FramerateLabel:SetPoint("TOPLEFT")
    display.LatencyLabel:SetPoint("BOTTOMLEFT")
    display.FramerateText:SetPoint("TOPRIGHT")
    display.LatencyText:SetPoint("BOTTOMRIGHT")
    local elapsedTotal = UPDATE_INTERVAL
    display:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal >= UPDATE_INTERVAL then
            elapsedTotal = 0
            UpdateDisplay()
        end
    end)
    display:SetScript("OnShow", UpdateDisplay)
    display:SetScript("OnEvent", RefreshNativeDisplay)
end

-- The active layout's position; dragging stores only point, x and y relative to UIParent.
local function CurrentPosition()
    local name = lib:GetActiveLayoutName()
    local position = (name and app.db.profile.fpsDisplay.layouts[name]) or defaults
    return {
        point = position.point,
        relativePoint = position.relativePoint or position.point,
        relativeTo = position.relativeTo or "UIParent",
        x = position.x,
        y = position.y,
    }
end

local function RelativeFrame(name)
    local frame = _G[name]
    if type(frame) == "table" and frame.IsObjectType and frame:IsObjectType("Frame") then
        for _, entry in ipairs(app.blizzardPosition:GetAnchorFrames(anchor)) do
            if entry.value == name then
                return frame
            end
        end
    end
    return UIParent
end

function module:Refresh()
    if not anchor or not self:IsEnabled() then
        return
    end
    local position = CurrentPosition()
    anchor:ClearAllPoints()
    anchor:SetPoint(position.point, RelativeFrame(position.relativeTo), position.relativePoint, position.x, position.y)
    anchor:SetShown(lib:IsInEditMode() and showAnchor)
    RefreshDisplay()
    app.core:RefreshEditModeOptions()
end

function module:OnEnable()
    if not anchor then
        anchor = CreateFrame("Frame", nil, UIParent)
        anchor:SetSize(120, 24)
        anchor:SetClampedToScreen(true)
        lib:AddFrame(anchor, function(_, layoutName, point, x, y)
            if module:IsEnabled() and layoutName then
                app.db.profile.fpsDisplay.layouts[layoutName] = { point = point, x = x, y = y }
                -- Reset Position does not refresh the dialog itself; keep the Position values current.
                lib:RefreshFrameSettings(anchor)
            end
        end, defaults, L["FPS display"])
        lib:AddFrameSettings(anchor, app.core:GetEditModePageSettings(appName, "fpsDisplay"))
        CreateDisplay()
    end
    if not keyboard then
        -- Bindings_Camelot.xml invokes the native frame directly for TOGGLEFPS. Observe the
        -- assigned keyboard input instead of hooking that frame or replacing its binding.
        -- WorldFrame keeps this listener independent of the counter and UIParent visibility.
        keyboard = CreateFrame("Frame", nil, WorldFrame)
        keyboard:EnableKeyboard(true)
        keyboard:SetPropagateKeyboardInput(true)
        local held = {}
        keyboard:SetScript("OnKeyDown", function(_, key)
            if held[key] then
                return
            end
            held[key] = true
            if
                module:IsEnabled()
                and not GetCurrentKeyBoardFocus()
                and GetBindingAction(GetBindingFullInput(key), true) == "TOGGLEFPS"
            then
                -- A keypress only changes this frame's runtime visibility. Do not route it
                -- through options/Refresh: those also reposition frames and refresh Edit Mode.
                visible = not display:IsShown()
                display:SetShown(visible)
            end
        end)
        keyboard:SetScript("OnKeyUp", function(_, key)
            held[key] = nil
        end)
        keyboard:SetScript("OnHide", function()
            wipe(held)
        end)
    end
    keyboard:Show()
    visible = app.core.db.profile.tweaks.showFramerateOnStartup
    self:Refresh()
end

function module:OnDisable()
    if keyboard then
        keyboard:Hide()
    end
    RestoreNativeDisplay()
    if anchor then
        anchor:Hide()
        display:Hide()
        display:UnregisterEvent("ADDON_LOADED")
    end
    app.core:RefreshEditModeOptions()
end

function module:OnProfileRefresh()
    self:Refresh()
end

app.core:RegisterEditModeOptions("SeamlessUI.FPSDisplay", {
    section = "frames",
    enabled = function()
        return app.db and app.addon:IsEnabled() and module:IsEnabled() and anchor ~= nil
    end,
    options = {
        {
            key = "fpsDisplay",
            type = "toggle",
            name = L["FPS display"],
            get = function()
                return module:EditModeVisibility()
            end,
            set = function(value)
                module:EditModeVisibility(value)
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
lib:RegisterCallback("layout", function()
    module:Refresh()
end)

local function ForEachLayout(callback)
    if app.db then
        for _, profile in pairs(app.db.profiles) do
            if profile.fpsDisplay and profile.fpsDisplay.layouts then
                callback(profile.fpsDisplay.layouts)
            end
        end
    end
end

lib:RegisterCallback("create", function(name, _, sourceName)
    ForEachLayout(function(layouts)
        local source = sourceName and layouts[sourceName]
        if source then
            layouts[name] = {
                point = source.point,
                relativePoint = source.relativePoint,
                relativeTo = source.relativeTo,
                x = source.x,
                y = source.y,
            }
        end
    end)
end)
lib:RegisterCallback("rename", function(oldName, newName)
    ForEachLayout(function(layouts)
        layouts[newName], layouts[oldName] = layouts[oldName], nil
    end)
end)
lib:RegisterCallback("delete", function(name)
    ForEachLayout(function(layouts)
        layouts[name] = nil
    end)
end)

function module:IsDisplayShown()
    return visible
end

function module:SetOption(key, value)
    if key == "startup" then
        app.core.db.profile.tweaks.showFramerateOnStartup = value
        visible = value
    elseif key == "visible" then
        visible = value
    else
        app.db.profile.fpsDisplay[key] = value
    end
    self:Refresh()
    app.core:RefreshOptions("SeamlessUI")
end

function module:GetPositionBinding()
    return {
        get = function(key)
            return CurrentPosition()[key]
        end,
        default = function(key)
            local values = { relativePoint = defaults.point, relativeTo = "UIParent" }
            return values[key] or defaults[key]
        end,
        set = function(key, value)
            local name = lib:GetActiveLayoutName()
            if not name or not module:IsEnabled() then
                return
            end
            local current = CurrentPosition()
            current[key] = value
            app.db.profile.fpsDisplay.layouts[name] = current
            module:Refresh()
        end,
        anchorFrames = function()
            return app.blizzardPosition:GetAnchorFrames(anchor)
        end,
    }
end
