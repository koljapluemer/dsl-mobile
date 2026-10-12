# Apps live in apps/<app>: queue, calendar, edit.

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
    cd apps/{{app}} && flutter run -d linux

# Build an app's debug APK and drop into its output directory (e.g. to run adb install)
apk app:
    cd apps/{{app}} && flutter build apk --debug
    cd apps/{{app}}/build/app/outputs/flutter-apk && exec $SHELL

# Build an app's Linux release bundle and (re)install it into ~/.local, with a desktop entry
reinstall app:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{app}}" in
        queue) name=Queue ;;
        calendar) name=Calendar ;;
        edit) name=Items ;;
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
