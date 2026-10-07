# SeamlessChat

Optional chat addon in the Seamless suite, imported from `../WoW-SeamlessChat`.
Requires `SeamlessCore`; users enable/disable it in WoW's AddOns screen and reload.
Preserves `SeamlessChatDB` (profiles, sync snapshots and character input history),
`SeamlessChatHistoryDB` and `SeamlessChatLogDB` (per-character history and log).

## Load order and integration

Every runtime Lua/XML file must be listed in dependency order in `SeamlessChat.toc`.

1. `src/core/bootstrap.lua`: obtains Core through AceAddon and shares its logger.
2. `db.lua`, `ace.lua`: defaults, independent AceDB/AceAddon lifecycle and legacy slash commands.
3. `options.lua`: native Settings > AddOns > Seamless > Chat, using Core's panel helpers and profiles.
4. `src/chat/`: state, sync, line transforms and input history.
5. `src/features/features.lua`, followed by features in TOC order. Window mixins load before their XML.
6. `SeamlessChat.lua`: load diagnostic.

LibEditModeOverride is vendored and loaded by Core, alongside Ace3. No local library embeds,
minimap launcher or standalone options window. `/seamlesschat` opens the native child category;
`save`, `apply`, `log`, `search <text>` and `reset` keep their existing behavior. `loglevel` delegates
to Core. Legacy local minimap/logLevel settings are unused; shared preferences live in Core.

Native controls retain the feature option definitions through `panel:Options`. Inputs open a
prefilled native dialog, permit empty channel labels, validate custom timestamp formats and
refuse stale edits after profile switches. Custom get/set callbacks retain nested settings and
color behavior. Nested channel-label options declare explicit defaults. Conditional inputs remain
visible but disabled while inapplicable. Status/preview rows show current text in their tooltip
and a Details dialog. Delete-log confirmation remains required.

### `src/chat/` — the same chat on every character

The game keeps the chat setup per character (windows via `GetChatWindowInfo` / `SetChatWindow*`,
colors via `ChangeChatColor`, channels via `GetChannelList`). The profile holds one snapshot
(`profile.chat`, `SeamlessChat.Snapshot`) that every character using it applies at login.

- `state.lua` — `app.chatState`, stateless: `Capture*` reads the game's setup, `Apply*` writes a
  snapshot back, `*Equal` compares. Applying diffs first and only touches what differs, so a
  character that already matches doesn't touch Blizzard's chat frames (less taint). Window layout
  (open/closed, dock order, name, color, position) is written with the `SetChatWindow*` setters and
  then applied by Blizzard's own `FloatingChatFrame_Update`, like at login; message types and
  channels go through the frame methods (`AddMessageGroup`, `AddChannel`). Voice transcription
  (ChatFrame3) and temporary whisper windows are left out. The main chat window (ChatFrame1) is an
  Edit Mode system, so its position and size (`SeamlessChat.ChatFrameLayout`: anchor at scale 1,
  width/height from the `Enum.EditModeChatFrameSetting` hundreds + tens-and-ones pair) are read
  from the active layout (`EditModeManagerFrame:GetActiveLayoutSystemInfo`) and written with
  LibEditModeOverride (`ReanchorFrame`, `SetFrameSetting`, `ApplyChanges`, which briefly opens and
  closes Edit Mode). `ApplyChatFrame` says why it couldn't: not loaded yet, Edit Mode open, combat,
  a preset layout (not editable), a missing anchor frame.
- `sync.lua` — `app.sync`, the Ace module that decides when: 2 s after the first
  `PLAYER_ENTERING_WORLD` it applies the snapshot (or saves one if the profile has none); after
  that, secure hooks on every setter (`WATCHED_FUNCTIONS`) save a changed setup, debounced. Saving
  is blocked (`ready = false`) while applying. The chat window position is applied after the
  windows (retried after combat or once Edit Mode has loaded its layouts) and taken from the game
  only after the user saved it in Edit Mode (`EditMode.SavedLayouts`, captured at `EditMode.Exit`),
  on "Save now", or when the profile has none, so a character that couldn't apply it (preset
  layout) doesn't overwrite it for everyone. Channels a window should show but the game refused
  on this character (`missingChannels`) are kept in the snapshot, so one character can't drop them
  for everyone; the channel list only grows by capture and shrinks on a `YOU_LEFT` notice.
