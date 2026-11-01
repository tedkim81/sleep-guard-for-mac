# Sleep Guard for Mac

[한국어](README.ko.md)

Keep your Mac awake with the lid closed, so a long build, a download or an AI coding agent keeps running while you move. It turns itself off after a set time, and shows a menu bar indicator while it's on.

```console
$ awake 90m
Sleep disabled: turns off automatically in 1h 30m
```

While it's on, the menu bar shows `☕️ 1:29` (time left). Click it to turn sleep back on.

## Why not just `caffeinate`?

`caffeinate -i` only blocks *idle* sleep: Apple's IOKit documentation for that assertion says the Mac may still sleep when you close the lid, choose Apple menu → Sleep, or run low on battery. `caffeinate -s` is documented only as preventing system sleep on AC power, with nothing said about a closed lid, so don't count on it there either. To survive a closed lid you need `sudo pmset -a disablesleep 1`, but that's a system setting: it stays on after the command ends, and even after a reboot, until you turn it off. If you forget, the Mac never sleeps again, even in your bag.

Sleep Guard wraps `disablesleep` so that forgetting is hard:

| | `caffeinate` | `pmset disablesleep` | Sleep Guard |
|---|---|---|---|
| Survives closing the lid | No (`-i`) / not documented (`-s`) | Yes | Yes |
| Turns off by itself | When the process exits | Never | After a set time (default 3h) |
| Visible while on | No | No | Menu bar ☕️ with time left |
| Survives a reboot | No | **Yes, silently** | Yes, and the indicator comes back at login |

Use `caffeinate` when the lid stays open. Use Sleep Guard when you need to close it.

## Install

Requirements: macOS, zsh (the default shell), Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/tedkim81/sleep-guard-for-mac.git
cd sleep-guard-for-mac
./install.sh
```

The installer asks for your password once, to put the root helper in `/usr/local/libexec/sleep-guard/`.

## Usage

```sh
awake          # disable sleep for 3 hours and turn the display off
awake 90m      # 90 minutes (also: 2h, or seconds like 5400)
unawake        # turn sleep back on
screenoff      # turn the display off only (handy with caffeinate)
```

- `awake` returns immediately; the timer runs in the background.
- Running `awake` again replaces the previous timer.
- Turn it off from the terminal (`unawake`) or from the menu bar (☕️ → Allow Sleep Again).

Always turn it on with `awake`. If you run `sudo pmset -a disablesleep 1` yourself, no indicator appears until your next login.

## How it works

| File | Installed to | Role |
|---|---|---|
| `bin/sleepguard.sh` | `/usr/local/libexec/sleep-guard/` (root-owned) | Turns `disablesleep` on and off and runs the auto-off timer |
| `shell/awake.zsh` | `~/.local/share/sleep-guard/` (sourced from `~/.zshrc`) | `awake`, `unawake`, `screenoff` |
| `app/SleepGuard.m` | `~/Applications/SleepGuard.app` | Menu bar indicator |
| LaunchAgent | `~/Library/LaunchAgents/io.github.tedkim81.sleep-guard.plist` | Opens the app once at login |

- **Nothing runs while sleep is enabled.** `awake` launches the menu bar app, and the app quits as soon as `disablesleep` is off. The LaunchAgent only opens the app once at login, so a setting left on by a forced shutdown still shows up.
- **An old timer never turns off a newer setting.** `/var/run/sleepguard.state` records the one current timer. Starting or stopping removes that record before killing the old timer, and a timer turns sleep back on only if it is still the current one.

Run the timer tests (no sudo, uses a fake `pmset`):

```sh
./test/test.sh
```

## Security notes

- `awake` and `unawake` call the helper with `sudo`, and the menu bar app asks for your password to turn sleep back on. Nothing is granted passwordless sudo.
- The helper lives in a root-owned directory. The installer refuses to install it if `/usr/local` or `/usr/local/libexec` is writable by anyone but root.
- The menu bar app is built on your machine from source and ad-hoc signed. There is no prebuilt binary.

## Heat

A Mac that stays awake in a closed bag can't get rid of heat well, even with its vents clear: the air in the bag warms up, and the case itself can't shed heat. Apple silicon slows down instead of overheating, so the cost is a slower job, a hot laptop and wear on the battery. Light work (downloads, SSH sessions, an agent waiting on API calls) is usually fine for a short trip. For heavy work (builds, local models, video encoding), carry the Mac out of the bag.

## Uninstall

```sh
./uninstall.sh
```

This turns sleep back on and removes everything the installer added.

## Tested on

macOS 15.1 (Apple silicon).

## License

[MIT](LICENSE)
