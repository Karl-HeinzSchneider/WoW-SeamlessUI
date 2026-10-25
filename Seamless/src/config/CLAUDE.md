# Custom configuration window

This folder owns the standalone SettingsPanel-style shell inside the core addon.
TOC order: `registry.lua` (after `core/profiles.lua`), `badges.lua`, `window.lua`
(the shell), `model.lua`, `controls.lua`, then `position.lua` after
`core/frameposition.lua`. Keep this separate from `core/options.lua`, which owns
the shared option declarations and registers each one in both this window and
Blizzard's Settings > AddOns panels. The two panels run in parallel: every option
added through `RegisterOptions` must work in both, so new control types or
AceConfig keys need a renderer here and must stay valid AceConfig there.

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

## Feature tags

Set `new = true`, `blizzard = true` or `editMode = true` on a `RegisterConfigCategory` spec,
an individual option declaration, a group (section heading), a `FeatureGroup` spec, or a tab in
`RegisterOptions(..., { tabs = { player = { name = L["Player"], order = 10,
new = true, args = { ... } } } })`. The tab flag marks its subcategory in the
left list; an option flag marks that setting or heading. Flags combine (EDIT MODE nearest the
label, then BLIZZ, then NEW). Labels do not propagate to children or clear on hover/open.

`editMode` (glowing EDIT MODE, blue glow) marks settings stored in the active Edit Mode layout
instead of the AceDB profile. Tag only those: `GetNativePositionOptions` tags its Position and
scale group; profile-stored positions from `GetPositionOptions` stay untagged. Settings in a
tagged group, or tagged themselves, also get the tooltip line
`\n\n|cff8080ff[Saved in the Edit Mode layout]|r`.

`badges.lua` uses `NewFeatureLabelTemplate`. Tags are children of their rows, do not reserve
layout space, and hide when pooled rows are reused. Setting rows place them left of the label;
section headings (`row.tagTrailing`) place them right of the heading text. Let parent
visibility and scrolling manage them; do not add per-frame visibility polling or a separate overlay.

`NormalizeOptionTags` removes these custom keys before passing declarations to
AceConfigRegistry, retaining them in a weak-key side table. Dynamic declarations
should call `core:RefreshOptions(addonName)` after rebuilding so flags are
normalized before native options redraw. Never modify the vendored AceConfig
validator to accept custom keys.

## Edit Mode visibility

A frame's option declarations also supply its Edit Mode details content, using the existing
Edit Mode renderer and row types. Preserve its templates, label/control alignment, dimensions,
fonts and spacing; do not use the settings-panel widgets or layout in the details window.

Options, groups, tabs and `FeatureGroup` specs may set `hideInEditmode = true` to exclude their
content from details. Omission or `false` includes it. A hidden group excludes its descendants;
a hidden standalone header excludes only that header. The flag does not affect either settings
panel, and is separate from the `editMode` layout-storage badge. Core validates and strips it
before passing the table to AceConfig.

Tabs with `GetNativePositionOptions` bind automatically to that native frame. Custom frames bind
with `core:RegisterEditModeSettings(frame, addonName, { tabKey }, enabled)`; `frame` may be a
resolver and `enabled` is an optional predicate. `GetEditModeOptionSections` converts the current
declarations to the existing details schemas: toggle, select, range, button, text, input and color.
Callbacks keep their original paths, inherited handlers, validation and confirmation. Cached row
adapters preserve sliders and typed input across refreshes. Position uses the existing specialized
section and respects the same visibility flag on its group and individual controls.

Run `lua src/tests/editmode-options.lua` and `lua src/tests/editmode-dialog.lua`; the dialog
harness verifies the original Edit Mode templates, widths and row heights for mirrored controls.

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
and button templates and the Settings checkbox atlases. Select rows use the native
previous/next stepper buttons and dropdown radio selection methods, preserving
choice order and disabling arrows at the endpoints or when the setting is disabled.
Menus call the native `SetScrollMode(160)` so the menu viewport is capped at eight
standard 20-pixel rows; longer lists receive native scrolling automatically.
Range rows replace the right-hand value label with an InputBox. Enter accepts
finite numbers within the declared min/max and snaps to the declared step from
min; the same option validation, confirmation and disabled checks still apply.
Invalid input remains editable with an error tooltip; Escape, focus loss, hiding
or refresh discard unfinished input. Refresh/profile changes update the displayed
value without writing settings. No SettingsPanel mixins,
global setting registration, AceGUI or AceConfigDialog rendering is involved.
Groups become collapsible section headings using the category headers' same
`common-button-list-plus/minus` art. Clicking either the label or button toggles
the section. Collapse state is kept per page and full option path for the session,
including across refreshes and profile switches. Nested groups retain their own
state; standalone header rows control following siblings until the next header.
Controls are pooled per page and type. The page
owns its height and the shell scrolls it. Registry notifications refresh visible
controls on the next frame, after the originating callback has finished.