- `lines.lua` — `app.lines`, the only wrapper of the chat frames' `AddMessage` (ChatFrame1-10 at
  file load, temporary windows via `FCF_OpenTemporaryWindow`; the combat log is passed through).
  Features change chat lines by `app.lines:Register(order, func(chatFrame, message, chatType),
secretSafe)`: `chatType` comes from the event AddMessage gets as 7th extra argument (so
  PARTY_LEADER, not PARTY), nil for print(). Each transform runs in pcall and checks its own
  feature's switch; secret lines only reach `secretSafe` transforms, which may only concatenate.
  Orders: URLs 10, channel names 20, timestamps 1000 (last, so its copy link holds the final line).
  Never wrap AddMessage anywhere else.

### `src/features/` — optional features

Everything the user can switch on and off is a feature: one file per feature, listed in the TOC
after `features.lua`.

- `features.lua` — `app.features`. `app.features:New(key, prototype, name, desc, defaults, ...libs)`
  makes an Ace module whose prototype inherits the feature methods: `GetSettings()`
  (`profile.features[key]`, where `enabled` is the switch; `defaults` are registered as AceDB
  defaults), `GetOptions()` (declarative option definitions for its own settings), `Refresh()` (re-apply after a
  setting changed) and `OnProfileRefresh()` (enable/disable to match the profile). `options.lua`
  gives every feature a native section: description, the Enable toggle, then `GetOptions()`, with get/set
  defaulting to the feature's settings and everything grayed out while it is off.
- A feature sets itself up in `OnEnable` and undoes it in `OnDisable`. Hooks that can't be removed
  (`hooksecurefunc`, a wrapped method) are installed once and check `self:IsEnabled()`.
- `timestamps.lua` — the last line transform (1000, `secretSafe`: the stamp is only concatenated)
  puts the time in front. Lines pass the transform from file load on, but stamping starts in
  `OnInitialize` (settings known); `Backfill` stamps the lines added before that, or while the
  feature was off (`unstampedSince`), with the time each arrived (`entry.timestamp`). Switches the game's
  `showTimestamps` CVar to `none` while enabled and restores it (`global.blizzardTimestamps`) when
  disabled.

