# Calendar data format

Items are written in the item language from the sibling `dsl` repo. Its
`spec/language.md` defines the syntax, and its `spec/keywords.yaml` lists the
keywords. This file only covers what is specific to the calendar.

## Files

Every `*.txt` file directly inside the data folder is one item. Subdirectories
and other extensions are ignored. The app only reads the files; it never
writes them.

```
HCI lecture 4pm-7pm
(bring laptop)
recurring mo until 27-03
```

## Schema

The parser and the vendored `keywords.yaml` live in `packages/dsl` (see the
repo README). Folder loading, cache and refresh are shared with the other apps.

## What the calendar does with keywords

- `appointment <date>`: shown on that day.
- `recurring <weekday> [until <date|month>]`: shown on every matching
  weekday up to and including `until`. A month means its last day.
- No primary keyword the calendar knows (a plain note, e.g. from graphirst
  sharing the folder, or a primary added to the schema later): the item is
  valid, but appears on no day and isn't kept in memory.
- The first body line is the item's heading; the other body lines are shown
  muted under it. Relationships, `media` and the `data` and `extra` blocks are ignored.

## Problems

Settings lists two kinds of problem files, each with the spec's code, line
and offending token:
- **Invalid files**: files with errors. They are not shown in the calendar.
- **Warnings**: valid items with warnings, for example unknown keywords.
