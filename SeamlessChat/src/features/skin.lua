---@type string, SeamlessChat
local _, app = ...

-- A flatter look for the chat tabs and the chat buttons, made to sit with the default UI: the
-- tabs' art is faded out (alpha 0, never hidden, so the game's own Show/Hide calls stay harmless)
-- and replaced by a dark plate with a thin accent line under the selected tab; the buttons next to
-- the chat get the same dark plate behind their own icons. Nothing is saved on the game's frames,
-- and disabling puts the art back.
---@class SeamlessChat.Skin : SeamlessChat.Feature
local module = {}

---@class SeamlessChat.SkinSettings : SeamlessChat.FeatureSettings
local defaults = {
    enabled = true,
    accent = { r = 1, g = 0.82, b = 0 }, -- the game's gold
}

app.features:New(
    "skin",
    module,
    "Tabs and buttons",
    "A flatter, darker look for the chat tabs and the buttons beside the chat, with an accent line under the selected tab.",
    defaults
)

local PLATE = { 0.04, 0.04, 0.05, 0.72 }
local PLATE_HOVER = { 0.12, 0.12, 0.14, 0.85 }
local PLATE_SELECTED = { 0.08, 0.08, 0.09, 0.9 }
local EDGE = { 0.32, 0.32, 0.34, 0.55 }
local TAB_HEIGHT = 20

-- The Blizzard buttons beside the chat, by global name; missing ones are skipped.
local BUTTON_NAMES = {
    "ChatFrameMenuButton",
    "ChatFrameChannelButton",
    "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton",
    "SeamlessChatLogButton",
}

---@class SeamlessChat.SkinParts
---@field edge Texture
---@field fill Texture
---@field accent Texture?
---@field faded Texture[] the frame's own textures, faded out while skinned

---@type table<Frame, SeamlessChat.SkinParts>
local skinned = {}

---@return SeamlessChat.SkinSettings
function module:Settings()
    return self:GetSettings() --[[@as SeamlessChat.SkinSettings]]
end

-- A 1 px edge with a fill inside it, behind everything else on `frame`.
local function makePlate(frame)
    local edge = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetColorTexture(unpack(EDGE))
    local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    fill:SetColorTexture(unpack(PLATE))
    fill:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
    return edge, fill
end

-- `frame`'s own textures, except the ones listed in `keep`.
local function ownTextures(frame, keep)
    local textures = {}
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") and not keep[region] then
            textures[#textures + 1] = region
        end
    end
    return textures
end

local function setFaded(parts, faded)
    for _, texture in ipairs(parts.faded) do
        texture:SetAlpha(faded and 0 or 1)
    end
    parts.edge:SetShown(faded)
    parts.fill:SetShown(faded)
    if parts.accent then
        parts.accent:SetShown(false)
    end
end

-- Tabs -------------------------------------------------------------------------------------------

local function isSelected(tab)
    local chatFrame = _G["ChatFrame" .. tab:GetID()]
    if not chatFrame then
        return false
    end
    if chatFrame.isDocked and GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow then
        return FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) == chatFrame
    end
    return chatFrame:IsShown()
end

function module:PaintTab(tab, hover)
    local parts = skinned[tab]
    if not parts or not self:IsEnabled() then
        return
    end
    local selected = isSelected(tab)
    local color = hover and PLATE_HOVER or selected and PLATE_SELECTED or PLATE
    parts.fill:SetColorTexture(unpack(color))
    local accent = self:Settings().accent
    parts.accent:SetColorTexture(accent.r, accent.g, accent.b, 1)
    parts.accent:SetShown(selected)
end

