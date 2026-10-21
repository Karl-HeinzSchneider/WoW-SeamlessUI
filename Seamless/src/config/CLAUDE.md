# Custom configuration window

This folder owns the standalone SettingsPanel-style shell inside the core addon.
`registry.lua` loads after `core/ace.lua`; `window.lua` owns rendering.
`options.lua` embeds existing option definitions. `core/options.lua` still owns
the existing AceConfig tables/panels and mirrors registrations into this tree.

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
and `core:OpenOptions` still open the existing Blizzard panels. Those panels and
the custom window share the same settings and callbacks.

## Addon option pages

Every `core:RegisterOptions` registration also adds a collapsible addon header.
General, each addon tab (including individual unit frames/cast bars), and Profiles
become separate child pages. Core's legacy Tweaks panel becomes a page under
Seamless. Only loaded addons register; Core does not discover or load features.

The adapter feeds the original table and tab path into `AceConfigDialog:Open`
with an owned AceGUI SimpleGroup. Do not duplicate accessors, copy option trees
or modify vendored code. This retains inherited get/set, disabled conditions,
confirmation dialogs, dynamic groups and AceDB profile controls. Existing control
styles are retained inside the new shell for now. Each page is created lazily;
its measured widget height drives the shell's native scrollbar. The page width
is the same in full and compact modes.

`hidden` categories (boolean or function) hide their descendants too. The adapter
uses the original tab's hidden condition with its original AceConfig path info,
so unavailable unit frames stay out of the sidebar. If the selected category
becomes hidden, the window selects the first visible page. Collapsing a header
does not change the selected page.

AceConfig `ConfigTableChange` notifications refresh a visible custom window on
the next tick, coalescing multiple notifications and allowing widget callbacks
to finish. Profile events already notify through the original registration.
Reopening refreshes a window that was hidden during an external change.

The red minimize/restore button beside Close switches between 920x724 and a
705x600 compact view. Compact mode retains the selected page and its width,
but hides navigation (including its scrollbar), the big Config tab, inner-frame
art and footer button. It retains the title, page scrolling, red Close button
and dragging. Mode survives closing/reopening for the session. Category collapse
buttons reuse the profession recipe headers' `common-button-list-plus/minus` art.
Header labels retain the native left inset, with the collapse button at the right
edge. The minimize button uses `UIPanelCloseButtonNoScripts` and matches the red
Close button's frame level so the title border cannot cover it.

Run `lua src/tests/config-window.lua`, `lua src/tests/config-options.lua` and `npm run check`. Review the visual
match, dragging, scrolling and Escape in the WoW Forever client.
