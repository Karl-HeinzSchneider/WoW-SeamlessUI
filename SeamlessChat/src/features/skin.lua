---@type string, SeamlessChat
local _, app = ...

-- The button bar left of the main chat window: the game's chat buttons and ours, one style, stacked
-- from the bottom without gaps, in a frame of our own (SeamlessChatButtonBar). The game's own button
-- strip belongs to ChatFrame1 and hides with it whenever another docked tab is selected; ours stays. A button the game hides (voice buttons outside voice chat) or the
-- user switches off leaves no hole; the ones above it move down. Each button gets the same size and
-- a dark plate behind its own icon, and the strips behind the buttons of every chat window have their
-- art hidden (the game only fades those textures, it never shows them again).
-- Disabling puts sizes, places and art back.
---@class SeamlessChat.Skin : SeamlessChat.Feature
---@field bar Frame? SeamlessChatButtonBar
---@field copyButton Button?
---@field optionsButton Button?
local module = { optionsTab = "buttons" }

---@class SeamlessChat.SkinSettings : SeamlessChat.FeatureSettings
local defaults = {
    enabled = true,
    accent = { r = 1, g = 0.82, b = 0 }, -- the game's gold
    -- Which buttons the bar shows, by BUTTONS key (the log button's switch is the log feature's).
    show = {
        social = true,
        channels = true,
        tts = true,
        voiceDeafen = true,
        voiceMute = true,
        copy = true,
        menu = true,
        options = true,
    },
}

-- The running module; `module` is only its prototype, so the buttons it makes live here.
local feature = app.features:New(
    "skin",
    module,
    "Chat buttons",
    "The buttons left of the main chat window in one bar and one style. Hidden buttons leave no gap.",
    defaults
) --[[@as SeamlessChat.Skin]]

local PLATE = { 0.04, 0.04, 0.05, 0.72 }
local EDGE = { 0.32, 0.32, 0.34, 0.55 }
local BUTTON_SIZE = 26
local GAP = 2
local COPY_ICON = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"
-- The game's own settings (gear) button art, as on its damage meter's settings button.
local OPTIONS_ART = {
    normal = "common-dropdown-a-button-settings-shadowless",
    pushed = "common-dropdown-a-button-settings-pressed-shadowless",
    highlight = "common-dropdown-a-button-settings-hover-shadowless",
}

---@class SeamlessChat.BarButton
---@field key string
---@field name string shown in the options
---@field frame fun(): Button?
---@field own boolean? made by this feature, not the game
---@field game boolean? shown and hidden by the game itself (voice chat, text to speech)

-- Top to bottom, as stacked in the bar: from the bottom options, copy, chat log, chat menu, channels,
-- social, then the buttons the game only shows now and then. Buttons the client doesn't have are skipped.
---@type SeamlessChat.BarButton[]
local BUTTONS = {
    {
        key = "tts",
        game = true,
        name = "Text to speech",
        frame = function()
            return TextToSpeechButton
        end,
    },
    {
        key = "voiceDeafen",
        game = true,
        name = "Voice: deafen",
        frame = function()
            return ChatFrameToggleVoiceDeafenButton
        end,
    },
    {
        key = "voiceMute",
        game = true,
        name = "Voice: mute",
        frame = function()
            return ChatFrameToggleVoiceMuteButton
        end,
    },
    {
        key = "social",
        name = "Social",
        frame = function()
            return QuickJoinToastButton
        end,
    },
    {
        key = "channels",
        name = "Channels",
        frame = function()
            return ChatFrameChannelButton
        end,
    },
    {
        key = "menu",
        name = "Chat menu",
        frame = function()
            return ChatFrameMenuButton
        end,
    },
    {
        key = "log",
        name = "Chat log",
        frame = function()
            return SeamlessChatLogButton
        end,
    },
    {
        key = "copy",
        own = true,
        name = "Copy chat",
        frame = function()
            return feature.copyButton
        end,
    },
    {
        key = "options",
        own = true,
        name = "Options",
        frame = function()
            return feature.optionsButton
        end,
    },
}

---@class SeamlessChat.SkinParts
---@field edge Texture
---@field fill Texture
---@field faded Texture[] the frame's own textures, faded out while skinned
---@field hideArt boolean? hide `faded` instead of setting their alpha (the game sets it)

