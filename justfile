# Apps live in apps/<app>: queue, calendar, note.

default:
    @just --list

# Copy the item language's keyword schema in from the sibling dsl repo
sync-spec:
    cp ../dsl/spec/keywords.yaml packages/dsl/assets/keywords.yaml

# Run every package's and app's tests
test:
    #!/usr/bin/env bash
    set -euo pipefail
    for d in packages/dsl apps/*; do
        [ -d "$d/test" ] || continue
        echo "== $d"
        (cd "$d" && flutter test)
    done

# Analyze the whole workspace
analyze:
    flutter analyze packages apps

# Run an app on the desktop with hot reload
dev app:
    @if ! command -v pkg-config >/dev/null || ! pkg-config --exists mpv; then \
        echo "Missing Linux dependency: libmpv development files." >&2; \
        echo "  Fedora: sudo dnf install mpv-libs-devel" >&2; \
        echo "  Ubuntu: sudo apt install libmpv-dev" >&2; \
        exit 1; \
    fi
    cd apps/{{app}} && flutter run -d linux

# Build an app's debug APK and drop into its output directory (e.g. to run adb install)
apk app:
    cd apps/{{app}} && flutter build apk --debug
    cd apps/{{app}}/build/app/outputs/flutter-apk && exec $SHELL

# Regenerate an app's icons (desktop/favicon set in icons/, Android launcher icons) from its emoji (needs ../scripts)
icons app:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{app}}" in
        queue) emoji=🎲 ;;
        calendar) emoji=📆 ;;
        note) emoji=📝 ;;
        *) echo "unknown app: {{app}}" >&2; exit 1 ;;
    esac
    uv run --project ../scripts ../scripts/emoji-icons/run.py "$emoji" apps/{{app}}/icons \
        --name {{app}} --android-res apps/{{app}}/android/app/src/main/res

# Build an app's Linux release bundle and (re)install it into ~/.local, with a desktop entry
reinstall app:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{app}}" in
        queue|calendar|note) name={{app}} ;;
        *) echo "unknown app: {{app}}" >&2; exit 1 ;;
    esac
    id=com.koljasam.dsl_{{app}}
    bin=dsl_{{app}}
    share=~/.local/share/$bin
    cd apps/{{app}}
    flutter build linux --release
    mkdir -p "$share"
    cp -r build/linux/x64/release/bundle/* "$share/"
    mkdir -p ~/.local/bin
    ln -sf "$share/$bin" ~/.local/bin/$bin

    magick=$(command -v magick || command -v convert)
    for size in 16 32 48 64 128 256 512; do
        dir=~/.local/share/icons/hicolor/${size}x${size}/apps
        mkdir -p "$dir"
        "$magick" icons/icon.png -resize "${size}x${size}" "$dir/$id.png"
    done
    command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor || true

    mkdir -p ~/.local/share/applications
    cat <<EOF > ~/.local/share/applications/$id.desktop
    [Desktop Entry]
    Type=Application
    Name=$name
    Exec=$share/$bin
    Icon=$id
    Categories=Utility;
    StartupWMClass=$id
    EOF
    command -v update-desktop-database >/dev/null && update-desktop-database ~/.local/share/applications || true
