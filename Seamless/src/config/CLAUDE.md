# Custom configuration window

This folder owns the standalone SettingsPanel-style shell inside the core addon.
`registry.lua` loads after `core/ace.lua`; `window.lua` owns rendering. Keep this
separate from `core/options.lua`, which owns the shared option declarations and
retains the existing Settings > AddOns panels as a fallback.

The shell uses the client's SharedXML primitives and Settings artwork, with its
own window, category tree and page lifecycle. It does not inherit SettingsPanel
mixins or register itself in Blizzard's window/layout managers.

## Public API

Get Core through `LibStub("AceAddon-3.0"):GetAddon("Seamless")`. Register from
`OnInitialize` if page callbacks need SavedVariables:

```lua
core:RegisterConfigCategory("MyAddon", {
    name = L["My addon"], header = true, order = 100,
})
core:RegisterConfigCategory("MyAddon:general", {
    name = L["General"], parent = "MyAddon", order = 0,
    create = function(page)
        -- Parent controls to page. Its width is 627; set its height to fit
        -- the controls. The shell handles scrolling the whole page.
        page:SetHeight(300)
    end,
    refresh = function(page)
        -- Read current settings, including the current profile.
    end,
})
core:OpenConfig("MyAddon:general")
core:RefreshConfig()
```

IDs must be unique; use an addon prefix. Parents must already exist. Categories
sort by `order` (default 100), then ID. Any parent can collapse; headers toggle
on label click, normal categories select a page and have a separate collapse
button. Collapse and window position last for the session. Opening a category
expands its ancestors. `create(page)` runs once; `refresh(page)` runs whenever
the selected page is refreshed. Callbacks own their controls, never reparent
the supplied page. All categories currently belong to the single Config tab.

`SeamlessConfigWindow` is the public frame name used by Escape handling.
`/seamless [options]` and minimap right-click toggle this shell (`core:ToggleConfig()`). Minimap left-click
opens General in this window. `core:OpenOptions(addonName, tab)` opens the corresponding
addon subview here as well.

## Settings rows

`core/options.lua` registers one category header per addon and one child page per
existing tab, including General. Only Core has Profiles. Unavailable tabs stay
hidden. The initial Core General placeholder receives its real page callbacks
when the Options module initializes.

`model.lua` adapts existing option declarations without rendering AceConfig UI.
It preserves original paths and inherited getters, setters, disabled predicates,
validation, confirmation and AceDBOptions handler methods. Read settings at use
time so profile switching continues to work.

`controls.lua` owns `config.ControlRow` (base class) and `config.controlCreators`
(factories keyed by option type). Extend these instead of patching Blizzard or
vendored libraries. Rows follow Settings' left label/right control alignment,
37-pixel label inset, 45-pixel section headers and hover treatment. They reuse
SharedXML's MinimalSliderWithSteppers, WowStyle2Dropdown, InputBox, ColorSwatch
and button templates and the Settings checkbox atlases. No SettingsPanel mixins,
global setting registration, AceGUI or AceConfigDialog rendering is involved.
Groups become collapsible section headings using the category headers' same
`common-button-list-plus/minus` art. Clicking either the label or button toggles
the section. Collapse state is kept per page and full option path for the session,
including across refreshes and profile switches. Nested groups retain their own
state; standalone header rows control following siblings until the next header.
Controls are pooled per page and type. The page
owns its height and the shell scrolls it. Registry notifications refresh visible
controls on the next frame, after the originating callback has finished.

`StaticPopupDialogs.SeamlessConfigConfirm` is the owned confirmation dialog key.
Run `lua src/tests/config-options.lua` and `lua src/tests/config-controls.lua`.

The red minimize/restore button beside Close switches between 920x724 and a
705x600 compact view. Compact mode retains the selected page and its width,
but hides navigation (including its scrollbar), the big Config tab, inner-frame
art and footer button. It retains the title, page scrolling, red Close button
and dragging. Mode survives closing/reopening for the session. Category collapse
buttons reuse the profession recipe headers' `common-button-list-plus/minus` art.
Header labels retain the native left inset, with the collapse button at the right
edge. Navigation rows and their artwork are 175 pixels wide, with a
1-pixel vertical gap between items. The navigation pane reserves a
24-pixel scrollbar gutter between the headers and the fixed inner-frame divider.
The scrollbar uses TOP/BOTTOM center anchors at the midpoint of that gap, with
8-pixel top/bottom insets. Its full 17-pixel arrow width fits inside the gap;
left-edge anchors would incorrectly shift the scrollbar toward the divider.
The minimize button uses `UIPanelCloseButtonNoScripts` and matches the red
Close button's frame level so the title border cannot cover it.

Run `lua src/tests/config-window.lua` and `npm run check`. Review the visual
match, dragging, scrolling and Escape in the WoW Forever client.

Scrollbars stay visible when their contents fit; scrolling is disabled and the bar
is desaturated and dimmed. Compact mode still hides the navigation scrollbar.
