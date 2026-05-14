# Intersolar TV Apps

Two standalone HTML kiosk apps for touchscreen TVs at the Intersolar exhibition,
plus scripts to boot a Mac into either app in Chrome kiosk mode.

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
└── kiosk/
    ├── launch-app1.sh
    ├── launch-app2.sh
    ├── com.intersolar.app1.plist
    ├── com.intersolar.app2.plist
    ├── install.sh
    └── INSTALL.md          # full kiosk-Mac + touchscreen setup + show-floor ops
```

> **Setting up a fresh kiosk Mac, configuring the touchscreen TV, or
> handing the install to a non-developer Victron staffer?** Use
> [`kiosk/INSTALL.md`](./kiosk/INSTALL.md) — that's the operational
> manual (hardware checklist, iiWare TV settings, daily start/stop
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
display resolution, notifications, fonts), `./kiosk/install.sh` usage,
Iiyama iiWare TV configuration, daily start/close, and troubleshooting.

This file (`README.md`) covers the **app internals** — config schema, slide
variants, animation timings — and intentionally doesn't duplicate the ops
manual to avoid drift between the two.
