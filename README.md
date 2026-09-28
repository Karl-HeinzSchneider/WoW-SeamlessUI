# SeamlessUnitframes

A short description of SeamlessUnitframes.

## Features

- **Class colors** — player health bars in their class color, switchable as a whole and per unit
  frame (player, pet, target, target of target, focus, target of focus, party). A pet takes its
  owner's class color; NPCs keep the default green.

## Installation

Download it from the GitHub releases and put the `SeamlessUnitframes` folder into
`..\World of Warcraft\<client>\Interface\AddOns`.

## Usage

- `/seamlessunitframes` — open the options
- `/seamlessunitframes loglevel <level>` — set how much the addon writes to chat (`none`, `error`,
  `warn`, `info`, `verbose`, `debug`, `silly`)
- `/seamlessunitframes reset` — reset the current profile

## Development

Node 20+; run `npm install` once. `npm run dev:link -- "<WoW>/Interface/AddOns"` links the addon
into a client, `/reload` picks up changes. `npm run format` formats everything, `npm run check`
validates it. Releases are built by the GitHub workflows in `.github/workflows/`.

## License

[MIT](LICENSE)
