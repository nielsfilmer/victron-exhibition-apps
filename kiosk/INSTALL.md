# Kiosk install & operations guide

Step-by-step setup for a brand-new touchscreen kiosk (Mac + Iiyama
touchscreen) running App 1 or App 2. Written for a non-developer
Victron staffer to follow at the show.

> **Already-configured kiosk?** Skip to [Daily operations](#6-daily-operations).
>
> **For details about the apps themselves** (config schema, slide
> variants, animation timings) see the project root [`README.md`](../README.md).
> This file is install / hardware / show-floor operations only.

---

## 1. Hardware

The combination below is what we ship with — these models have been
tested through several shows and meet the kiosk's particular
requirements (capacitive multi-touch, touch-event behaviour that
doesn't trigger pinch-zoom).

| | Recommendation | Why this exact one |
|---|---|---|
| Touchscreen | **IIyama ProLite TF1633MSC** (15.6", Full HD 1920×1080, open-frame) or newer in the same series | Capacitive multi-touch, USB-powered touch, plays nicely with macOS. Open-frame mounting fits the demo enclosure. |
| Computer | **Apple Mac Mini M2** (8 CPU / 10 GPU, 8 GB / 256 GB) or newer | Mac is **mandatory**: Windows can't reliably disable multi-finger pinch-zoom gestures, which break the kiosk app. |
| Keyboard | Apple Magic Keyboard (any layout) | Needed only for one-time setup and on-site troubleshooting. The kiosk doesn't need it during the show. |
| Mouse | None | The touchscreen IS the input device. |
| Cabling | HDMI cable Mac → touchscreen HDMI in, USB cable Mac → touchscreen USB-B | Power: Mac, touchscreen (12 V DC adapter), optional powered USB hub. |

> **Don't substitute a Samsung touchscreen or a Windows PC.** We've
> tried both at previous shows; neither delivers on the combination of
> requirements (touch-without-pinch-zoom + reliable kiosk auto-start).

---

## 2. macOS one-time setup

Do these steps **once** when preparing a fresh Mac. They're independent
of which app (App 1 or App 2) you'll deploy — you'll pick that in step 3.

> **About running shell commands:** every command in this guide that
> looks like `sudo …` or starts with `./` runs in the macOS **Terminal**
> app — *not* the Spotlight search bar, the URL bar, or anywhere else.
>
> To open Terminal: press **⌘ + Space** to open Spotlight → type
> **Terminal** → press **Enter**. A black-or-white window with a `$`
> (or `%`) prompt appears. To run a command, click into the window,
> paste the command, press **Enter**. When prompted for the password
> by `sudo`, type the admin password (the cursor doesn't move while
> you type — that's normal) and press **Enter**.
>
> If you've never used Terminal before, that's it — paste, Enter, wait
> for the next prompt, paste the next command. Don't add any extra
> characters.

### 2.1 Update macOS to the latest version
The apps are tested against the latest stable macOS only.

### 2.2 Auto-login
Without auto-login, the LaunchAgent never fires after a power cycle.

`System Settings → Users & Groups → Automatically log in as → <kiosk user>`
→ enter the admin password.

> Auto-login requires **FileVault to be off**. Acceptable for a
> dedicated kiosk machine that holds no sensitive data; not acceptable
> for a personal Mac.

### 2.3 Auto-restart on power failure
So that a tripped power strip doesn't leave the kiosk dark.

```bash
sudo systemsetup -setrestartpowerfailure on
```

### 2.4 Disable sleep, screensaver, energy saver
The launcher script also runs `caffeinate -dimsu` while the kiosk is
running, but the system defaults should match.

```bash
sudo pmset -a displaysleep 0 sleep 0 disksleep 0
```

### 2.5 Disable all notifications
A macOS update banner over the slideshow is a bad look at a trade show.

`System Settings → Notifications`
- Show previews: **Never**
- Allow notifications when…: turn **all off**
- Walk through every app in the list, set to **Off**
- Schedule a 24/7 **Do Not Disturb** focus mode

### 2.6 Set display resolution
Our app targets 4K primary and scales linearly down to 1080p. Set the
Mac's display output to the touchscreen's **native** resolution.

`System Settings → Displays → Resolution → Scaled` → pick the
touchscreen's native resolution (**1920×1080** for the IIyama
TF1633MSC). Hover the resolution tiles to see the px values.

### 2.7 Install Chrome and make it default
The kiosk only ever uses Chrome; making it default avoids any Mac
prompts about which browser to use.

1. Download Chrome from <https://www.google.com/chrome/> and install.
2. Open Chrome → menu → **Settings → Default browser → Make default**.

### 2.7b Install Git (Xcode Command Line Tools)
The project is installed and updated via `git`, which isn't on a
brand-new Mac by default.

In Terminal:

```bash
xcode-select --install
```

A system dialog pops up — click **Install**, accept the licence, wait
for the download to finish (a few minutes). To verify, in Terminal:

```bash
git --version
```

You should see something like `git version 2.39.x`.

---

## 3. Install the project

### 3.1 Clone the project from GitHub
Don't download a zip — clone the repo so updates are a single command
(see §3.6). In Terminal:

```bash
cd ~
git clone https://github.com/nielsfilmer/victron-exhibition-apps.git
cd victron-exhibition-apps
```

This creates `~/victron-exhibition-apps/` containing the whole
project. **Don't rename or move the folder after install** — the
LaunchAgent gets the absolute path baked in. If you do need to move
it later, re-run `./kiosk/install.sh app1` (or `app2`) from the new
location to refresh the path.

> ⚠ **Don't clone into `~/Documents/`, `~/Desktop/`, `~/Downloads/`,
> `~/Pictures/`, `~/Movies/`, or `~/Music/`.** macOS protects these
> folders via TCC; LaunchAgents can't read scripts from them and the
> kiosk will silently fail to start at boot ("Operation not permitted"
> in `kiosk/app1.err.log`). `install.sh` refuses to install if the
> project is in one of these locations. The home directory itself
> (`~/`) is fine, as is anywhere else outside the protected list
> (e.g. an external drive mounted under `/Volumes/`).

### 3.2 Pick which app to run
- **App 1** — slideshow with countdown / pause / variants. Use this
  for product / story marketing screens.
- **App 2** — fullscreen video with invisible chapter buttons.
  Use this for a "press the on-screen image to jump to that section"
  experience.

### 3.3 Install the LaunchAgent
**Easy mode (no Terminal needed)** — open the project folder in
Finder (`~/victron-exhibition-apps`) and **double-click**:

- `Install App 1.command` — for App 1 (slideshow)
- `Install App 2.command` — for App 2 (chapter video)

A Terminal window opens automatically, runs the install, and prints
the success / failure message. Press any key to close the window
when it's done.

> First time you double-click a `.command` file, macOS may ask
> "Are you sure you want to open it?" Click **Open**. If macOS
> instead refuses with "cannot be opened because it is from an
> unidentified developer", right-click the file → **Open** → click
> **Open** in the dialog. This grants permission once, permanently.

**Terminal mode** (equivalent — any of these work the same as the
Easy-mode buttons):

```bash
./kiosk/install.sh app1     # for App 1 (slideshow)
# OR
./kiosk/install.sh app2     # for App 2 (chapter video)
```

You should see (for app1):

```
Installed and loaded com.intersolar.app1.
Start now:   launchctl start com.intersolar.app1
Logs:        /Users/<you>/victron-exhibition-apps/kiosk/app1.out.log / app1.err.log
```

If instead you see a "**Refusing to install: project lives in a
TCC-protected folder**" error, the project was cloned into one of
the protected locations (see §3.1). Follow the `mv` command shown
in the error to move it out, then re-run `./kiosk/install.sh app1`.

What just happened:
- The script templated the project's absolute path into
  `kiosk/com.intersolar.app{1,2}.plist`,
- Copied the plist to `~/Library/LaunchAgents/`,
- Loaded it via `launchctl` so it runs on every login,
- Set the launch script executable.

The kiosk will now start automatically at login, restart automatically
if Chrome quits unexpectedly, and write logs to
`kiosk/app{1,2}.{out,err}.log`.

### 3.4 Reboot to verify
Reboot the Mac. After auto-login, Chrome should come up fullscreen
running the chosen app, no manual interaction needed.

If it doesn't, check `kiosk/app{1,2}.err.log` for the reason. The most
common cause is the project folder having moved since `install.sh` ran
— re-run `./kiosk/install.sh app1` (or `app2`) to refresh the path.

### 3.5 Switching between App 1 and App 2
There's no in-app toggle (each kiosk runs one app at a time). **Always
uninstall the current app before installing the other** — otherwise
both LaunchAgents are loaded and both apps fight to take over the
foreground. In Terminal:

```bash
./kiosk/install.sh uninstall app1
./kiosk/install.sh app2
```

(Or vice versa.) Reboot to verify only the new app starts.

### 3.6 Updating the kiosk to the latest version
When new content / fixes are pushed to GitHub:

**Easy mode** — in Finder, open the project folder and **double-click
`Update.command`**. A Terminal window opens, pulls the latest version,
reloads the kiosk, and prints what changed.

**Terminal mode** (equivalent):

```bash
./kiosk/update.sh
```

This:
- Refuses to run if the project isn't a git clone, has uncommitted
  local changes, or isn't on the `main` branch (so it never clobbers
  on-site edits).
- Pulls the latest `main` from GitHub via fast-forward only.
- Reloads any loaded kiosk LaunchAgent (`com.intersolar.app1` /
  `app2`) so the running kiosk picks up the new files within a few
  seconds.
- Prints the list of new commits applied so the operator sees what
  changed.

If `update.sh` bails out with a "local changes detected" message,
it's because someone edited files on the kiosk Mac directly (e.g.
adjusted slide content in `config.js`). The script tells you the
two options — `git stash` (set them aside, can be restored) or
`git checkout -- .` (discard them, **destructive**).

---

## 4. Updating content during a show

### App 1 — slideshow
- Slide content (image / video, title, subtitle, body, variant,
  duration, loop): edit `app1-slideshow/config.js`. Save and reload
  the kiosk (see [§6 Operations](#6-daily-operations) — quit Chrome,
  it auto-relaunches).
- Add a new image: drop the file into `app1-slideshow/media/`,
  reference its filename from `config.js`. Same for videos
  (`.mp4`/`.webm`/`.ogg`).

### App 2 — chapter video
- Change the video: replace `app2-chapters/media/main.mp4`.
- Re-calibrate hotspots: set `debug: true` in
  `app2-chapters/config.js`, reload the kiosk, drag a finger over the
  visible button areas in the video and read the live coordinates from
  the on-screen HUD; update `buttons[].x/y/width/height` and set
  `debug: false` again.

> **Reminder:** the checked-in `app2-chapters/config.js` ships with
> `debug: true`. **Before the show**, set it to `false` or visitors
> will see red calibration outlines over every hotspot.

For the full schema (every config field, every variant, animation
timings) see [`README.md`](../README.md).

---

## 5. Hardware connections (each kiosk)

| Cable | From | To |
|---|---|---|
| HDMI | Mac Mini | Touchscreen HDMI input |
| USB | Mac Mini | Touchscreen USB-B — provides the touch input |
| Power | Mac Mini | Wall / power strip |
| Power | Touchscreen | 12 V DC adapter → wall / power strip |

---

## 6. Daily operations

### 6.1 Opening the stand (each touchscreen)
1. Power on the touchscreen at its on/off button (or just energise the power strip — the touchscreen comes on automatically when power is applied).
2. The Mac Mini auto-powers when its power strip comes on (because of `setrestartpowerfailure`). If it didn't, press its on/off button on the back-right.
3. The Mac shows the kiosk fullscreen automatically.

If the kiosk doesn't appear but the Mac desktop is visible:
1. Force-quit Chrome: `⌘+⌥+Esc → Google Chrome → Force Quit`.
2. The LaunchAgent will relaunch the kiosk almost immediately (the
   plist's `ThrottleInterval: 10` is a *minimum* gap — relaunch may
   be near-instant when Chrome was up for more than 10 s before
   quitting).

If Chrome shows "Restore previous session?" — the launch script
auto-strips this on next start. If it persists, delete the kiosk
profile: `rm -rf ~/.kiosk-app1-profile` (or `app2`), then reboot.

### 6.2 Closing the stand
- Power off the touchscreen and the Mac at the power strip. They'll
  come back automatically next time the strip is energised.
- Wipe the touchscreen with a damp soft cloth or pre-moistened wet
  wipe (no abrasive cloths; no paper towels).

### 6.3 Troubleshooting

| Symptom | Fix |
|---|---|
| Black touchscreen, kiosk Mac is on | Verify HDMI cable is seated at both ends and the touchscreen is powered. |
| Mac desktop visible instead of the kiosk | Force-quit Chrome (`⌘+⌥+Esc`); LaunchAgent relaunches within 10 s. |
| Chrome "Restore session?" prompt visible | `rm -rf ~/.kiosk-app1-profile` (or `app2`), then reboot. |
| App 2 has red dashed boxes over chapter buttons | `debug: true` is still set in `app2-chapters/config.js` — change to `false` and reload. |
| Update notification pops up | macOS notifications weren't fully muted (§2.5). Fix it during downtime. |
| Video plays but you hear nothing | **By design** — kiosk video is muted. (Browsers also block autoplay of un-muted video.) |
| Kiosk doesn't auto-start after a reboot | Auto-login isn't on (§2.2), or the project folder moved (re-run `./kiosk/install.sh app1`). Check `kiosk/app1.err.log`. |
| `kiosk/app1.err.log` (or app2) says "Operation not permitted" | Project lives in a TCC-protected folder (`~/Documents/`, `~/Desktop/`, `~/Downloads/`, `~/Pictures/`, `~/Movies/`, `~/Music/`). LaunchAgents can't read scripts from these. Move the project to `~/` (or anywhere else outside the protected list) and re-run `./kiosk/install.sh app1`. See §3.1 for the full list. |
| `./kiosk/update.sh` says "not a git repo" | Project was downloaded as a zip rather than cloned. Re-clone per §3.1 (back up `app1-slideshow/config.js` and `app2-chapters/config.js` first if you've edited them). |
| `./kiosk/update.sh` says "local changes detected" | Someone edited a file on the kiosk Mac directly. Either save the change properly (`git stash` to set aside, can be restored), or discard with `git checkout -- .` (destructive — permanent). |

### 6.4 Exiting kiosk mode for service
Two ways:
1. `⌘+⌥+Esc → Google Chrome → Force Quit` (LaunchAgent will relaunch in ~10 s — if you want it to stay closed:
   `launchctl unload ~/Library/LaunchAgents/com.intersolar.app1.plist`).
2. To re-enable: `launchctl load -w ~/Library/LaunchAgents/com.intersolar.app1.plist`.

To uninstall the auto-launch entirely:
```bash
./kiosk/install.sh uninstall app1
```
