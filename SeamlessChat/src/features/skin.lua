---@type string, SeamlessChat
local _, app = ...

-- A flatter look for the buttons beside the chat, made to sit with the default UI: each button gets
-- a dark plate behind its own icon, and the strip behind them has its art faded out (alpha 0, never
-- hidden, so the game's own Show/Hide calls stay harmless). Nothing is saved on the game's frames,
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
    "Chat buttons",
    "A flatter, darker look for the buttons beside the chat.",
    defaults
)

local PLATE = { 0.04, 0.04, 0.05, 0.72 }
local EDGE = { 0.32, 0.32, 0.34, 0.55 }

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

function module:OnInitialize()
    -- New and temporary windows bring their own button strips.
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        self:Refresh()
    end)
    hooksecurefunc("FCF_OpenNewWindow", function()
        self:Refresh()
    end)
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
            desc = "The edge of a button under the mouse.",
            get = function()
                local color = self:Settings().accent
                return color.r, color.g, color.b
            end,
            set = function(_, r, g, b)
                local color = self:Settings().accent
                color.r, color.g, color.b = r, g, b
            end,
        },
    }
end
