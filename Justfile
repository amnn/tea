name := "Tea"
app := ".build/" + name + ".app"
contents := app + "/Contents"
macos := contents + "/MacOS"
resources := contents + "/Resources"
executable := ".build/release/" + name
icon_source := "Resources/AppIcon.png"
iconset := ".build/AppIcon.iconset"
icon := ".build/" + name + ".icns"

_default:
    @just --list

# Build the Swift executable in release mode.
build:
    swift build -c release

# Generate the macOS app icon from the checked-in source image.
icon:
    @if [ -f "{{icon}}" ] && [ "{{icon}}" -nt "{{icon_source}}" ]; then \
      echo "Icon up to date {{icon}}"; \
    else \
      rm -rf "{{iconset}}"; \
      mkdir -p "{{iconset}}"; \
      sips -z 16 16 "{{icon_source}}" --out "{{iconset}}/icon_16x16.png"; \
      sips -z 32 32 "{{icon_source}}" --out "{{iconset}}/icon_16x16@2x.png"; \
      sips -z 32 32 "{{icon_source}}" --out "{{iconset}}/icon_32x32.png"; \
      sips -z 64 64 "{{icon_source}}" --out "{{iconset}}/icon_32x32@2x.png"; \
      sips -z 128 128 "{{icon_source}}" --out "{{iconset}}/icon_128x128.png"; \
      sips -z 256 256 "{{icon_source}}" --out "{{iconset}}/icon_128x128@2x.png"; \
      sips -z 256 256 "{{icon_source}}" --out "{{iconset}}/icon_256x256.png"; \
      sips -z 512 512 "{{icon_source}}" --out "{{iconset}}/icon_256x256@2x.png"; \
      sips -z 512 512 "{{icon_source}}" --out "{{iconset}}/icon_512x512.png"; \
      sips -z 1024 1024 "{{icon_source}}" --out "{{iconset}}/icon_512x512@2x.png"; \
      iconutil -c icns "{{iconset}}" -o "{{icon}}"; \
      rm -rf "{{iconset}}"; \
    fi

# Build a macOS .app bundle around the SwiftPM executable.
app: build icon
    rm -rf "{{app}}"
    mkdir -p "{{macos}}" "{{resources}}"
    cp "{{executable}}" "{{macos}}/{{name}}"
    cp Resources/Info.plist "{{contents}}/Info.plist"
    cp "{{icon}}" "{{resources}}/{{name}}.icns"
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
