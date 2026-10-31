# SeamlessChat

Optional chat addon. The `SeamlessChat` namespace in `SeamlessDB` holds shared suite profiles (with the synced
chat snapshot) and per-character input history; `SeamlessChatHistoryDB` and `SeamlessChatLogDB` are per-character
saved lines and the chat log.

## Load order and integration

1. `src/core/bootstrap.lua`: obtains Core through AceAddon and shares its logger.
2. `db.lua`, `ace.lua`: schema skeleton, AceDB/AceAddon lifecycle and `/seamlesschat`.
3. `src/chat/`: state, sync, line transforms and input history.
4. `src/features/features.lua`, followed by features in TOC order. Window mixins load before their
   XML.
5. `SeamlessChat.lua`: load diagnostic.
6. `src/options/`: the General (sync, chat input), Messages, Windows, Buttons and Log pages, then
   `register.lua`.

`/seamlesschat` opens the Chat panel; `save`, `apply`, `log`, `search <text>`, `reset` and
`loglevel` (delegated to Core) are subcommands. LibEditModeOverride comes from Core.

Each page file declares its own defaults and controls; features contain runtime behavior only.
Feature groups bind to the current `GetSettings()` table and refresh their module.

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
  Features change chat lines by
  `app.lines:Register(order, func(chatFrame, message, chatType), secretSafe)`: `chatType` comes from
  the event AddMessage gets as 7th extra argument (so PARTY_LEADER, not PARTY), nil for print().
  Each transform runs in pcall and checks its own feature's switch; secret lines only reach
  `secretSafe` transforms, which may only concatenate. Orders: unread counts 1 (only counts), URLs
  10, channel names 20, timestamps 1000 (last, so its copy link holds the final line). Never wrap
  AddMessage anywhere else.
- `input.lua` — `app.input`: plain arrow keys browse the chat input's sent lines (not secure slash
  commands, no consecutive repeats; Down past the newest empties the input), `inputHistoryLines`
  deep, per window; with `persistInputHistory` kept in `db.char.inputHistory` (temporary windows not).

### Feature integration

`app.features:New(key, prototype, ...libs)` creates an Ace module. Its settings page
selects Messages, Windows, Buttons or Log. Defaults live beside that page in `src/options/`;
`GetSettings()` reads `profile.features[key]`, the page declares controls, and `Refresh()`
reapplies changes. Add the file to the TOC after `features.lua` and document it in the README.

Set up in `OnEnable`, undo changes in `OnDisable`. Install permanent hooks once and guard them
with `self:IsEnabled()`. Preserve these ownership boundaries:

- `timestamps.lua`: final line transform; copy links must contain the fully transformed line.
- `history.lua`: per-character persisted public lines, restored once with `BackFillMessage`;
  relink saved copy links through `app.copy:Relink`.
- `copy.lua`, `copywindow.lua/xml`: copy via an edit box; never attach copy links to secret lines.
  Use an owned fade rather than tainting the shared `UIFrameFadeIn` list.
- `log.lua`, `logwindow.lua/xml`: structured per-character records and search UI. Never record
  secret text. Prune through the moving first index, compact at database shutdown.
- `urls.lua`, `channels.lua`, `unread.lua`: ordered line transforms (10, 20, 1 respectively).
  URL links carry their address so restored history remains usable.
- `background.lua`: visual overrides use `doNotSave`; preserve the synced native backgrounds.
- `skin.lua`: owns chat-button placement and styling; restore parents, anchors, art and hidden
  buttons on disable. Keep the bar on UIParent so switching docked tabs cannot hide it.

## Conventions

- Feature keys are persistent compatibility contracts; retain old SavedVariables names for migration.
- New feature settings and defaults belong in their page under `src/options/`.
- Keep the single AddMessage wrapper in `src/chat/lines.lua`; transforms must preserve secret-value handling.
- Logout code reading settings registers AceDB `OnDatabaseShutdown`, never `PLAYER_LOGOUT`, because
  AceDB removes defaults when serializing its SavedVariables.
- Preserve combat, Edit Mode readiness and preset-layout guards in chat synchronization.
- The custom copy/log windows stay native Lua/XML UI; the options panel does not replace them.