---@type table<Frame, SeamlessChat.SkinParts>
local skinned = {}

---@class SeamlessChat.BarOriginal
---@field parent Frame
---@field width number
---@field height number
---@field points table[]

-- Size and anchors of every bar button before the bar took it over.
---@type table<Frame, SeamlessChat.BarOriginal>
local originals = {}

-- The bar button entry of each frame, once seen.
---@type table<Frame, SeamlessChat.BarButton>
local entryOf = {}

-- Set while the bar moves buttons, so the hooks don't answer our own calls.
local arranging = false

---@return SeamlessChat.SkinSettings
function module:Settings()
    return self:GetSettings() --[[@as SeamlessChat.SkinSettings]]
end

-- Style -------------------------------------------------------------------------------------------

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
        if parts.hideArt then
            texture:SetShown(not faded)
        else
            texture:SetAlpha(faded and 0 or 1)
        end
    end
    parts.edge:SetShown(faded)
    parts.fill:SetShown(faded)
end

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

-- The strip of buttons beside a chat window: its own background goes, its buttons get plates.
function module:SkinButtonFrame(buttonFrame)
    local parts = skinned[buttonFrame]
    if not parts then
        local edge, fill = makePlate(buttonFrame)
        parts = {
            edge = edge,
            fill = fill,
            faded = ownTextures(buttonFrame, { [edge] = true, [fill] = true }),
            hideArt = true,
        }
        skinned[buttonFrame] = parts
    end
    setFaded(parts, true)
    parts.edge:Hide()
    parts.fill:Hide()
    for _, child in ipairs({ buttonFrame:GetChildren() }) do
        if child:IsObjectType("Button") and not entryOf[child] then
            self:SkinButton(child)
        end
    end
end

-- Bar frame -------------------------------------------------------------------------------------

-- Where the game puts the main chat window's button strip, but not a child of the chat window, so it
-- stays while another docked tab is selected. No background of its own.
function module:CreateBar()
    local bar = CreateFrame("Frame", "SeamlessChatButtonBar", UIParent)
    bar:SetFrameStrata("MEDIUM")
    bar:SetSize(BUTTON_SIZE + 3, BUTTON_SIZE)
    local anchor = ChatFrame1.Background or ChatFrame1
    bar:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -3, -3)
    bar:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", -3, 6)
    self.bar = bar
end

-- Our buttons -----------------------------------------------------------------------------------

-- A bar button of our own, made like the log button: the chat buttons' art with an icon on top, or
-- with `art` (normal, pushed, highlight atlases) a button whose art already shows its icon.
function module:CreateBarButton(title, iconFile, onClick, art)
    local button = CreateFrame("Button", nil, self.bar)
    button:SetFrameStrata("MEDIUM")
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    if art then
        button:SetNormalAtlas(art.normal)
        button:SetPushedAtlas(art.pushed)
        button:SetHighlightAtlas(art.highlight)
        return button
    end
    button:SetNormalAtlas("chatframe-button-up")
    button:SetPushedAtlas("chatframe-button-down")
    button:SetHighlightAtlas("chatframe-button-highlight", "ADD")
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(iconFile)
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER")
    -- The icon moves with the pushed art, as on the chat's other buttons.
    button:SetScript("OnMouseDown", function()
        icon:SetPoint("CENTER", -1, -2)
        icon:SetAlpha(0.75)
    end)
    button:SetScript("OnMouseUp", function()
        icon:SetPoint("CENTER", 0, 0)
        icon:SetAlpha(1)
    end)
    return button
end

function module:CreateOwnButtons()
    -- Opens the copy window with the selected chat tab's lines.
    self.copyButton = self:CreateBarButton("Copy chat", COPY_ICON, function()
        local chatFrame = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
        if chatFrame then
            app.copy:OpenWindow(chatFrame)
        end
    end)
    self.optionsButton = self:CreateBarButton("Chat options", nil, function()
        app.options:Open()
    end, OPTIONS_ART)
end

-- Bar ---------------------------------------------------------------------------------------------

-- Whether the user wants `entry` in the bar.
function module:Wanted(entry)
    if entry.key == "log" then
        return true -- shown or hidden by the log feature's own switch
    end
    if entry.key == "copy" then
        return self:Settings().show.copy and app.copy:IsEnabled()
    end
    return self:Settings().show[entry.key] ~= false
