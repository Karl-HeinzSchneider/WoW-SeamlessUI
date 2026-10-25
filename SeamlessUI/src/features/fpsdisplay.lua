---@type string, SeamlessUI
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessUI.FPSDisplay : AceModule
local module = app.addon:NewModule("FPSDisplay") --[[@as SeamlessUI.FPSDisplay]]
app.fpsDisplay = module

local lib = app.core:GetEditModeLibrary()
local anchor
local originalPoints
local showAnchor = true
local visibilityBeforeEditMode
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

-- The native counter formats "%.1f" itself (Blizzard_FramerateFrame); rewrite it right after.
-- Its Layout() runs after this hook, so the counter still resizes to the rounded text.
local function HookNativeFramerate()
    local text = FramerateFrame.FramerateText or FramerateText
    if not text then
        return
    end
    hooksecurefunc(text, "SetFormattedText", function(self)
        if module:IsEnabled() and app.db.profile.fpsDisplay.roundFramerate then
            local rounded = (self:GetText() or ""):gsub("%d+%.%d+", function(value)
                return tostring(math.floor(tonumber(value) + 0.5))
            end, 1)
            self:SetText(rounded)
        end
    end)
end

-- With latency on, the native counter is faded out and this two-row display takes its place:
-- labels left, values right-aligned, sized once for "999.9" so it never resizes. Kept out of
-- the counter's children, since the counter sizes itself to fit them. Follows the counter's
-- visibility (Ctrl+R) through script hooks; OnUpdate only runs while shown.
local function RefreshDisplay()
    local shown = module:IsEnabled() and app.db.profile.fpsDisplay.showLatency and FramerateFrame:IsShown()
    display:SetShown(shown)
    FramerateFrame:SetAlpha(shown and 0 or 1)
    if shown then
        -- The anchor lives in UIParent's scale, the display in WorldFrame's.
        local scale = display:GetEffectiveScale() / anchor:GetEffectiveScale()
        anchor:SetSize(display:GetWidth() * scale, display:GetHeight() * scale)
    else
        anchor:SetSize(120, 24)
    end
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
    display:SetSize(math.ceil(labelWidth + 4 + valueWidth), math.ceil(rowHeight * 2 + ROW_GAP))
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
    FramerateFrame:HookScript("OnShow", RefreshDisplay)
    FramerateFrame:HookScript("OnHide", RefreshDisplay)
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
    if lib:IsInEditMode() then
        if visibilityBeforeEditMode == nil then
            visibilityBeforeEditMode = FramerateFrame:IsShown()
        end
        FramerateFrame:SetShown(showAnchor or visibilityBeforeEditMode)
    elseif visibilityBeforeEditMode ~= nil then
        FramerateFrame:SetShown(visibilityBeforeEditMode)
        visibilityBeforeEditMode = nil
    end
    RefreshDisplay()
    app.core:RefreshEditModeOptions()
end

function module:OnEnable()
    if not FramerateFrame then
        return
    end
    originalPoints = {}
    for index = 1, FramerateFrame:GetNumPoints() do
        originalPoints[index] = { FramerateFrame:GetPoint(index) }
    end
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
        local settings = {}
        local args = app.optionPages.fpsDisplay.config.args
        for _, key in ipairs({ "startup", "showLatency", "whiteLatency", "roundFramerate" }) do
            local option = args[key]
            settings[#settings + 1] = {
                name = option.name,
                kind = lib.SettingType.Checkbox,
                default = option.default,
                get = option.get,
                set = option.set,
            }
        end

        settings[#settings + 1] = app.core:GetEditModePositionSetting(module:GetPositionBinding())
        settings[#settings + 1] = app.optionPages.fpsDisplay.config.buttonSection
        lib:AddFrameSettings(anchor, settings)
        CreateDisplay()
        HookNativeFramerate()
    end
    FramerateFrame:ClearAllPoints()
    FramerateFrame:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT")
    self:Refresh()
end

function module:OnDisable()
    if visibilityBeforeEditMode ~= nil then
        FramerateFrame:SetShown(visibilityBeforeEditMode)
        visibilityBeforeEditMode = nil
    end
    if anchor then
        anchor:Hide()
        anchor:SetSize(120, 24)
        display:Hide()
        FramerateFrame:SetAlpha(1)
    end
    if originalPoints then
        FramerateFrame:ClearAllPoints()
        for _, point in ipairs(originalPoints) do
            FramerateFrame:SetPoint(unpack(point))
        end
        originalPoints = nil
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
                return showAnchor
            end,
            set = function(value)
                showAnchor = value
                EventRegistry:TriggerEvent("EditModeExternal.hideDialog")
                module:Refresh()
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

function module:SetOption(key, value)
    if key == "startup" then
        app.core.db.profile.tweaks.showFramerateOnStartup = value
        visibilityBeforeEditMode = value
        self:Refresh()
    else
        app.db.profile.fpsDisplay[key] = value
        if key == "showLatency" then
            self:Refresh()
        else
            UpdateDisplay()
        end
    end
    app.core:RefreshOptions("SeamlessUI")
end

function module:GetPositionBinding()
    return {
        get = function(key)
            return CurrentPosition()[key]
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
