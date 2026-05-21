# Kiosk install & operations guide

Step-by-step setup for a brand-new touchscreen kiosk (Mac + Iiyama
touchscreen) running App 1, App 2, or App 3. Written for a
non-developer Victron staffer to follow at the show.

> **Already-configured kiosk?** Skip to [Daily operations](#6-daily-operations).
>
> **For details about the apps themselves** (config schema, slide
> variants, animation timings) see the project root [`README.md`](../README.md).
> This file is install / hardware / show-floor operations only.

## Change control

| Author | Summary of changes | Version | Last Updated |
|---|---|---|---|
| Niels Filmer | Initial document — manual for the rewritten kiosk apps (Victron Exhibition Apps). | V1.0 | 14-5-2026 |
| Niels Filmer | Added App 3 (3-screen synced kiosk slideshow + WebSocket sync relay); content-update.sh now also replaces each app's config.js when present in the zip. | V1.1 | 19-5-2026 |
| Niels Filmer | Removed App 3's on-screen controls — the kiosk is now display-only, three fullscreen photos/videos auto-advancing on a config-driven timer (no visitor interaction). None of the three displays needs to be a touchscreen anymore. | V1.2 | 19-5-2026 |
| Peter Coolen | Split App 1 into three content versions — ESS, OL, Microgrid. Each ships its own `config.js` + `media/` under `app1-slideshow/versions/<v>/`; install with the matching `Install App 1 - <Version>.command` (only one App 1 version may run at a time — installing one auto-unloads the other two as siblings). The bulk content updater now writes into the version subfolders. | V1.3 | 21-5-2026 |

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

### 1.1 Extra hardware for App 3 (3-screen synced slideshow)

App 3 spans **three displays**, each showing a fullscreen photo or
video. There are no on-screen controls and no visitor interaction —
the slideshow auto-advances on a config-driven timer, with all three
displays kept in sync by a small local relay. **None of the three
displays needs to be a touchscreen**, since nothing takes input.

| | Recommendation | Notes |
|---|---|---|
| Center / left / right displays | Three displays at the **same resolution**, ideally matching size for visual continuity | Any standard HDMI displays. No touch input needed. |
| Computer | **Apple Mac Mini M2 or newer** | Must have 3 video outputs. The M2 has 1× HDMI + 2× Thunderbolt 4 (each does USB-C → HDMI via a $20 adapter). |
| HDMI cables | 3× | One per display. |
| HDMI adapter | 2× USB-C/Thunderbolt → HDMI | For the two non-HDMI Mac outputs. |

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
it later, re-run the matching install command (e.g.
`./kiosk/install.sh app1-ess`, `app1-ol`, `app1-microgrid`, or
`app2`/`app3`) from the new location to refresh the path.

> ⚠ **Don't clone into `~/Documents/`, `~/Desktop/`, `~/Downloads/`,
> `~/Pictures/`, `~/Movies/`, or `~/Music/`.** macOS protects these
> folders via TCC; LaunchAgents can't read scripts from them and the
> kiosk will silently fail to start at boot ("Operation not permitted"
> in `kiosk/app1-<v>.err.log` for App 1, or `kiosk/app2.err.log`).
> `install.sh` refuses to install if the project is in one of these
> locations. The home directory itself
> (`~/`) is fine, as is anywhere else outside the protected list
> (e.g. an external drive mounted under `/Volumes/`).

### 3.2 Pick which app to run
- **App 1** — slideshow with countdown / pause / variants. Use this
  for product / story marketing screens (single display).
- **App 2** — fullscreen video with invisible chapter buttons.
  Use this for a "press the on-screen image to jump to that section"
  experience (single display).
- **App 3** — synced 3-screen slideshow. All three screens show
  fullscreen photos or videos that auto-advance in unison. No
  on-screen controls; no visitor interaction. Use this for a wide
  cinematic kiosk where three matching photos animate together.
  **Requires the extra hardware in §1.1 and the multi-screen setup
  in §3.7.**

### 3.3 Install the LaunchAgent
**Easy mode (no Terminal needed)** — open the project folder in
Finder (`~/victron-exhibition-apps`) and **double-click**:

- `Install App 1 - ESS.command` — for App 1 with **ESS** content
- `Install App 1 - OL.command` — for App 1 with **OL** content
- `Install App 1 - Microgrid.command` — for App 1 with **Microgrid** content
  (App 1 ships in three content versions — only one may run at a
  time. Installing one auto-unloads the other two as siblings, so
  you can switch versions without uninstalling first.)
- `Install App 2.command` — for App 2 (chapter video)
- `Install App 3.command` — for App 3 (3-screen synced slideshow).
  **Complete §3.7 first** — App 3 needs the 3 displays plugged in
  and arranged in macOS before install.

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
./kiosk/install.sh app1-ess        # for App 1 (ESS content)
# OR
./kiosk/install.sh app1-ol         # for App 1 (OL content)
# OR
./kiosk/install.sh app1-microgrid  # for App 1 (Microgrid content)
# OR
./kiosk/install.sh app2            # for App 2 (chapter video)
# OR
./kiosk/install.sh app3            # for App 3 (3-screen synced slideshow)
```

You should see (for `app1-ess`):

```
Installed and loaded com.intersolar.app1-ess.
Start now:   launchctl start com.intersolar.app1-ess
Logs:        /Users/<you>/victron-exhibition-apps/kiosk/app1-ess.{out,err}.log
```

If instead you see a "**Refusing to install: project lives in a
TCC-protected folder**" error, the project was cloned into one of
the protected locations (see §3.1). Follow the `mv` command shown
in the error to move it out, then re-run the matching install
command (e.g. `./kiosk/install.sh app1-ess`).

What just happened:
- The script templated the project's absolute path into the matching
  plist (`kiosk/com.intersolar.app1-{ess,ol,microgrid}.plist`,
  `app2.plist`, or one of App 3's four),
- Copied the plist to `~/Library/LaunchAgents/`,
- Loaded it via `launchctl` so it runs on every login,
- Set the launch script executable,
- For App 1: unloaded the other two App 1 version agents (only one
  App 1 version may run at a time).

The kiosk will now start automatically at login, restart automatically
if Chrome quits unexpectedly, and write logs to
`kiosk/app1-{ess,ol,microgrid}.{out,err}.log` (App 1) or
`kiosk/app2.{out,err}.log` (App 2).

### 3.4 Reboot to verify
Reboot the Mac. After auto-login, Chrome should come up fullscreen
running the chosen app, no manual interaction needed.

If it doesn't, check `kiosk/app1-{ess,ol,microgrid}.err.log` (or
`app2.err.log`, or App 3's logs) for the reason. The most common
cause is the project folder having moved since `install.sh` ran —
re-run the matching install command (e.g.
`./kiosk/install.sh app1-ess`, `./kiosk/install.sh app2`) to refresh
the path.

### 3.5 Switching between App 1, App 2, and App 3
There's no in-app toggle (each kiosk runs one app at a time). **Always
uninstall the current app before installing a different app type** —
otherwise multiple LaunchAgents are loaded and the apps fight to take
over the foreground. In Terminal:

```bash
./kiosk/install.sh uninstall app1     # or app2, or app3
./kiosk/install.sh app2               # or app1-{ess,ol,microgrid}, or app3
```

Reboot to verify only the new app starts. (Uninstalling `app1` removes
all three App 1 version agents — ESS, OL, Microgrid. Uninstalling
`app3` removes all four of its LaunchAgents: the ws relay + center +
left + right.)

**Switching between App 1 versions (ESS ↔ OL ↔ Microgrid) is
automatic.** Installing any one (via the Finder command or
`./kiosk/install.sh app1-<v>`) auto-unloads the other two App 1
versions as siblings — you don't need to uninstall first. App 2 and
App 3 are NOT auto-unloaded by an App 1 install: only the App 1
versions are treated as mutually exclusive.

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
- Restarts any loaded kiosk LaunchAgent
  (`launchctl kickstart -k`, which kills the running Chrome and
  re-launches it) so the running kiosk picks up the new files
  within a few seconds. The screen will go briefly black during
  the restart.
- Prints the list of new commits applied so the operator sees what
  changed.

If `update.sh` bails out with a "local changes detected" message,
it's because someone edited files on the kiosk Mac directly (e.g.
adjusted slide content in `config.js`). The script tells you the
two options — `git stash` (set them aside, can be restored) or
`git checkout -- .` (discard them, **destructive**).

### 3.7 App 3 — multi-screen setup (do this BEFORE `./kiosk/install.sh app3`)

App 3 runs as **three Chrome `--kiosk` instances** (one per display)
that sync via a tiny localhost-only WebSocket relay. Get the display
hardware and macOS arrangement right first; install second.

**Step 1 — plug in all three displays.** Center display via HDMI to
the Mac's HDMI port; left + right via USB-C/Thunderbolt → HDMI
adapters into the Mac's Thunderbolt ports. Power everything on. No
USB / touch input needed for any of the three displays — App 3 is
display-only.

**Step 2 — arrange the displays in macOS.**
`System Settings → Displays → Arrange…`

In the Arrange pane you'll see three rectangles representing the
displays. Drag them so they sit in a row left → center → right,
edges flush. The order in the pane must match the physical layout
on your stand (the kiosk uses the screen-to-screen coordinates to
decide which Chrome window opens on which display).

**Step 3 — make the CENTER display the Main Display.** Still in the
Arrange pane: at the top of the center rectangle there's a white
strip representing the menu bar. Drag it onto the center rectangle
if it isn't already there. This sets the center display as the macOS
"Main Display" — the kiosk install assumes this. (The "center" role
is the one that runs the auto-advance timer + broadcasts to the
satellites; no controls or input live on any screen.)

**Step 4 — confirm "Use as separate display" mode.** Not mirrored.
Each display should show its own desktop wallpaper, not a copy of
the same one.

**Step 5 — set every display to the same resolution.** Click each
display tile in turn and set Resolution → Scaled → 1920×1080 (or
all three to the same higher resolution if your displays support it
and you've updated `kiosk/app3-displays.env`).

**Step 6 — verify with the default `kiosk/app3-displays.env`.** Open
that file in any text editor. The defaults assume three 1920×1080
displays:

```
DISPLAY_WIDTH=1920
DISPLAY_HEIGHT=1080
CENTER_X=0;  CENTER_Y=0      # main display, top-left at (0,0)
LEFT_X=-1920; LEFT_Y=0       # to the left of center, X is negative
RIGHT_X=1920; RIGHT_Y=0      # to the right of center, X is positive
```

If your displays are a different resolution OR the arrangement isn't
a simple left-center-right row, edit the coordinates accordingly.
Each pair is the top-left corner of that display in macOS's global
display coordinate space. (The Main Display's top-left is always
`(0, 0)`; other displays have negative or positive coordinates
depending on whether they're to the left or right.)

**Step 7 — install.** Now double-click `Install App 3.command` (or
run `./kiosk/install.sh app3` in Terminal). The script will install
**four** LaunchAgents:

- `com.intersolar.app3-ws` — the WebSocket sync relay (localhost only)
- `com.intersolar.app3-center` — Chrome on the center display
- `com.intersolar.app3-left` — Chrome on the left display
- `com.intersolar.app3-right` — Chrome on the right display

After install, reboot to verify all four come up automatically.

**If a satellite (left or right) lands on the wrong display** after
reboot:
1. Confirm the System Settings → Displays → Arrange layout matches
   the kiosk-Mac's physical setup (Step 2).
2. Confirm the center display is the Main Display (Step 3).
3. Confirm the coordinates in `kiosk/app3-displays.env` match the
   arrangement (Step 6).
4. Restart the kiosk: `./kiosk/update.sh` (it pulls + restarts).

**If the three displays show the same slide but out of sync** (e.g.
left is one ahead, right is one behind): the WebSocket relay isn't
running. Check `kiosk/app3-ws.err.log` and confirm the relay binary
is executable: `ls -l kiosk/bin/kiosk-ws-relay-*`.

---

## 4. Updating content during a show

### 4.1 Bulk update from a content-team zip (Easy mode)
When the content team ships a refreshed media + config package as a
single `.zip`, refresh the kiosk in one step:

**One-time setup (per show):** open `kiosk/content-url.txt` in any
text editor, paste the zip URL the content team sent on a line below
the comments, save.

**Then, every time there's a new package** — in Finder, open the
project folder and **double-click `Update media.command`**. A
Terminal window opens, downloads the zip, replaces:

- the `media/` folder for any app whose `app{N}-…/media/` is in the zip
- the `config.js` for any app whose `app{N}-…/config.js` is in the zip

…deletes the downloaded zip + everything else from the archive, and
restarts the running kiosk so the new content is on screen.

`media/` and `config.js` are independent — the zip may include
either, both, or neither for any given app. Anything missing from
the zip is left untouched on disk.

**Terminal mode** (equivalent):

```bash
./kiosk/content-update.sh
```

The script ONLY touches each app's `media/` folder and `config.js` —
nothing else, even if the zip contains other files under an app
folder. HTML, CSS, fonts, launch scripts, LaunchAgent plists, the
App 3 ws-relay binary, and `kiosk/app3-displays.env` (operator-edited
per-Mac hardware geometry) are never touched. Everything else in the
zip is ignored and cleaned up.

**Recovering from a bad content update:** if the new zip is wrong,
restore the original committed media + config with:

```bash
git checkout -- app1-slideshow/versions/ \
                app2-chapters/{media,config.js} \
                app3-multi-screen/{media,config.js}
```

(`app1-slideshow/versions/` covers all three App 1 version subfolders
in one path; everything else under `app1-slideshow/` —
`index.html`, `fonts/` — is dev / ops scope and isn't touched by the
content updater.)

Then re-run `./kiosk/update.sh` (or double-click `Update.command`)
to reload the kiosk. The kiosk will show its on-screen error overlay
(a full-viewport blue screen — e.g. "config.js did not set
window.APP_CONFIG…", "slideshow.images is empty", or App 3's
"missing or empty wsUrl") if the content team shipped a malformed or
mis-filed `config.js` — any of these is the signal to roll back.

### 4.2 Manual edits — App 1 (slideshow)
App 1 ships in three content versions — `ess`, `ol`, `microgrid` —
each with its own `config.js` and `media/` under
`app1-slideshow/versions/<v>/`. Edit the version that's currently
installed on this Mac (check which is loaded with
`launchctl list | grep com.intersolar.app1-`).

- Slide content (image / video, title, subtitle, body, variant,
  duration, loop): edit `app1-slideshow/versions/<v>/config.js`. Save
  and reload the kiosk (see [§6 Operations](#6-daily-operations) —
  quit Chrome, it auto-relaunches).
- Add a new image: drop the file into
  `app1-slideshow/versions/<v>/media/`, reference its filename from
  `versions/<v>/config.js`. Same for videos (`.mp4`/`.webm`/`.ogg`).
- The other two versions on disk (not currently installed) are
  untouched — leaving room to swap a different version in via
  `./kiosk/install.sh app1-<other-v>` without losing your edits.

### 4.3 Manual edits — App 3 (3-screen synced slideshow)
- Slide content (left/middle/right media per slide, duration, loop):
  edit `app3-multi-screen/config.js`. Save and either reboot the Mac
  or run `./kiosk/update.sh` to restart all four LaunchAgents.
- Drop new images / videos into `app3-multi-screen/media/`, reference
  their filenames from `config.js` under `left:` / `middle:` / `right:`.
- Auto-advance timing: every slide stays for `slideshow.autoAdvanceMs`
  (default 8000 ms) unless it has its own `autoAdvanceMs` override.
  `0` on a slide makes it stay forever — useful only if every slide
  is `0` or if you want the kiosk to hold on a single hero slide.
- Display geometry (resolution, layout): edit
  `kiosk/app3-displays.env` and run `./kiosk/update.sh` to restart.
- The middle screen runs the auto-advance timer and broadcasts each
  slide change to the left + right screens via the local WebSocket
  relay. There are no on-screen controls and no visitor interaction.
  If left/right go out of sync, see §6.3 troubleshooting.

### 4.4 Manual edits — App 2 (chapter video)
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
profile: `rm -rf ~/.kiosk-app1-<v>-profile` (where `<v>` is `ess`,
`ol`, or `microgrid` — the App 1 version that's installed) or
`~/.kiosk-app2-profile`, then reboot.

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
| Chrome "Restore session?" prompt visible | `rm -rf ~/.kiosk-app1-<v>-profile` (where `<v>` = `ess`/`ol`/`microgrid`) or `~/.kiosk-app2-profile`, then reboot. |
| App 2 has red dashed boxes over chapter buttons | `debug: true` is still set in `app2-chapters/config.js` — change to `false` and reload. |
| Update notification pops up | macOS notifications weren't fully muted (§2.5). Fix it during downtime. |
| Video plays but you hear nothing | **By design** — kiosk video is muted. (Browsers also block autoplay of un-muted video.) |
| Kiosk doesn't auto-start after a reboot | Auto-login isn't on (§2.2), or the project folder moved (re-run the matching `./kiosk/install.sh app1-{ess,ol,microgrid}`, or `app2`/`app3`). Check `kiosk/app1-<v>.err.log` (or `kiosk/app2.err.log`, or App 3's logs). |
| `kiosk/app1-<v>.err.log` (or app2/app3) says "Operation not permitted" | Project lives in a TCC-protected folder (`~/Documents/`, `~/Desktop/`, `~/Downloads/`, `~/Pictures/`, `~/Movies/`, `~/Music/`). LaunchAgents can't read scripts from these. Move the project to `~/` (or anywhere else outside the protected list) and re-run the matching `./kiosk/install.sh app1-{ess|ol|microgrid}` (or `app2`/`app3`). See §3.1 for the full list. |
| `./kiosk/update.sh` says "not a git repo" | Project was downloaded as a zip rather than cloned. Re-clone per §3.1 (back up `app1-slideshow/versions/*/config.js` and `app2-chapters/config.js` first if you've edited them). |
| `./kiosk/update.sh` says "local changes detected" | Someone edited a file on the kiosk Mac directly. Either save the change properly (`git stash` to set aside, can be restored), or discard with `git checkout -- .` (destructive — permanent). |
| App 3: left or right display is on the wrong screen | macOS display arrangement doesn't match `kiosk/app3-displays.env`. Re-check §3.7 steps 2-3 (arrangement + Main Display on center) and step 6 (coordinates in displays.env). Then `./kiosk/update.sh`. |
| App 3: left or right shows the wrong slide | WS relay isn't running. Check `kiosk/app3-ws.err.log` (`tail kiosk/app3-ws.err.log`). Confirm the relay binary is executable for your CPU: `ls -l kiosk/bin/kiosk-ws-relay-$(uname -m)`. Restart with `./kiosk/update.sh`. |
| App 3: all three displays show the same slide but it never advances | The center Chrome isn't running (it owns auto-advance). Check `kiosk/app3-center.err.log` and confirm `com.intersolar.app3-center` is loaded: `launchctl list \| grep app3-center`. |
| App 3: blank screen on one of the three displays | That display's Chrome failed to launch. Check the matching `kiosk/app3-{center,left,right}.err.log`. Common cause: the display was disconnected when the kiosk started; reconnect and run `./kiosk/update.sh` to relaunch. |

### 6.4 Exiting kiosk mode for service
Two ways:
1. `⌘+⌥+Esc → Google Chrome → Force Quit` (LaunchAgent will relaunch
   in ~10 s — if you want it to stay closed:
   `launchctl unload ~/Library/LaunchAgents/com.intersolar.app1-<v>.plist`
   for App 1 (where `<v>` is the installed version — `ess`/`ol`/`microgrid`),
   or the matching `app2.plist` / `app3-*.plist`).
2. To re-enable: `launchctl load -w ~/Library/LaunchAgents/com.intersolar.app1-<v>.plist`.

To uninstall the auto-launch entirely:
```bash
./kiosk/install.sh uninstall app1            # all 3 App 1 version agents
# OR
./kiosk/install.sh uninstall app1-ess        # one specific App 1 version (or app1-ol / app1-microgrid)
# OR
./kiosk/install.sh uninstall app2            # or app3
```

(For App 3 this removes all four LaunchAgents — relay + center + left + right.)