- `history.lua` — `SetMaxLines` on every chat window (not the combat log; temporary windows via a
  hook on `FCF_OpenTemporaryWindow`), back to the game's 128 when disabled. Resizing keeps the
  lines (the newest ones when shrinking). With `persist`, logout (also /reload; via AceDB's `OnDatabaseShutdown`, see Conventions)
  saves the last `savedLines` of each open window (text as shown + color, no secret lines) into
  `SeamlessChatHistoryDB` (`## SavedVariablesPerCharacter`); `OnEnable` puts them back once per
  session with `BackFillMessage` (adds above everything, only while the window has room), below
  them a divider that is never saved (`dividers`). Copy links in saved lines get new ids
  (`app.copy:Relink`).
- `copy.lua` — `app.copy`. The game can only copy out of an edit box, so copying puts the line into
  the chat input, selected (`ChatFrameUtil.OpenChat(nil, frame)`, then `SetText` +
  `HighlightText`). `WrapTimestamp` (called by timestamps.lua) keeps the line under an id (last 1000) and wraps the stamp in `|Haddon:SeamlessChat:copy:<id>|h`; the game hands `addon` links to
  `EventRegistry` `"SetItemRef"`, where `OnSetItemRef` copies the line, stripped with
  `C_StringUtil.StripHyperlinks`. Secret lines get no link. The copy button (`CreateButton`, one
  per chat window, top right) follows the game's chat fade via hooks on `FCF_FadeInChatFrame` /
  `FCF_FadeOutChatFrame` with its own OnUpdate fade (not `UIFrameFadeIn`, whose shared list would
  get tainted); it opens the copy window with `GetRecentText` (`GetMessageInfo(1)` is the oldest
  line).
- `copywindow.lua` + `copywindow.xml` — `SeamlessChatCopyWindow`, a `DefaultPanelFlatTemplate` with
  a `ScrollingEditBoxTemplate` and `MinimalScrollBar` (shared templates this client loads).
  `ShowText` shows the text focused, selected and scrolled to its end; Escape closes it.

- `log.lua` — `app.chatLog`, the chat log: one `SeamlessChat.LogRecord` per chat event (`time`,
  `type` = event without `CHAT_MSG_`, `text` raw, `sender`, `channel`, `channelNum`, `guid`,
  `class`, `lang`, `flags`; empty/secret fields nil, secret text not recorded), from its own frame
  registered for every event in `ChatTypeGroup` plus `CHAT_MSG_COMMUNITIES_CHANNEL`. Stored in
  `SeamlessChatLogDB.records` (`## SavedVariablesPerCharacter`), oldest first. `Prune` drops past
  `maxMessages`/`maxDays` by moving `first` (no table.remove on a big array); `Compact` closes
  the gap at `OnDatabaseShutdown`. `Query(filter)` (search = text or sender, text on the plain
  text, sender, group, channel, types, since/before, limit; returns matches and the total) is the
  search API. `GROUPS` sorts records into kinds (`groupOf`: by type, then channel, BN_, NPC,
  else system); `CountGroups` counts them. `FormatRecord` is a plain line (copying),
  `FormatColored` the window's line with links, class color and the chat type's color. `onAdd` is
  the window's live-update hook.
- `logwindow.lua` + `logwindow.xml` — `SeamlessChatLogWindow` (`/seamlesschat log`, `search`): a
  `SearchBoxTemplate`, the groups in a `WowScrollBoxList` (`SeamlessChatLogGroupTemplate` rows,
  channels indented under Channels) and the newest 2000 matches in a `ScrollingMessageFrame`
  (hyperlinks go to `SetItemRef`, like the chat). Searching is debounced; new messages refresh the
  counts, and the results only while scrolled to the bottom. Copy sends `FormatRecord` lines to
  the copy window (`ShowText(text, title)`). `SeamlessChatLogButton` opens it: parented to
  `ChatFrame1ButtonFrame` above `ChatFrameMenuButton`, remade with the chat buttons' atlases
  (`chatframe-button-*`, not `VoiceToggleButtonTemplate`, which brings voice behavior); shown per
  `showButton` (`log.lua` `UpdateButton`).

- `urls.lua` — `app.urls`, line transform 10: web addresses (`scheme://`, `www.`, `domain/path`; outside
  existing `|H...|h` links, punctuation around them left out) become
  `|Haddon:SeamlessChat:url:<address>|h[address]|h`, the address in the link itself so restored
  history keeps working; a click (`SetItemRef` callback) puts it into the chat input. `Linkify` is
  also used by the log window.
- `channels.lua` — line transform 20: rewrites `|Hchannel:<data>|h[<name>]|h` (numbered: data
  `channel:<n>`, name "2. Trade - City", shown per `numbered` style; group channels: data GUILD,
  PARTY, ..., shown as `short[chatType]`, so PARTY_LEADER gets its own).
- `classcolors.lua` — sets the CVar `chatClassColorOverride` to "0" (every name class colored,
  overriding the per-type setting) while enabled; restores it (`global.classColorOverrideBefore`).
- `fading.lua` — `SetFading` / `SetTimeVisible` / `SetFadeDuration` on every chat window; the
  game's values (fade, 120 s, 3 s) when disabled.
- `background.lua` — one background `color` (with alpha; black, opaque by default) on every chat
  window, display only: `FCF_SetWindowColor` / `FCF_SetWindowAlpha` with `doNotSave`, so the
  windows' saved backgrounds (and the synced snapshot) stay and are restored when disabled. Secure
  hooks on those two setters paint over every redraw by the game (`painting` guards our own calls).

To add a feature: a new `src/features/<name>.lua` calling `app.features:New`, its TOC line, a README
entry. Nothing else needs registering.

### Annotations (not in the TOC)

- `src/types.lua` — the private-table class `SeamlessChat` (`app.*` fields) and
  `SeamlessChat.DB`. When a file adds a member to `app`, add a matching `---@field` here.

## Conventions

- Feature keys and SavedVariables names are persistent compatibility contracts; do not rename them.
- New feature settings belong in their defaults and `GetOptions()` definitions; no central registration needed.
- New private-table members need annotations in `src/types.lua`.
- Keep the single AddMessage wrapper in `src/chat/lines.lua`; transforms must preserve secret-value handling.
- Logout code reading settings registers AceDB `OnDatabaseShutdown`, never `PLAYER_LOGOUT`, because
  AceDB removes defaults when serializing its SavedVariables.
- Preserve combat, Edit Mode readiness and preset-layout guards in chat synchronization.
- The custom copy/log windows stay native Lua/XML UI; the settings renderer does not replace them.
