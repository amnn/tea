# Tea

A tiny macOS menu bar utility for toggling `caffeinate`.

- Empty tea cup outline: `caffeinate` is off.
- Filled tea cup: `caffeinate` is on.
- Left-click the menu bar icon to open the menu.
- Right-click the menu bar icon to toggle. Turning it on runs:

```sh
/usr/bin/caffeinate -is
```

## Run

For quick development:

```sh
swift run Tea
```

The app runs as an accessory app, so it only appears in the menu bar. Stop it
with `Ctrl-C` from the terminal while running via SwiftPM.

For a normal macOS menu bar app launch:

```sh
just run
```

## Build

```sh
swift build -c release
```

The executable will be at `.build/release/Tea`. `just app` wraps that
executable in `.build/Tea.app` using the checked-in `Resources/Info.plist` with
`LSUIElement` enabled.

Useful commands:

```sh
just build    # release SwiftPM build
just app      # build .build/Tea.app
just run      # build and open .build/Tea.app
just restart  # kill Tea, rebuild, and reopen
just clean    # remove .build
```
