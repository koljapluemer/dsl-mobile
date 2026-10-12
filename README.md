# dsl-mobile

Mobile-first Flutter apps over a folder of items written in the item language
from [`../dsl`](../dsl): one `*.txt` file per item, directly inside a data folder
you pick. Targets Android (sideload) and Linux desktop.

| App | Dir | Label / ID | What it does |
| --- | --- | --- | --- |
| queue | `apps/queue` | Queue, `com.koljasam.dsl_queue` | Three random items from the whole folder, "Next" for others. Read-only. |
| calendar | `apps/calendar` | Calendar, `com.koljasam.dsl_calendar` | Items per day / per date range (`appointment`, `recurring`). Read-only. See [its data-format notes](apps/calendar/docs/data-format.md). |
| edit | `apps/edit` | Items, `com.koljasam.dsl_edit` | Add, edit and delete items as plain text, with highlighting and lint. |

Each app is its own Flutter project with its own Android/Linux runner, so all
three install side by side. They share `packages/dsl` through a
[pub workspace](https://dart.dev/tools/pub/workspaces) (one `pubspec.lock` at
the root).

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/install) (stable channel)
- Android SDK + NDK (via `flutter doctor` / Android Studio) for the Android target
- Linux desktop build tools:
  - Ubuntu: `sudo apt install cmake ninja-build clang libgtk-3-dev imagemagick libmpv-dev`
  - Fedora: `sudo dnf install cmake ninja-build clang gtk3-devel ImageMagick mpv-libs-devel`
  - `libmpv-dev` is needed by `media_kit` (video playback), which every app
    links through `packages/dsl`.
- [`just`](https://github.com/casey/just) (optional)

## Commands

```bash
flutter pub get          # once, at the root
just dev queue           # run an app on the desktop
just apk edit            # debug APK, drops you into its output dir
just reinstall calendar  # release Linux bundle into ~/.local + desktop entry
just test                # all tests
just analyze
just sync-spec           # after a change in ../dsl
```

Install a built APK: `adb install -r apps/<app>/build/app/outputs/flutter-apk/app-debug.apk`

On Android every app asks for "All files access" (`MANAGE_EXTERNAL_STORAGE`) on
launch, so the data folder can live anywhere; Settings has a button to grant it
again. Each app asks for the data folder once (stored per app).

## Loading

All apps start painting immediately and scan the folder in a background
isolate. A rescan re-reads only files whose modification time or size changed.

- **queue** and **calendar** keep the last scan in a cache file in app storage
  (`items-cache.json`, raw text per file, reparsed with the current schema) and
  show it on start until the fresh scan lands. The refresh button rescans.
- **edit** keeps no cache. It opens on the Add screen while the folder loads.
  The editor always starts from the file's current text on disk, not from the
  scan.

## packages/dsl

- `document.dart`, `schema.dart`: the parser. Reads `assets/keywords.yaml`
  (vendored from `../dsl`, refresh with `just sync-spec`) and names no keyword.
  Besides the spec's parse it gives offsets for highlighting (`Document.spans`)
  and for each diagnostic (`Diagnostic.from`/`to`). Tests run
  `../dsl/spec/examples` and fail when the vendored schema is out of date.
- `edits.dart`: the whole-line text edits behind the editor's quick buttons
  (set/remove a keyword's line, start the extra block).
- `folder_scan.dart`, `item_cache.dart`, `folder_repository.dart`: scan,
  cache, and the `ChangeNotifier` all apps build on.
- `widgets/`: app bootstrap (`DslApp`), settings screen, refresh button, media
  preview and viewers.

## edit: writing files

- New files are named `<slug of the first line>-<6 hex>.txt`. The name never
  changes afterwards, because other items refer to it (`-> label @name`).
- Writes go through a hidden temp file (`.<name>.tmp`) and a rename. A save
  whose text equals the file's text doesn't touch the file, so modification
  time keeps meaning "last edited".
- A save checks that the file hasn't changed on disk since the editor opened
  it. If it has, it asks: keep editing, load the disk version, or overwrite.
- Text is saved as typed, errors included. Errors and warnings are shown under
  the editor; the list's warning button filters to items that need attention.
- Attachments are copied to `images/<item stem>-<epochMillis><ext>` and
  referenced with a `media` line. Attachments imported during an edit that the
  text no longer references when the edit ends are deleted again.
- Delete hides the item at once and deletes the file after two more taps
  anywhere without "Undo". Its attachment is deleted too, if it's directly in
  `images/` and no other item references it (only checked after a complete
  scan; otherwise it's left in place).
