# Victron Exhibition Kiosk — Install Guide

A short, plain-language guide for getting a kiosk app onto a Mac:
**download → install → update → remove.** No developer tools and no
Git are required — each app ships as a ready-made `.zip` you download,
unzip, and double-click to install.

> **Need the full manual?** This guide covers the day-to-day app
> lifecycle only. For the complete setup — kiosk hardware, the
> one-time macOS configuration (auto-login, sleep, notifications,
> displays), the App 3 three-screen arrangement, and show-floor
> troubleshooting — see [`kiosk/INSTALL.md`](./kiosk/INSTALL.md).
> Prepare a brand-new Mac with that first; come back here for
> installing, updating, and removing the apps.

---

## The five apps

You download **one** zip per kiosk. Pick the one you need:

| Download | App | What it is |
|---|---|---|
| `app1-ess.zip` | App 1 — **ESS** content | Single-screen slideshow (countdown + pause), ESS content |
| `app1-ol.zip` | App 1 — **OL** content | Same slideshow, OL content |
| `app1-microgrid.zip` | App 1 — **Microgrid** content | Same slideshow, Microgrid content |
| `app2.zip` | App 2 | Single-screen fullscreen video with tappable chapter areas |
| `app3.zip` | App 3 | Three synced screens, fullscreen photos/videos, no controls |

> App 1 comes in three content versions but only **one runs at a
> time** on a given Mac. Download the version you want to show.

---

## 1. Download

1. Open the project's **GitHub Releases** page:
   <https://github.com/nielsfilmer/victron-exhibition-apps/releases/latest>
2. Under **Assets**, click the zip for the app you want (see the table
   above). It downloads to your `Downloads` folder.

The same files always live at stable links, if you prefer to download
directly:

- `…/releases/latest/download/app1-ess.zip`
- `…/releases/latest/download/app1-ol.zip`
- `…/releases/latest/download/app1-microgrid.zip`
- `…/releases/latest/download/app2.zip`
- `…/releases/latest/download/app3.zip`

(Prefix each with
`https://github.com/nielsfilmer/victron-exhibition-apps`.)

Each zip is stamped with the exact build it came from — see
`VERSION.txt` inside the unzipped folder if you ever need to confirm
which version is installed.

---

## 2. Install

### Step 1 — Unzip in the right place

Double-click the downloaded zip to unpack it. Then **move the unzipped
folder somewhere under your home folder** — for example
`/Users/<you>/app2`.

> ⚠ **Do NOT install from `Downloads`, `Documents`, `Desktop`,
> `Pictures`, `Movies`, or `Music`.** macOS protects those folders, and
> the kiosk will silently fail to start at login. The installer will
> **refuse** to run from them and tell you so. The home folder (`~/`)
> itself is fine, as is an external drive under `/Volumes/`.
>
> The `READ ME FIRST.txt` inside every bundle repeats this warning.

### Step 2 — Run the installer

Open the unzipped folder and **double-click the install command** it
contains:

- `Install App 1 - ESS.command` (or OL / Microgrid) — App 1
- `Install App 2.command` — App 2
- `Install App 3.command` — App 3

A Terminal window opens, installs the kiosk, and prints a success
message. Press any key to close it.

> **First time only:** macOS may warn that the file is from an
> *unidentified developer* and refuse to open it. If so: **right-click**
> the `.command` file → **Open** → click **Open** in the dialog. This
> grants permission once, permanently.

> **App 3 needs setup first.** Before installing App 3, plug in and
> arrange the three displays as described in
> [`kiosk/INSTALL.md` §3.7](./kiosk/INSTALL.md#37-app-3--multi-screen-setup-do-this-before-kioskinstallsh-app3).
> Install App 3 only after the displays are arranged.

### Step 3 — Reboot to verify

Restart the Mac. After it logs in automatically, the kiosk app should
appear fullscreen on its own, with no clicking needed. From now on it
starts automatically every time the Mac powers on, and relaunches if
Chrome is ever closed.

> Don't rename or move the folder after installing — the kiosk
> remembers its exact location. If you do need to move it, just run the
> install command again from the new location.

---

## 3. Update

### App update (new code or features)

These zip installs update by **re-downloading**:

1. Download the newer zip for the same app (section 1).
2. Install it the same way (section 2), into the same location.

There is no `Update.command` in these bundles on purpose — that one is
only for the developer Git-based install.

### Content-only refresh (new photos / videos / text)

When the content team sends a refreshed media package (a single zip
URL), you don't need to reinstall the whole app:

1. Open `kiosk/content-url.txt` in any text editor, paste the URL the
   content team gave you on a blank line, and save. (One-time per show.)
2. Double-click **`Update media.command`** in the app folder.

It downloads the package, swaps in the new media and settings, and
restarts the kiosk. The screen goes briefly black, then shows the new
content. Nothing else (the app code, fonts, layout) is touched.

> **Rolling back a bad content drop** and other content-team details
> are covered in [`kiosk/INSTALL.md` §4](./kiosk/INSTALL.md#4-updating-content-during-a-show).

---

## 4. Remove

Removing an app stops it from auto-starting. This step uses **Terminal**
(there's no double-click uninstaller).

1. Open **Terminal** (press **⌘ + Space**, type `Terminal`, press
   **Enter**).
2. Go into the app folder — type `cd ` (with a trailing space), then
   **drag the app folder from Finder onto the Terminal window** (this
   pastes its path), and press **Enter**.
3. Run the matching uninstall command:

   ```bash
   ./kiosk/install.sh uninstall app1     # App 1 (all three versions)
   # or
   ./kiosk/install.sh uninstall app2     # App 2
   # or
   ./kiosk/install.sh uninstall app3     # App 3 (all of its screens + the sync relay)
   ```

The kiosk stops auto-starting immediately. After uninstalling you can
delete the app folder if you no longer need it.

> **Switching to a different app on the same Mac?** Uninstall the
> current one first (above), then install the new one (section 2) —
> otherwise both try to take over the screen. Switching *between App 1
> versions* (ESS ↔ OL ↔ Microgrid) is the exception: installing one
> automatically removes the other two, so you don't need to uninstall
> first.

---

## Something went wrong?

The most common issues and their fixes — kiosk doesn't appear, "Restore
session?" prompt, screens out of sync, "Operation not permitted" in a
log — are all in the troubleshooting table at
[`kiosk/INSTALL.md` §6.3](./kiosk/INSTALL.md#63-troubleshooting).
