# SeamlessChat

Optional chat addon. `SeamlessChatDB` holds profiles (with the synced chat snapshot) and
per-character input history; `SeamlessChatHistoryDB` and `SeamlessChatLogDB` are per-character
saved lines and the chat log.

## Load order and integration

1. `src/core/bootstrap.lua`: obtains Core through AceAddon and shares its logger.
2. `db.lua`, `ace.lua`: defaults, AceDB/AceAddon lifecycle and `/seamlesschat`.
3. `options.lua`: the Chat panel: General (sync, chat input), Messages, Windows, Buttons, Log, Profiles.
4. `src/chat/`: state, sync, line transforms and input history.
5. `src/features/features.lua`, followed by features in TOC order. Window mixins load before their XML.
6. `SeamlessChat.lua`: load diagnostic.

`/seamlesschat` opens the Chat panel; `save`, `apply`, `log`, `search <text>`, `reset` and
`loglevel` (delegated to Core) are subcommands. LibEditModeOverride comes from Core.

Each feature is an inline section (`core.FeatureGroup`) on the tab named by its prototype's
`optionsTab` (`messages`, `windows`, `buttons`, `log`; the `TABS` table in `options.lua`), in TOC
order. Its `GetOptions()` args are plain AceConfig: get/set default to the feature's settings, an
own `disabled` must include the feature-off check, unknown keys are rejected.

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
  Orders: unread counts 1 (only counts), URLs 10, channel names 20, timestamps 1000 (last, so its copy link holds the final line).
  Never wrap AddMessage anywhere else.
- `input.lua` — `app.input`: plain arrow keys browse the chat input's sent lines (not secure slash
  commands, no consecutive repeats; Down past the newest empties the input), `inputHistoryLines`
  deep, per window; with `persistInputHistory` kept in `db.char.inputHistory` (temporary windows not).

### `src/features/` — optional features

Everything the user can switch on and off is a feature: one file per feature, listed in the TOC
after `features.lua`.

- `features.lua` — `app.features`. `app.features:New(key, prototype, name, desc, defaults, ...libs)`
  makes an Ace module whose prototype inherits the feature methods: `GetSettings()`
  (`profile.features[key]`, where `enabled` is the switch; `defaults` are registered as AceDB
  defaults), `GetOptions()` (AceConfig args for its own settings), `Refresh()` (re-apply after a
  setting changed) and `OnProfileRefresh()` (enable/disable to match the profile). `options.lua`
  gives every feature a section on its `optionsTab`: the Enable toggle with its description, then `GetOptions()`, with get/set
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
  `EventRegistry` `"SetItemRef"`, where `OnSetItemRef` copies the line (`FindLine`: the kept one, else
  read back from the chat window still showing the link, so restored history stays copyable), stripped with
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
  `ChatFrame1ButtonFrame` above `ChatFrameMenuButton` (placed by `skin.lua` while it is on), remade with the chat buttons' atlases
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
- `unread.lua` — line transform 1 (`secretSafe`, returns the line unchanged): counts chat lines (a
  `chatType`; numbered channels per `channels`) reaching a docked window that isn't the selected one
  (`FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)`), shown as a badge (`color`) at its tab's top right
  corner. The badge is on UIParent, anchored to the tab, so it stays while the game fades idle tabs;
  it hides with the tab. Cleared by hooks on `FCFDock_SelectWindow`, `FCF_UnDockFrame`, `FCF_Close`.
- `skin.lua` — the button bar left of the main chat window (feature key `skin`, "Chat buttons").
  `BUTTONS` lists the game's chat buttons and ours top to bottom; `Arrange` reparents the shown ones
  into `SeamlessChatButtonBar` (on UIParent where the game puts ChatFrame1's strip, so it stays while
  another docked tab hides ChatFrame1) and stacks them from the bottom up at one size, so hidden ones leave no gap (re-run from
  each button's OnShow/OnHide). `show[key]` hides a button (the log button uses the log feature's
  `showButton`; `game` buttons are still shown and hidden by the game). Its own buttons (`own`): copy
  (copy window for `SELECTED_CHAT_FRAME`) and options (Chat settings). Bottom up: options, copy, log,
  chat menu, channels, social, then text to speech and voice. Its settings are on the
  Buttons tab. Every button gets a dark plate (1 px edge + fill,
  the edge in `accent` on hover) and one icon style (`StyleIcons`): its own normal, pushed,
  highlight and disabled art hidden (again on `UpdateHighlight`, voice buttons swap it), its icon
  textures (`icons`, default `Icon`; the chat menu's art includes a frame, so a cropped `glyph`)
  desaturated and tinted `ICON_COLOR`, `accent` on hover. The social button's friends count is a
  corner badge shown only above 0 (hook on `UpdateDisplayedFriendCount`). The button strips' own art (`ButtonFrame*` in `CHAT_FRAME_TEXTURES`,
  whose alpha the game sets while fading) is hidden. `Release` puts parents, sizes, anchors, art, icon colors and
  hidden buttons back when disabled.

To add a feature: a new `src/features/<name>.lua` calling `app.features:New` with an `optionsTab`
on its prototype, its TOC line, a README entry. Nothing else needs registering.

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
- The custom copy/log windows stay native Lua/XML UI; the options panel does not replace them.
