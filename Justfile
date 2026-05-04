name := "Coffee"
app := ".build/" + name + ".app"
contents := app + "/Contents"
macos := contents + "/MacOS"
executable := ".build/release/" + name

_default:
    @just --list

# Build the Swift executable in release mode.
build:
    swift build -c release

# Build a macOS .app bundle around the SwiftPM executable.
app: build
    rm -rf "{{app}}"
    mkdir -p "{{macos}}"
    cp "{{executable}}" "{{macos}}/{{name}}"
    cp Resources/Info.plist "{{contents}}/Info.plist"
    @echo "Built {{app}}"

# Open the app bundle.
run: app
    open "{{app}}"

# Kill any running instance, rebuild, and reopen it.
restart: app
    pkill -x "{{name}}" || true
    open "{{app}}"

# Remove build products.
clean:
    rm -rf .build
