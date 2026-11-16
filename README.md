# 🐱 CuteTimer

A tiny, cute, animated countdown timer for macOS that floats at the top of your screen — above every window, on every Space, even over full-screen apps.

- Pastel gradient that slowly shifts, with a progress ring around a little cat mascot
  - 🐱 hops while running · 😴 snoozes when paused · 🙀 panics in the last 10 s · 😻 celebrates when done
- Finish: happy shake, floating ✨💖🌸 sparkles and a 3× Glass chime
- Controls: pause/play, **+1** min (snooze when done), ✏️ new timer, ✕ close
- Draggable, no Dock icon, multiple timers at once

## Build

Requires macOS 13+ and the Xcode command-line tools (`xcode-select --install`).

```bash
./build.sh   # builds ~/Applications/CuteTimer.app
```

Optional CLI helper:

```bash
mkdir -p ~/.local/bin
printf '#!/bin/bash\nopen -n "$HOME/Applications/CuteTimer.app" --args "$@"\n' > ~/.local/bin/cutetimer
chmod +x ~/.local/bin/cutetimer
```

## Use

```bash
cutetimer 25 Deep work     # start a 25-minute "Deep work" timer immediately
cutetimer                  # open the setup card (title + minutes, quick picks 5/15/25/45)
```

Or double-click `CuteTimer.app`. Decimal minutes work too (`cutetimer 0.5 Tea`).
