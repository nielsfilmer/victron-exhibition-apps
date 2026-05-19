# Intersolar TV Apps

Three standalone HTML kiosk apps for touchscreen TVs at the Intersolar exhibition,
plus scripts to boot a Mac into any of them in Chrome kiosk mode.

> ## Runtime environment
>
> **This is a local-only app. It is designed to run fully offline on the
> latest version of Google Chrome.** Once a folder is on the kiosk Mac, no
> internet connection is required — there are no CDN fonts, no remote
> assets, no analytics, and no runtime `fetch()` calls. Both apps target
> the current stable Chrome release on macOS Sequoia (15.x); older
> browsers and other engines are not supported and not tested.
>
> Any code review or future change must preserve this principle: zero
> network calls at runtime, no build step, no server.

```
intersolar-tv-apps/
├── app1-slideshow/      # Slideshow with countdown + pause (Victron-styled)
│   ├── index.html
│   ├── config.js
│   ├── fonts/           # museosans-700.ttf (self-hosted, no network calls)
│   └── media/           # sinus-bg.svg + slide-1..5.jpg (4K placeholders)
├── app2-chapters/       # Fullscreen video with invisible hotspot buttons
│   ├── index.html
│   ├── config.js
│   └── media/           # main.mp4 (placeholder)
├── app3-multi-screen/   # 3-screen synced slideshow (center has controls)
│   ├── index.html
│   ├── config.js
│   ├── fonts/
│   └── media/           # slide-N-{left,middle,right}.jpg
├── Install App 1.command   # double-click in Finder → install App 1 kiosk
├── Install App 2.command   # double-click in Finder → install App 2 kiosk
├── Install App 3.command   # double-click in Finder → install App 3 (4 LaunchAgents)
├── Update.command          # double-click in Finder → pull latest code + reload
├── Update media.command    # double-click in Finder → download latest content zip (media + config) + reload
└── kiosk/
    ├── launch-app1.sh
    ├── launch-app2.sh
    ├── launch-app3-center.sh / launch-app3-left.sh / launch-app3-right.sh
    ├── launch-app3-ws.sh    # tiny WebSocket relay that syncs the 3 App 3 windows
    ├── app3-displays.env    # operator-editable display geometry for App 3
    ├── com.intersolar.app1.plist
    ├── com.intersolar.app2.plist
    ├── com.intersolar.app3-ws.plist
    ├── com.intersolar.app3-center.plist / app3-left.plist / app3-right.plist
    ├── ws-relay/            # Go source + build.sh for the App 3 sync relay
    ├── bin/                 # prebuilt arm64 + x86_64 relay binaries (committed)
    ├── install.sh           # one-shot LaunchAgent install / uninstall
    ├── update.sh            # pull latest code from GitHub + reload the kiosk
    ├── content-update.sh    # download content zip from content-team URL → replace each app's media/ + config.js, reload
    ├── content-url.txt      # one-line URL the content team gives you
    └── INSTALL.md           # full kiosk-Mac + touchscreen setup + show-floor ops
```

> **Setting up a fresh kiosk Mac, configuring the touchscreen, or
> handing the install to a non-developer Victron staffer?** Use
> [`kiosk/INSTALL.md`](./kiosk/INSTALL.md) — that's the operational
> manual (hardware checklist, macOS setup, daily start/stop
> procedure, troubleshooting). This `README.md` covers the **app
> internals** (config schema, slide variants, animation timings).

Each app folder is self-contained: drop the folder anywhere on the kiosk Mac
and open `index.html` in Chrome — no build step, no server.

> **Note:** `app1-slideshow/media/slide-*.jpg` are placeholder photos from
> picsum.photos (random landscape photography); `app1-slideshow/media/sample-video.mp4`
> and `app2-chapters/media/main.mp4` are both the Sintel trailer (Blender
> Foundation, CC). Swap them for production assets before the show.

---

## App 1 — Slideshow with Countdown + Pause

