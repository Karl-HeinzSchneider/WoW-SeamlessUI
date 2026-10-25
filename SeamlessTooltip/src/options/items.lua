---@type string, SeamlessTooltip
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local media = app.media
local LSM = media.LSM
local itemDetails = app.features:GetModule("ItemDetails")
local itemIDs = app.features:GetModule("ItemIDs")
local itemLevel = app.features:GetModule("ItemLevel")
local qualityBorder = app.features:GetModule("QualityBorder")
local vendorPrice = app.features:GetModule("VendorPrice")
---@type SeamlessCore.SettingsPage
app.optionPages.items = {
    tooltip = function(path)
        if path[2] == "game" then
            return app.core:GetCVarOptionInfo(path[3])
        end
        local defaults = app.dbDefaults.profile.features[path[2]]
        return app.core:GetOptionDefault(defaults, #path == 2 and { "enabled" } or path, #path == 2 and 1 or 3)
    end,
    defaults = {
        profile = {
            features = {
                ItemDetails = {
                    enabled = true,
                    stackSize = false,
                },
                ItemIDs = {
                    enabled = true,
                    item = true,
                    icon = false,
                },
                ItemLevel = {
                    enabled = true,
                    qualityColor = true,
                },
                QualityBorder = {
                    enabled = true,
                    minQuality = 2,
                },
                VendorPrice = {
                    enabled = true,
                    perItem = true,
                },
            },
        },
    },
    config = {
        type = "group",
        name = L["Items"],
        order = 20,
        args = {
            ItemDetails = {
                type = "group",
                feature = true,
                name = L["Item details"],
                desc = L["Adds details about an item to its tooltip."],
                order = 20,
                settings = function()
                    return itemDetails:Settings()
                end,
                toggled = function()
                    itemDetails:Refresh()
                end,
                changed = function()
                    itemDetails:SettingsChanged()
                end,
                args = {
                    stackSize = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = L["Stack size"],
                        desc = L["How many of the item fit in one stack; only for items that stack."],
                    },
                },
            },
            ItemIDs = {
                type = "group",
                feature = true,
                name = L["Item IDs"],
                desc = L["Adds the item's ID, and its icon's ID, to item tooltips."],
                order = 10,
                settings = function()
                    return itemIDs:Settings()
                end,
                toggled = function()
                    itemIDs:Refresh()
                end,
                changed = function()
                    itemIDs:SettingsChanged()
                end,
                args = {
                    item = {
                        type = "toggle",
                        order = 10,
                        name = L["Item ID"],
                    },
                    icon = {
                        type = "toggle",
                        order = 20,
                        name = L["Icon ID"],
                        desc = L["The file ID of the item's icon."],
                    },
                },
            },
            ItemLevel = {
                type = "group",
                feature = true,
                name = L["Item level"],
                desc = L["Adds the item level to weapons and armor."],
                order = 15,
                settings = function()
                    return itemLevel:Settings()
                end,
                toggled = function()
                    itemLevel:Refresh()
                end,
                changed = function()
                    itemLevel:SettingsChanged()
                end,
                args = {
                    qualityColor = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = L["In quality color"],
                        desc = L["Shows the item level in the color of the item's quality (green, blue, purple, ...)."],
                    },
                },
            },
            QualityBorder = {
                type = "group",
                feature = true,
                name = L["Quality border"],
                desc = L["Colors the border of item tooltips in the item's quality color. Works with the game's border and with \"Border and background\"."],
                order = 30,
                settings = function()
                    return qualityBorder:Settings()
                end,
                toggled = function()
                    qualityBorder:Refresh()
                end,
                changed = function()
                    qualityBorder:SettingsChanged()
                end,
                args = {
                    minQuality = {
                        type = "select",
                        order = 10,
                        name = L["From quality"],
                        desc = L["Items of a lower quality keep the normal border."],
                        -- Filled below from the game's quality names and colors.
                        values = {},
                        sorting = {},
                    },
                },
            },
            VendorPrice = {
                type = "group",
                feature = true,
                name = L["Vendor price"],
                desc = L["Shows what an item sells for at a vendor; for a stack, also what one of it sells for."],
                order = 25,
                settings = function()
                    return vendorPrice:Settings()
                end,
                toggled = function()
                    vendorPrice:Refresh()
                end,
                changed = function()
                    vendorPrice:SettingsChanged()
                end,
                args = {
                    perItem = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = L["Price per item"],
                        desc = L['Adds the price of one item behind a stack\'s price ("1s 20c (6c each)").'],
                    },
                },
            },
        },
    },
}

-- Poor (grey) up to Heirloom; the select shows each in its own color.
local qualityOption = app.optionPages.items.config.args.QualityBorder.args.minQuality
for quality = 0, 7 do
    local r, g, b = C_Item.GetItemQualityColor(quality)
    local name = _G["ITEM_QUALITY" .. quality .. "_DESC"]
    if r and name then
        qualityOption.values[quality] = CreateColor(r, g, b):WrapTextInColorCode(name)
        qualityOption.sorting[#qualityOption.sorting + 1] = quality
    end
end