end

-- Takes `button` into the bar once: remembers its size and anchors, and keeps it hidden while the
-- user doesn't want it and the bar in order when the game shows or hides it.
function module:Adopt(entry, button)
    if entryOf[button] then
        return
    end
    entryOf[button] = entry
    local width, height = button:GetSize()
    local points = {}
    for i = 1, button:GetNumPoints() do
        points[i] = { button:GetPoint(i) }
    end
    originals[button] = { parent = button:GetParent(), width = width, height = height, points = points }
    button:HookScript("OnShow", function()
        if not arranging and self:IsEnabled() and not self:Wanted(entry) then
            button:Hide() -- OnHide arranges
            return
        end
        self:Arrange()
    end)
    button:HookScript("OnHide", function()
        self:Arrange()
    end)
end

-- Stacks the shown buttons from the bottom of the main chat window's button strip up.
function module:Arrange()
    if arranging or not self:IsEnabled() or not self.bar then
        return
    end
    arranging = true
    local below
    for i = #BUTTONS, 1, -1 do
        local entry = BUTTONS[i]
        local button = entry.frame()
        if button then
            self:Adopt(entry, button)
            if entry.own then
                button:SetShown(self:Wanted(entry))
            elseif not self:Wanted(entry) then
                button:Hide()
            end
            if button:IsShown() then
                if button:GetParent() ~= self.bar then
                    button:SetParent(self.bar)
                end
                button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
                button:ClearAllPoints()
                if below then
                    button:SetPoint("BOTTOM", below, "TOP", 0, GAP)
                else
                    button:SetPoint("BOTTOM", self.bar, "BOTTOM", 0, 0)
                end
                self:SkinButton(button)
                below = button
            end
        end
    end
    arranging = false
end

-- Gives every bar button its own size and place back.
function module:Release()
    arranging = true
    for button, original in pairs(originals) do
        button:SetParent(original.parent)
        button:SetSize(original.width, original.height)
        button:ClearAllPoints()
        for _, point in ipairs(original.points) do
            button:SetPoint(unpack(point))
        end
    end
    if self.copyButton then
        self.copyButton:Hide()
        self.optionsButton:Hide()
    end
    if self.bar then
        self.bar:Hide()
    end
    arranging = false
    -- Buttons hidden by the bar come back; the log button follows its own switch, the game decides
    -- for its own.
    for button, entry in pairs(entryOf) do
        if not entry.own and entry.key ~= "log" and not entry.game then
            button:Show()
        end
    end
    app.chatLog:UpdateButton()
end

-- Everything --------------------------------------------------------------------------------------

function module:Refresh()
    if not self:IsEnabled() then
        return
    end
    if not self.bar then
        self:CreateBar()
    end
    self.bar:Show()
    if not self.copyButton then
        self:CreateOwnButtons()
    end
    self:Arrange()
    for _, name in ipairs(CHAT_FRAMES) do
        local buttonFrame = _G[name .. "ButtonFrame"]
        if buttonFrame then
            self:SkinButtonFrame(buttonFrame)
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
    self:Release()
end

function module:GetOptions()
    local options = {
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
    for i, entry in ipairs(BUTTONS) do
        options["show_" .. entry.key] = {
            type = "toggle",
            order = 20 + i,
            name = entry.name,
            desc = entry.key == "log" and "Same as the Chat log setting of the same name."
                or entry.key == "copy" and "Opens the copy window for the selected chat tab. Needs Copy to be enabled."
                or entry.key == "options" and "Opens the Chat settings."
                or "Show this button in the bar.",
            get = function()
                if entry.key == "log" then
                    return app.chatLog:GetSettings().showButton
                end
                return self:Settings().show[entry.key] ~= false
            end,
            set = function(_, value)
                if entry.key == "log" then
                    app.chatLog:GetSettings().showButton = value
                    app.chatLog:UpdateButton()
                else
                    self:Settings().show[entry.key] = value
                    -- A button switched back on comes back; the game decides for its own.
                    local button = entry.frame()
                    if value and button and not entry.own and not entry.game then
                        button:Show()
                    end
                end
                self:Arrange()
            end,
        }
    end
    return options
end
