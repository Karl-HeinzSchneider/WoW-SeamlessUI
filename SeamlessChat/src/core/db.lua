---@type string, SeamlessChat
local appName, app = ...

app.optionPages = {}
app.dbDefaults = { profile = { features = {} }, char = {}, global = { dbVersion = 1 } }
