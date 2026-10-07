---@type string, SeamlessChat
local _, app = ...

---@type SeamlessCore.Addon
app.core = LibStub("AceAddon-3.0"):GetAddon("SeamlessCore")
app.logger = app.core.logger
