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
    display.FramerateText:SetFormattedText("%.1f", math.min(GetFramerate(), 999.9))
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

function module:Refresh()
    if not anchor or not self:IsEnabled() then
        return
    end
    local name = lib:GetActiveLayoutName()
    local position = (name and app.db.profile.fpsDisplay.layouts[name]) or defaults
    anchor:ClearAllPoints()
    anchor:SetPoint(position.point, UIParent, position.point, position.x, position.y)
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
            end
        end, defaults, L["FPS display"])
        lib:AddFrameSettings(anchor, {
            {
                name = L["Show FPS on startup"],
                kind = lib.SettingType.Checkbox,
                default = false,
                get = function()
                    return app.core.db.profile.tweaks.showFramerateOnStartup
                end,
                set = function(_, value)
                    app.core.db.profile.tweaks.showFramerateOnStartup = value
                    visibilityBeforeEditMode = value
                    module:Refresh()
                end,
            },
            {
                name = L["Show latency"],
                kind = lib.SettingType.Checkbox,
                default = false,
                get = function()
                    return app.db.profile.fpsDisplay.showLatency
                end,
                set = function(_, value)
                    app.db.profile.fpsDisplay.showLatency = value
                    module:Refresh()
                end,
            },
            {
                name = L["White latency text"],
                kind = lib.SettingType.Checkbox,
                default = false,
                get = function()
                    return app.db.profile.fpsDisplay.whiteLatency
                end,
                set = function(_, value)
                    app.db.profile.fpsDisplay.whiteLatency = value
                    UpdateDisplay()
                end,
            },
        })
        CreateDisplay()
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
            layouts[name] = { point = source.point, x = source.x, y = source.y }
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
