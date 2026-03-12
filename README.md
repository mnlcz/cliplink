# cliplink

A lightweight background daemon for Linux that monitors the clipboard and lets you save URLs to a file with a single click.

## What it does

When you copy a URL, cliplink detects it via GPaste and shows a desktop notification with **Save** and **Dismiss** buttons. If you choose Save, the URL is appended to chosen location (`~/links.txt` by default). If you dismiss, nothing happens and cliplink goes back to watching.

## How it works

```
GPaste (clipboard manager)
        │ D-Bus signal: Update
        ▼
cliplink detects URL via regex
        │
        ▼
freedesktop desktop notification (Save / Dismiss)
        │
        ├─ Save   → append to <output_file_path>
        └─ Dismiss → skip
```

## Stack

| Component | Technology |
|---|---|
| Language | D (LDC 1.40 / DMD 2.110) |
| Build system | DUB |
| D-Bus bindings | ddbus 3.0.0-beta.2 |
| Clipboard monitoring | GPaste 45.3 via `org.gnome.GPaste2` D-Bus API |
| Notifications | freedesktop `org.freedesktop.Notifications` |
| Target platform | RHEL 10 / GNOME 47 / Wayland |

## Requirements

- Linux with a GNOME/Wayland session
- [GPaste](https://github.com/Keruspe/GPaste) installed and running
- LDC or DMD D compiler
- DUB package manager

## Building

```bash
dub build
```

## Running

```bash
./cliplink --path=<output_file_path>
```

Make sure the GPaste daemon is running before starting cliplink:

```bash
gpaste-client start
./cliplink --path=<output_file_path>
```

## Project structure

```
cliplink/
├── dub.sdl
├── resources/
│   └── cliplink.png     # Icon
└── source/
    ├── app.d            # Entry point, D-Bus main loop, GPaste watcher
    ├── urlfilter.d      # Regex-based URL detection
    ├── linkappender.d   # Appends URLs to ~/links.txt
    └── notifier.d       # Notification queue and freedesktop Notify integration
```

## Output file

URLs are saved to `~/links.txt` by default. You can specify a different path using the `--path` option. The default value can be changed in `app.d`.
