# Kiosk install & operations guide

Step-by-step setup for a brand-new touchscreen kiosk (Mac + Iiyama
touchscreen TV) running App 1 or App 2. Written for a non-developer
Victron staffer to follow at the show.

> **Already-configured kiosk?** Skip to [Daily operations](#daily-operations).
>
> **For details about the apps themselves** (config schema, slide
> variants, animation timings) see the project root [`README.md`](../README.md).
> This file is install / hardware / show-floor operations only.

---

## 1. Hardware

The combination below is what we ship with — these models have been
tested through several shows and meet the kiosk's particular
requirements (4K, capacitive multi-touch, hardware lock for the front
buttons, touch-event behaviour that doesn't trigger pinch-zoom).

| | Recommendation | Why this exact one |
|---|---|---|
| Touchscreen TV | **Iiyama ProLite TE5512MIS** (4K, 55") or newer in the same series | The front power/menu buttons can be hardware-locked from the remote, the touch surface plays nicely with macOS, and the iiWare OS lets us pin HDMI 1 as the start-up channel. |
| Computer | **Apple Mac Mini M2** (8 CPU / 10 GPU, 8 GB / 256 GB) or newer | Mac is **mandatory**: Windows can't reliably disable multi-finger pinch-zoom gestures, which break the kiosk app. |
| Keyboard | Apple Magic Keyboard (any layout) | Needed only for one-time setup and on-site troubleshooting. The kiosk doesn't need it during the show. |
| Mouse | None | The touchscreen IS the input device. |
| Cabling | HDMI cable Mac → TV HDMI 1, USB cable Mac → TV USB | Power: Mac, TV, optional powered USB hub. |

> **Don't substitute a Samsung touchscreen or a Windows PC.** We've
> tried both at previous shows; neither delivers on the combination of
> requirements (front-button lock + touch-without-pinch-zoom).

---

## 2. macOS one-time setup

Do these steps **once** when preparing a fresh Mac. They're independent
of which app (App 1 or App 2) you'll deploy — you'll pick that in step 3.

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
Our app targets 4K (3840×2160) primary, scales linearly down to 1080p
(1920×1080). Set the Mac's display output to match the touchscreen's
native resolution.

`System Settings → Displays → Resolution → Scaled` → pick **3840×2160**
on the Iiyama TE5512MIS. Hover the resolution tiles to see the px
values.

### 2.7 Install Chrome and make it default
The kiosk only ever uses Chrome; making it default avoids any Mac
prompts about which browser to use.

1. Download Chrome from <https://www.google.com/chrome/> and install.
2. Open Chrome → menu → **Settings → Default browser → Make default**.

### 2.8 Install fonts (App 1 only)
App 1 uses Museo Sans 700 for slide titles and Inter for body. Both are
needed for the design to render correctly. Install them by
double-clicking the files in `~/Library/Fonts/`:

- `app1-slideshow/fonts/museosans-700.ttf` (shipped with the project)
- Inter — install separately if you have a license; otherwise the body
  text falls back to the macOS system font (San Francisco), which is
  visually close enough at kiosk distance.

---

## 3. Install the project

### 3.1 Copy the project folder
Copy the entire `intersolar-tv-apps/` folder to the Mac. A common
location is `~/Documents/intersolar-tv-apps/`, but **the folder can
live anywhere** — `kiosk/install.sh` resolves the absolute path on
install. Don't rename the folder after install (or re-run
`install.sh`).

### 3.2 Pick which app to run
- **App 1** — slideshow with countdown / pause / variants. Use this
  for product / story marketing screens.
- **App 2** — fullscreen video with invisible chapter buttons.
  Use this for a "press the on-screen image to jump to that section"
  experience.

### 3.3 Install the LaunchAgent
From the project folder:

```bash
./kiosk/install.sh app1     # OR: ./kiosk/install.sh app2
```

This:
- Templates the project's absolute path into
  `kiosk/com.intersolar.app{1,2}.plist`,
- Copies the plist to `~/Library/LaunchAgents/`,
- Loads it via `launchctl` so it runs on every login,
- Sets the launch script executable.

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
There's no in-app toggle (each kiosk runs one app at a time). To
switch:

```bash
./kiosk/install.sh uninstall app1
./kiosk/install.sh app2
```

(Or vice versa.) Reboot to verify.

---

## 4. Touchscreen TV (iiWare OS) setup

The Iiyama TE-series ships with the iiWare OS. Configure it once with
the TV remote — these settings make the touchscreen behave like a
single-purpose kiosk display rather than a smart-TV.

To open iiWare: press **Input** on the remote, select the **iiWare**
channel.

| Setting path | Value |
|---|---|
| Personal → Screensaver | **Never** |
| Personal → System bar channel settings | **Disable in all channels** |
| Input & Output → Touch sounds | **Off** |
| System → Start up & Shut down → Startup channel | **HDMI 1** |
| System → Start up & Shut down → Standby after startup | **Off** |
| System → Start up & Shut down → Start up logo | **Off** |
| System → Start up & Shut down → Energy saving | **Off** |
| Administrator (password `8428` = VICT) → Wake on LAN | **Off** |
| Administrator → HDMI CEC | **Off** |
| Administrator → Wake on active source | **On** |
| Administrator → Kiosk mode | **None** |
| Top-right "Sun" icon | Swipe right for **max brightness** |

Then:
- Press **green button** on the remote to **lock the front buttons** of
  the touchscreen. Visitors can't power-cycle or open menus from the
  bezel any more. (The button is a toggle — press again to unlock for
  service.)
- Do **not** press the yellow button — that locks the touch surface
  itself, which would break the kiosk.

Test that touch still works after locking the front buttons.

---

## 5. Updating content during a show

### App 1 — slideshow
- Slide content (image / video, title, subtitle, body, variant,
  duration, loop): edit `app1-slideshow/config.js`. Save and reload
  the kiosk (see [§7 Operations](#daily-operations) — quit Chrome,
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

## 6. Hardware connections (each kiosk)

| Cable | From | To |
|---|---|---|
| HDMI | Mac Mini | Touchscreen **HDMI 1** (back) |
| USB | Mac Mini | Touchscreen **USB** (back) — provides the touch input |
| Power | Mac Mini | Wall / power strip |
| Power | Touchscreen | Wall / power strip |

The HDMI 1 channel is what iiWare auto-selects on startup (see §4).

---

## 7. Daily operations

### 7.1 Opening the stand (each touchscreen)
1. Power on the touchscreen with the **red on/off button** on the TV remote (front-aim at the screen).
2. The Mac Mini auto-powers when its power strip comes on (because of `setrestartpowerfailure`). If it didn't, press its on/off button on the back-right.
3. The TV starts on HDMI 1 → the Mac shows the kiosk fullscreen automatically.

If the Mac doesn't appear:
- Press **Input** on the TV remote, select **HDMI 1**.

If the kiosk doesn't appear but the Mac desktop is visible:
1. Force-quit Chrome: `⌘+⌥+Esc → Google Chrome → Force Quit`.
2. The LaunchAgent will relaunch the kiosk within ~10 s (the
   `KeepAlive`/`ThrottleInterval` from the plist).

If Chrome shows "Restore previous session?" — the launch script
auto-strips this on next start. If it persists, delete the kiosk
profile: `rm -rf ~/.kiosk-app1-profile` (or `app2`), then reboot.

### 7.2 Closing the stand
- Power off the touchscreen and the Mac at the power strip. They'll
  come back automatically next time the strip is energised.
- Wipe the touchscreen with a damp soft cloth or pre-moistened wet
  wipe (no abrasive cloths; no paper towels).

### 7.3 Troubleshooting

| Symptom | Fix |
|---|---|
| Black touchscreen, kiosk Mac is on | TV is on a wrong channel — Input → HDMI 1. |
| Mac desktop visible instead of the kiosk | Force-quit Chrome (`⌘+⌥+Esc`); LaunchAgent relaunches within 10 s. |
| Chrome "Restore session?" prompt visible | `rm -rf ~/.kiosk-app1-profile` (or `app2`), then reboot. |
| Kiosk launches but isn't fullscreen | Press `fn+f` on the Mac keyboard to toggle Chrome fullscreen. |
| App 2 has red dashed boxes over chapter buttons | `debug: true` is still set in `app2-chapters/config.js` — change to `false` and reload. |
| Update notification pops up | macOS notifications weren't fully muted (§2.5). Fix it during downtime. |
| App 1's title font looks generic / wrong shape | Museo Sans isn't installed (§2.8). Install the TTF from `app1-slideshow/fonts/`. |
| Video plays but you hear nothing | **By design** — kiosk video is muted. (Browsers also block autoplay of un-muted video.) |
| Kiosk doesn't auto-start after a reboot | Auto-login isn't on (§2.2), or the project folder moved (re-run `./kiosk/install.sh app1`). Check `kiosk/app1.err.log`. |

### 7.4 Exiting kiosk mode for service
Two ways:
1. `⌘+⌥+Esc → Google Chrome → Force Quit` (LaunchAgent will relaunch in ~10 s — if you want it to stay closed:
   `launchctl unload ~/Library/LaunchAgents/com.intersolar.app1.plist`).
2. To re-enable: `launchctl load -w ~/Library/LaunchAgents/com.intersolar.app1.plist`.

To uninstall the auto-launch entirely:
```bash
./kiosk/install.sh uninstall app1
```

---

## 8. Show-floor escalation
If everything above fails, contact the project maintainer (Niels
Filmer, niels@eviloverlord.nl) with:
- Which app (App 1 / App 2)
- Last 50 lines of `kiosk/app{1,2}.err.log`
- A photo of what's actually on the touchscreen
