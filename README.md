# EdgeTodo ✿

**English** | [繁體中文](README.zh-Hant.md) | [简体中文](README.zh-Hans.md)

**A to-do list that lives on the edge of your Mac screen — so you never forget to check it.**

Most to-do apps make you stop what you're doing and open another app. EdgeTodo hides as a thin sliver on the right edge of your screen. Move your mouse there and it slides out; move away and it tucks itself back in.

<!-- Add a demo GIF here: ![demo](docs/demo.gif) -->

## Features

- 🫧 **Hover to peek** — hides at the screen edge, slides out on hover
- 📌 **Pin it open** — pinned panel turns into Liquid Glass (macOS 26+)
  - Focused: glass + frost, easy to read
  - Unfocused: fully clear glass, you can see what's underneath
- 🔁 **Repeating tasks**
  - *Repeat anytime* — habits you do often but not daily (gym, laundry). Each click logs a completion and shows "last: 3 days ago · 12×"
  - *Scheduled* — every day, week, month, or any custom interval (every 3 days, every 2 weeks…). Once done, it shows when it's next due, comes back automatically, and turns red when overdue. Daily tasks get a 🔥 streak counter
- ⏰ **Due dates & reminders** — give any task a deadline. As it gets close, it moves to a "due soon" section at the top and turns yellow → orange → red. The screen edge glows when something is due today or overdue (so you notice even when the panel is hidden), the menu bar icon shows a count, and you get a notification the day before and on the day
- 📌 **Pin tasks to the top** — the most important ones stay in a highlighted section above everything else
- ↕️ **Drag to reorder** — arrange tasks however you like, even across categories
- 🗂 **Categories & states** — group tasks with `#work`, `#life`, `#study`… and sort them into To-do / Pending / Done / Cancelled
- 🎨 **Customize everything** — fonts (any font on your Mac), weight, size, text & accent colors, tint, opacity, size, corner radius
- 🤖 **AI-friendly** — tasks live in a plain JSON file, so any AI assistant (or script) can add tasks for you and the panel updates within a second
- 🪶 **Tiny & native** — a single Swift file, no dependencies, no account, no cloud

## Install

Requires macOS 12 or later (Liquid Glass needs macOS 26+).

1. Download this repo (**Code → Download ZIP**) and unzip it
2. Open **Terminal**, type `bash ` (with a space), drag `build.sh` into the window, press Enter
3. If macOS asks you to install **Command Line Tools**, install them and run step 2 again

The script builds the app, installs it to `/Applications`, and launches it.

## Usage

| Action | How |
|---|---|
| Open the panel | Move your mouse to the right edge of the screen (upper half) |
| Add a task | Type at the bottom. Add `#category` to file it, e.g. `edit raw clips #content` |
| Complete a task | Click the checkbox |
| Add a repeating task | Click the ↻ button next to + (cycles: none → anytime → daily → weekly → monthly), or type it: `/repeat`, `/daily`, `/weekly`, `/monthly`, or a custom interval like `/3d`, `/2w`, `/6m`, `/every 10 days` — e.g. `water plants #home /3d` |
| Add a due date | Click the 📅 button next to + and pick a date (and optional time), or type it: `/due fri`, `/due 10/25`, `/due 10/25 6pm`, `/due 3d`, `/today`, `/tmr 9am` — e.g. `essay #study /due fri 11:59pm` |
| Change or remove a due date | Right-click → **Due Date** |
| Log a repeating task | Click its ↻ icon — every click records a new completion time |
| Reorder tasks | Drag a task onto another spot. Dropping it into another category moves it there; dropping it into 📌 pins it. Or right-click → **Move Up / Move Down** |
| Pin a task to the top | Right-click → **Pin to Top** |
| Make an existing task repeat | Right-click → **Repeat** (pick a preset, or **Custom interval…** to set every N days / weeks / months) |
| Undo a check-in | Right-click → **Undo Last Check-in** |
| Move / re-categorize / delete | Right-click a task |
| Keep it open | Click 📌 |
| Reminder settings | Settings → **Due Dates & Reminders**: what counts as "due soon", reminder time, edge glow, notifications |
| Settings | Click ⚙︎ on the panel, or the ☑︎ menu bar icon → **Settings…** (⌘,) |
| Launch at login | ☑︎ menu bar icon → **Open at Login** |

## Let an AI add tasks for you

Everything is stored in `~/EdgeTodo/todos.json`. Give your AI assistant access to the `~/EdgeTodo` folder and say *"add 'book friday dinner' to my to-do"* — the panel picks up the change within a second.

Only `title` is required; everything else has defaults:

```json
{
  "todos": [
    { "title": "weekly report", "category": "work", "status": "todo" }
  ]
}
```

`status` is one of `todo`, `pending`, `completed`, `cancelled`.

Add `"due": "2026-10-25"` (or `"2026-10-25 18:00"` with a time) to give a task a deadline. Add `"pinned": true` to keep a task at the top. Repeating tasks add `"repeat": "anytime"`, or a schedule like `"repeat": "every", "every": 3, "unit": "day"` (`unit` is `day`, `week` or `month`; `"daily"`, `"weekly"` and `"monthly"` work as shortcuts). The app records `lastDone` and a `history` of check-in timestamps (ISO 8601) — handy if you want an AI to summarize your habits.

## Build manually

```bash
swiftc -O -parse-as-library EdgeTodo.swift -o EdgeTodo
```

Add `-D GLASS` when building against the macOS 26+ SDK to enable Liquid Glass. `build.sh` handles this and also works around mismatched SDK / compiler versions.

## Support

If EdgeTodo makes your day a little lighter, you can support it here:

- ☕ Buy Me a Coffee: https://buymeacoffee.com/sirene122


## License

[MIT](LICENSE)
