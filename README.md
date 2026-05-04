# Coffee

A tiny macOS menu bar utility for toggling `caffeinate`.

- Empty coffee cup outline: `caffeinate` is off.
- Filled coffee cup: `caffeinate` is on.
- Left-click the menu bar icon to open the menu.
- Right-click the menu bar icon to toggle. Turning it on runs:

```sh
/usr/bin/caffeinate -is
```

## Run

For quick development:

```sh
swift run Coffee
```

The app runs as an accessory app, so it only appears in the menu bar. Stop it with `Ctrl-C` from the terminal while running via SwiftPM.

For a normal macOS menu bar app launch:

```sh
just run
```

## Build

```sh
swift build -c release
```

The executable will be at `.build/release/Coffee`. `just app` wraps that executable in `.build/Coffee.app` using the checked-in `Resources/Info.plist` with `LSUIElement` enabled.

Useful commands:

```sh
just build    # release SwiftPM build
just app      # build .build/Coffee.app
just run      # build and open .build/Coffee.app
just restart  # kill Coffee, rebuild, and reopen
just clean    # remove .build
```

## Possible next steps

- Add a small preferences UI or config file for custom `caffeinate` flags.
- Add a dropdown menu showing current power assertions from `pmset -g assertions`.
- Package as a `.app` bundle with `LSUIElement` for login/startup use.