Tooltips use one anchor for both the row and its control: tooltip BOTTOMLEFT to
label TOPRIGHT, padded 12 pixels right and 8 up. Every setting gets the localized
`\n(Default: |cff8080ff%s|r)` line; per-character settings also get
`\n\n|cff8080ff[Per-character setting]|r`. `RegisterOptions` accepts a `tooltip(path)`
resolver returning the declared default and a per-character boolean. Keep this
metadata outside AceConfig tables. Resolve defaults from addon schemas or CVar
defaults, never from the current value. Profile settings that control per-character
data remain profile settings. Actions and transient selections with no stored
default display Not applicable. Select defaults use their localized choice labels;
colors use RGBA hex. `GetOptionDefault` reads schemas with AceDB wildcard support;
`GetCVarOptionInfo` reads the client default and server-character flag.

`StaticPopupDialogs.SeamlessConfigConfirm` is the owned confirmation dialog key.
Run `lua src/tests/config-options.lua` and `lua src/tests/config-controls.lua`.

Compact mode preserves the selected page, page width and scrolling while hiding navigation
and the Config tab. Window and collapse state last for the session. Scrollbars remain visible
but dimmed and disabled when content fits; compact mode hides the navigation scrollbar.

Run `lua src/tests/config-window.lua`. Check dragging, scrolling, compact mode and Escape in game.

## Reusable Position sections

`core:GetPositionOptions(spec)` returns a collapsible inline Position and scale group with
Anchor, AnchorParent, AnchorFrame, X, Y and Scale. It uses the same `get(key)`,
`set(key, value)`, `anchorFrames` and optional `disabled()` contract as
`GetEditModePositionSetting`; the keys are point, relativePoint, relativeTo, x, y.
No position is stored by the controls. The returned group's order can be changed.

For native Edit Mode frames, use `core:GetNativePositionOptions(function()
return PlayerFrame end)`. The frame is resolved on every access, and the shared
`core:GetFramePositionService()` reads and applies the active native layout.
Inside Edit Mode it preserves the live draft and native Save/Revert ownership;
outside Edit Mode it saves through the manager's current live layout. Presets,
override layouts, unavailable systems and combat disable editing. Anchor choices
exclude self, descendants and cycles. This works without SeamlessUI enabled;
SeamlessUI's Edit Mode extension uses the same core backend with its own selection
and feature-enable checks. Settings stay in Edit Mode layouts, not AceDB profiles.

`Unit Frames > Player`, `Target` and `Focus` use it, each with Position and scale and
Style groups. Run `lua src/tests/blizzard-position.lua` for both native and config paths.

Defaults come from the game, not from our schemas: the service's `GetDefault(frame)`
returns `EditModePresetLayoutManager:GetDefaultSystemAnchorInfo`, the anchor the native
"Reset To Default Position" button applies, and `GetDefaultSetting(frame, setting)`
converts `GetDefaultSettingForSystem` to display units. Both return nil (tooltip: Not
applicable) where the client lacks the API. The native group passes them as the
optional spec `default(key)` and adds **Reset to default position** (spec `reset()`,
disabled by `isDefault()`), which applies the preset anchor with
`isInDefaultPosition = true` through the same `Apply` path.

Any option may carry its own `default` (a value or a function returning it). It is
stripped with the `new`/`blizzard` tags before AceConfig sees the table and wins over
the addon's `tooltip(path)` resolver; use it for values only the game knows.

Scale is always shown but disabled without an explicit `scale` binding containing
both `get()` and `set(value)`. Scale uses multipliers (1 = 100%); defaults are
min 0.5, max 2, step 0.01. Override these with the binding's `min`, `max`, `step`;
its optional `disabled()` adds to the section's combat/availability guards.
The binding owns applying and persisting scale through the frame's existing
settings path. It never routes scale through the position setter.

For a generic frame, add `scale = { get = getScale, set = setScale }` to the
`GetPositionOptions` spec. For a native frame, pass that binding as the optional
second argument to `GetNativePositionOptions(getFrame, scale)`; its default
getter reads the native frame's current scale. Omit the binding to retain the
disabled slider. The same binding in a `core:GetEditModePositionSetting(spec)` spec drives
the Scale row that leads every Edit Mode Position section (also disabled without it; Reset To
Default leaves it alone).

`core:GetNativeSettingScale(getFrame, setting)` binds Scale to a native Edit Mode
percentage setting (the unit frames pass `Enum.EditModeUnitFrameSetting.FrameSize`):
range, step and default from the setting's display info and preset, values written as
whole percentages through `EditModeManagerFrame:OnSystemSettingChange` like the native
slider (`ApplySetting`: saved at once outside Edit Mode, a draft inside it). It is
disabled while Edit Mode hides the setting (`ShouldShowSetting`, e.g. Focus without
Larger Frame).