function module:SkinTab(tab)
    local parts = skinned[tab]
    if not parts then
        -- The new-message flash (glow) stays: it says where unread lines are.
        local keep = {}
        if tab.glow then
            keep[tab.glow] = true
        end
        local faded = ownTextures(tab, keep)
        local edge, fill = makePlate(tab)
        edge:SetPoint("LEFT", tab, "LEFT", 2, 0)
        edge:SetPoint("RIGHT", tab, "RIGHT", -2, 0)
        edge:SetHeight(TAB_HEIGHT)
        local text = tab.Text or _G[tab:GetName() .. "Text"]
        if text then
            edge:SetPoint("TOP", text, "CENTER", 0, TAB_HEIGHT / 2)
        else
            edge:SetPoint("BOTTOM", tab, "BOTTOM", 0, 2)
        end
        local accent = tab:CreateTexture(nil, "BACKGROUND", nil, -6)
        accent:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT")
        accent:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
        accent:SetHeight(2)
        parts = { edge = edge, fill = fill, accent = accent, faded = faded }
        skinned[tab] = parts
        tab:HookScript("OnEnter", function()
            self:PaintTab(tab, true)
        end)
        tab:HookScript("OnLeave", function()
            self:PaintTab(tab, false)
        end)
    end
    setFaded(parts, true)
    self:PaintTab(tab, tab:IsMouseOver())
end

-- Buttons ----------------------------------------------------------------------------------------

function module:SkinButton(button)
    local parts = skinned[button]
    if not parts then
        local edge, fill = makePlate(button)
        edge:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        edge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        parts = { edge = edge, fill = fill, faded = {} }
        skinned[button] = parts
        button:HookScript("OnEnter", function()
            if self:IsEnabled() then
                local accent = self:Settings().accent
                edge:SetColorTexture(accent.r, accent.g, accent.b, 0.8)
            end
        end)
        button:HookScript("OnLeave", function()
            edge:SetColorTexture(unpack(EDGE))
        end)
    end
    setFaded(parts, true)
end

-- The strip of buttons left of a chat window: its own background goes, its buttons get plates.
function module:SkinButtonFrame(buttonFrame)
    local parts = skinned[buttonFrame]
    if not parts then
        local edge, fill = makePlate(buttonFrame)
        parts = { edge = edge, fill = fill, faded = ownTextures(buttonFrame, { [edge] = true, [fill] = true }) }
        skinned[buttonFrame] = parts
    end
    setFaded(parts, true)
    parts.edge:Hide()
    parts.fill:Hide()
    for _, child in ipairs({ buttonFrame:GetChildren() }) do
        if child:IsObjectType("Button") then
            self:SkinButton(child)
        end
    end
end

-- Everything --------------------------------------------------------------------------------------

function module:Refresh()
    if not self:IsEnabled() then
        return
    end
    for _, name in ipairs(CHAT_FRAMES) do
        local tab = _G[name .. "Tab"]
        if tab then
            self:SkinTab(tab)
        end
        local buttonFrame = _G[name .. "ButtonFrame"]
        if buttonFrame then
            self:SkinButtonFrame(buttonFrame)
        end
    end
    for _, name in ipairs(BUTTON_NAMES) do
        local button = _G[name]
        if button then
            self:SkinButton(button)
        end
    end
end

function module:RepaintTabs()
    if not self:IsEnabled() then
        return
    end
    for frame, parts in pairs(skinned) do
        if parts.accent then -- only tabs have one
            self:PaintTab(frame, frame:IsMouseOver())
        end
    end
end

function module:OnInitialize()
    -- New and temporary windows, and every change of the selected tab.
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        self:Refresh()
    end)
    hooksecurefunc("FCF_OpenNewWindow", function()
        self:Refresh()
    end)
    if FCF_DockUpdate then
        hooksecurefunc("FCF_DockUpdate", function()
            self:RepaintTabs()
        end)
    end
    if FCFTab_UpdateColors then
        hooksecurefunc("FCFTab_UpdateColors", function()
            self:RepaintTabs()
        end)
    end
    if FCFDock_SelectWindow then
        hooksecurefunc("FCFDock_SelectWindow", function()
            self:RepaintTabs()
        end)
    end
end

function module:OnEnable()
    self:Refresh()
end

function module:OnDisable()
    for _, parts in pairs(skinned) do
        setFaded(parts, false)
    end
end

function module:GetOptions()
    return {
        accent = {
            type = "color",
            order = 10,
            name = "Accent color",
            desc = "The line under the selected tab and the edge of a button under the mouse.",
            get = function()
                local color = self:Settings().accent
                return color.r, color.g, color.b
            end,
            set = function(_, r, g, b)
                local color = self:Settings().accent
                color.r, color.g, color.b = r, g, b
                self:RepaintTabs()
            end,
        },
    }
end
