[한국어](README.md) | **English**

# Dallyeora Menubar

A macOS menu bar app that shows CPU and memory usage as an animated character. The default character, a sunfish, drifts along calmly when the machine is idle, swims faster as usage climbs, and flips belly-up and dies once usage passes 90%. Four Korean meme characters are included (a sunfish, an office worker heading home, a pork belly grill and a delivery rider), and you can switch between them from the menu.

The sunfish is a running joke in Korea: it's said to be so fragile that it dies from being startled, from too much sunlight, or from stress, which makes it a good stand-in for a laptop under load.

## Characters

Each character has four stages, and the phrase shown next to the icon changes with the CPU range. The numbers below are where each stage starts. The phrases in the app are in Korean; the English here is a rough translation.

| Character | 0% | 25% | 50% | 75% (90% for the sunfish) |
|---|---|---|---|---|
| Sunfish (default) | Swimming peacefully | Startled by sunlight | Critical from stress | Died of shock… please close some apps |
| Office worker Mr. Kim | Getting paid to slack off | Pretending to work | Overtime tonight, for sure | Sprinting out the door! |
| Pork belly grill | Heating up the grill | Sizzling | Flip it now! | It's burning! Laptop's hot |
| Delivery rider | Food is being cooked… | Picked up | On the way | Almost there! |

The drawings change with the stages too. The sunfish starts trembling and sweating when it gets startled and ends up upside down with X eyes, Mr. Kim leans further forward and takes longer strides as usage goes up, the grill puts out one more puff of smoke per stage and flips the meat above 75%, and the rider waits in place below 25% before the wheels start turning.

You can switch the phrasing between standard Korean and the Gyeongsang dialect from southeastern Korea, which reads a lot gruffer. Your choice of character and dialect is kept after you quit and reopen the app.

The Metric menu lets the character react to memory usage instead of CPU. Memory usage is app memory plus wired and compressed memory, divided by total memory. Since macOS puts spare memory to work as cache, this number often sits above 70 to 80% even on a quiet machine, so in memory mode the character spends more time in the higher stages.

Clicking the menu bar icon shows the current character and the selected metric's usage at the top, with submenus below for changing the character, the dialect and the metric, and a Quit item.

## Cleanup window

Choosing "정리하기…" (Clean up) from the menu opens a window that lists what is using the most CPU or memory right now. Apps with dozens of helper processes, like Chrome, are collapsed into one row, and each row carries a Korean name and a one-line note on why it is busy and whether it will settle down on its own. Apps that appear in the Dock or menu bar get a Quit button that works like ⌘Q; if the app is still running after five seconds the button changes to Force Quit, which asks for confirmation first.

System processes cannot be measured without administrator rights, so they appear as a single "macOS 시스템" row, and the memory total does not match the menu bar percentage exactly because the two use different definitions. Processes not in the built-in catalog show their raw name or "unknown"; the catalog lives in `Sources/DallyeoraCore/Processes/CatalogEntries.swift`.

## Install

Run this one line in Terminal to download the latest version into your Applications folder and launch it. Installing this way does not trigger the security warning described below.

```bash
curl -fsSL https://raw.githubusercontent.com/cozynye/dallyeora-menubar/main/scripts/install.sh | sh
```

If you would rather not use Terminal, download `Dallyeora-<version>.dmg` from [Releases](../../releases), open it, and drag `Dallyeora.app` onto the Applications folder next to it. It needs macOS 14 or later and runs on both Apple Silicon and Intel Macs.

Because the app isn't notarized by Apple, the first launch is blocked with a message saying Apple could not verify it is free of malware. Close that dialog, open System Settings > Privacy & Security, scroll down and click "Open Anyway", then open the app again and confirm. The button is only shown for about an hour after the blocked attempt. If you prefer the terminal, `xattr -d com.apple.quarantine /Applications/Dallyeora.app` removes the quarantine flag instead. After the first launch it opens normally.

The app has no Dock icon and only lives in the menu bar, so to quit it, click the menu bar icon and choose Quit, or press ⌘Q while the menu is open.

## How it works

Every two seconds the app reads both CPU tick counts and memory page statistics from the macOS kernel. CPU usage comes from the difference since the previous reading, and since both values are always being measured, switching the metric takes effect immediately. The icon is redrawn every 0.2 seconds at 0% and every 0.03 seconds at 100%, with the interval shrinking in proportion to usage in between. It's drawn as a single-color template image, so macOS picks the right color for light and dark mode.

There are no image files; every character is drawn from lines and shapes with Core Graphics. The menu bar item's width is fixed to the longest phrase of the selected character so neighboring icons don't shift around when the stage changes, and the phrase is capped at 150pt and truncated with an ellipsis so the app doesn't get pushed out of sight on a crowded notched MacBook menu bar.

## Building from source

You need the Swift 6 toolchain, and building the universal (Intel plus Apple Silicon) app requires a full Xcode install rather than just the Command Line Tools.

```bash
swift test                  # unit tests
swift run Dallyeora         # build and run
scripts/make-app.sh 0.4.0   # creates Dallyeora.app, a dmg and a zip in dist/
```

The app launched with `swift run` and the packaged `.app` store their settings separately, so a character picked in one won't show up in the other.

Logic and drawing that can be tested without AppKit live in `Sources/DallyeoraCore`, and the menu bar UI is in `Sources/Dallyeora`. To add a character, create a file in `Sources/DallyeoraCore/Mascots/` that implements the `Mascot` protocol and register it in `Mascots.all`; it will show up in the menu right away. The drawing canvas is 28×18 with the y axis pointing down. The original design notes are in [docs/spec.md](docs/spec.md) (Korean).

## Known limitations

The icon is redrawn every 0.2 seconds even at 0% usage, so the app uses a bit more power than one that does nothing. The timers have a tolerance set so the system can coalesce wakeups, but drawing doesn't pause while the display is off yet. There's no launch-at-login option either; if you want it, add the app under System Settings > General > Login Items. The cleanup window is Korean only and does not list system processes individually.

## License

MIT. All characters are drawn from simple shapes in code, and no existing characters or brand logos are used.