Implements the UX from
[Figma 6428-12557](https://www.figma.com/design/roKcuVfDcxoY3PFMvJQ3UX/.com---Dev-Ready?node-id=6428-12557).

**Layout** — each slide carries a `variant` that positions the image and text:

| `variant` | Media (image or video) | Text | Sinus bg | Figma |
|---|---|---|---|---|
| `default` (omitted) | Right (~63% wide, centered) | Top-left (443 px) | Yes | [6428:12910](https://www.figma.com/design/roKcuVfDcxoY3PFMvJQ3UX/.com---Dev-Ready?node-id=6428-12910) |
| `large-image` | Right, larger (68% wide, sharp corners — deviates from Figma's 24 px radius per stakeholder direction) | Top-left | Yes | [6428:13078](https://www.figma.com/design/roKcuVfDcxoY3PFMvJQ3UX/.com---Dev-Ready?node-id=6428-13078) |
| `text-right` | Left (mirror of default) | Top-right (left=1368 px) | Yes | [6437:465](https://www.figma.com/design/roKcuVfDcxoY3PFMvJQ3UX/.com---Dev-Ready?node-id=6437-465) |
| `fullscreen` | Fills the whole screen | none | **No** (hidden via opacity transition) | — |

All four variants share the controls cluster (back / `current/total` / next +
countdown ring / pause) in the bottom-left.

**Controls cluster** — anchored bottom-left by default; flip to bottom-right with `controlsAlign: "right"` in the config. The button order (left → right) is preserved either way:
- **Back** circle button — previous slide (wraps from slide 1 to last).
- **Pagination text** — `current / total` (e.g. `3 / 5`).
- **Next** circle button with a **countdown ring** drawn around it. The ring
  fills from empty → full over `autoAdvanceMs`; when it completes the slide
  auto-advances. Manual back/next resets the ring to empty and starts again.
- **Pause** button — toggles auto-advance. While paused the ring freezes at
  its current position. After `pauseMinutes` the app auto-resumes and the
  countdown starts over from empty. Tap pause again to resume early.

All slide text is non-selectable (CSS `user-select: none` plus
`selectstart`/`dragstart` blocking) so kiosk users can't accidentally
highlight or copy anything.

**`config.js`** (loaded by `index.html` via a `<script>` tag — works over plain `file://`, no server needed)
```js
window.APP_CONFIG = {
  slideshow: {
    images: [
      {
        src:   "media/slide-1.jpg",
        title: "Solar energy at scale",
        body:  "Victron MPPT charge controllers extract every available watt..."
      },
      {
        src:   "media/slide-2.jpg",
        title: "Inverters built to last",
        body:  "MultiPlus and Quattro inverter/chargers seamlessly switch..."
      }
    ],
    autoAdvanceMs: 8000,
    transitionMs:  700
  },
  pauseMinutes:  5,
  controlsAlign: "left"
};
```

| Field | Meaning |
|---|---|
| `slideshow.images[]` | Any number of `{src, variant?, loop?, autoAdvanceMs?, title?, subtitle?, body?}` objects. `src` can be either an **image** (`.jpg`/`.png`/`.svg`/etc.) or a **video** (`.mp4`/`.webm`/`.ogg`/`.m4v`/`.mov`) — the renderer auto-detects by file extension. Videos are muted, play from frame 0 the moment the slide becomes current, and pause as soon as it leaves (so nothing plays in the background). `loop` (videos only, default `true`) — set `false` to play once and stop on the last frame. `variant` selects one of the four layouts above (defaults to `default`). `title` is the leading bold portion of the headline (100% white); `subtitle` is rendered inline at 80% white as a continuation. `body` is the paragraph below. All text fields are ignored on the `fullscreen` variant. |
| `slideshow.images[].autoAdvanceMs` | _Optional, per slide._ Overrides `slideshow.autoAdvanceMs` for this slide only. Useful when one slide should linger longer than the rest (e.g. a busy diagram or a longer video clip). Set to `0` to make the slide stay until the viewer navigates manually. |
| `slideshow.autoAdvanceMs` | Default duration of the countdown ring; how long until the slide auto-advances (default `8000`). Individual slides can override this via `images[].autoAdvanceMs`. |
| `slideshow.transitionMs` | Crossfade duration between slides (default `700`). |
| `pauseMinutes` | Minutes to keep the slideshow paused after the pause button is pressed (default `5`). After this elapses the countdown starts over from empty. Set to `0` to keep paused indefinitely until manually resumed. |
| `controlsAlign` | `"left"` (default) or `"right"`. Pins the controls cluster to the bottom-left or bottom-right of the screen. The button order is preserved either way. When set to `"right"`, the `large-image` variant auto-flips its image to the left edge so the controls don't sit on top of it. |

---

## App 3 — Synced 3-Screen Slideshow

**Behaviour**
- Three Chrome `--kiosk` instances, one per display (center / left / right).
- All three show fullscreen photos or videos (`object-fit: cover`).
- The **center** display also hosts the controls cluster from App 1
  (back / pagination / next + countdown ring / pause) and is the only
  touchscreen / input device.
- Every slide change on the center is **broadcast to the left + right
  instances** via a tiny localhost-only WebSocket relay so all three
  screens stay in lockstep. Pause, swipe, and auto-advance are all
  authoritative on the center; satellites just mirror what they're
  told.

**Architecture**
- Three separate Chrome `--kiosk` processes (one per display, each
  with its own `--user-data-dir`) — needed because `--kiosk` only
  covers one display at a time on macOS.
- One small Go binary (`kiosk/bin/kiosk-ws-relay-{arm64,x86_64}`,
  ~5 MB, committed to the repo) listens on `127.0.0.1:8743` and
  rebroadcasts each message to all OTHER connections. Source +
  `build.sh` live in `kiosk/ws-relay/`.
- The relay caches the last message and replays it to new connects,
  so a late-joining satellite immediately catches up to the center's
  state without waiting for the next broadcast.
- This is a documented exception to the "no server requirement" rule
  in `CLAUDE.md` — see the hard-constraints section there.

**`config.js`** (loaded by `index.html` via a `<script>` tag — works over plain `file://`, no server needed)
```js
window.APP_CONFIG = {
  slideshow: {
    images: [
      { left: "media/slide-1-left.jpg", middle: "media/slide-1-middle.jpg", right: "media/slide-1-right.jpg" },
      { left: "media/slide-2-left.jpg", middle: "media/slide-2-middle.mp4", right: "media/slide-2-right.jpg", autoAdvanceMs: 12000 },
    ],
    autoAdvanceMs: 8000,
    transitionMs:  700,
  },
  pauseMinutes:  5,
  controlsAlign: "right",
  debug:         false,
  wsUrl:         "ws://127.0.0.1:8743/ws",
};
```

| Field | Meaning |
|---|---|
| `slideshow.images[]` | Any number of `{left, middle, right, loop?, autoAdvanceMs?}` objects. Each side is independently auto-detected as image or video by file extension (so left can be a video while middle is an image). |
| `slideshow.images[].loop` | _Videos only._ Applies to all three sides of that slide. Default `true`. |
| `slideshow.images[].autoAdvanceMs` | _Optional per-slide override_ of the global `slideshow.autoAdvanceMs`. `0` = stay until manual navigation. |
| `slideshow.autoAdvanceMs` / `transitionMs` / `pauseMinutes` / `controlsAlign` / `debug` | Same semantics as App 1. The controls cluster only ever renders on the center role. |
| `wsUrl` | WebSocket relay address. Default `ws://127.0.0.1:8743/ws` — only change if you also change the `-addr` flag in `kiosk/launch-app3-ws.sh`. |

**Setup** — three displays, one Mac, one WebSocket relay binary.
See [`kiosk/INSTALL.md` §3.7](./kiosk/INSTALL.md#37-app-3--multi-screen-setup-do-this-before-kioskinstallsh-app3)
for the hardware checklist and the seven-step macOS arrangement
procedure that must happen BEFORE `./kiosk/install.sh app3`.

---

## App 2 — Chapter Hotspots over Fullscreen Video

**Behaviour**
- Single fullscreen video (`object-fit: cover`).
- N invisible buttons overlaid in the top-left corner. Each jumps the video to
  a `timestamp` (in seconds) when tapped.
- Designed against a reference resolution (`designWidth`/`designHeight`) and
  positioned in `%` of viewport — works on any TV size, the buttons stay
  locked to their visual targets in the video.

**Calibrating the hotspots**

Set `debug: true` in `config.js`. The hotspots become red dashed
rectangles with their label and target timestamp, and a HUD in the bottom-left
shows the live video time, design size and viewport size. Once you have the
right coordinates, set `debug: false`.

**`config.js`** (loaded by `index.html` via a `<script>` tag — works over plain `file://`, no server needed)
```js
window.APP_CONFIG = {
  video: "media/main.mp4",
  loop: true,
  muted: true,
  designWidth: 3840,
  designHeight: 2160,
  debug: false,
  buttons: [
    { x: 80, y: 80,  width: 480, height: 220, timestamp: 0,  label: "Chapter 1" },
    { x: 80, y: 340, width: 480, height: 220, timestamp: 12, label: "Chapter 2" }
  ]
};
```

| Field | Meaning |
|---|---|
| `designWidth` / `designHeight` | Reference resolution the `x/y/width/height` are expressed in (default 4K — works on 1080p too via `%` scaling). |
| `debug` | Show hotspot outlines + a HUD with live video time. |
| `buttons[]` | Any number of hotspots. `x/y/width/height` in pixels at the design resolution. `timestamp` in seconds. `label` is optional, used for `aria-label` and the debug overlay. |

---

## Local development

Just open the HTML in Chrome with a `file://` URL — both apps are pure
HTML/CSS/JS with no build step. To rebuild the slide content or swap the
video, drop new files in `media/` and update `config.js`.

If Chrome blocks autoplay during testing, click the page once (the kiosk
launcher script passes `--autoplay-policy=no-user-gesture-required` so this
isn't an issue in production).

---

## Mac kiosk setup

Full step-by-step Mac + touchscreen + show-floor-operations manual lives in
[`kiosk/INSTALL.md`](./kiosk/INSTALL.md). It's the single source of truth
for: hardware checklist, macOS setup (auto-login, power-failure restart,
display resolution, notifications), `./kiosk/install.sh` usage,
hardware connections, daily start/close, and troubleshooting.

This file (`README.md`) covers the **app internals** — config schema, slide
variants, animation timings — and intentionally doesn't duplicate the ops
manual to avoid drift between the two.
