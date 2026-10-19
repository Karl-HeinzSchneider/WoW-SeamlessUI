---@type string, SeamlessUI
local _, app = ...

---@type SeamlessCore.Addon
app.core = LibStub("AceAddon-3.0"):GetAddon("Seamless")
app.logger = app.core.logger
