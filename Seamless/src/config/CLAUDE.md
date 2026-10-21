# Custom configuration window

This folder owns the standalone SettingsPanel-style shell inside the core addon.
`registry.lua` loads after `core/ace.lua`; `window.lua` owns rendering. Keep this
separate from `core/options.lua`, which still owns the existing AceConfig panels.

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
and `core:OpenOptions` still open the existing panels until option migration.

The red minimize/restore button beside Close switches between 920x724 and a
705x600 compact view. Compact mode retains the selected page and its width,
but hides navigation (including its scrollbar), the big Config tab, inner-frame
art and footer button. It retains the title, page scrolling, red Close button
and dragging. Mode survives closing/reopening for the session. Category collapse
buttons reuse the profession recipe headers' `common-button-list-plus/minus` art.

Run `lua src/tests/config-window.lua` and `npm run check`. Review the visual
match, dragging, scrolling and Escape in the WoW Forever client.
