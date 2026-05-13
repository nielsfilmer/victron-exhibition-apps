# Claude project notes — Victron exhibition apps

Persistent context for future Claude sessions on this repo. Read this first
before making changes.

---

## Workflow (mandatory)

Every task ends with a pull request. Do **not** push directly to `main`.

1. **Work on a feature branch** — branch off `main` with a short
   descriptive name (e.g. `add-fullscreen-variant`, `fix-countdown-drift`).
2. **Commit and push the branch**, then open a PR against `main` via
   `gh pr create`. Title is concise; description summarises the change
   and lists anything the reviewer should pay extra attention to.
3. **Spawn a senior-developer review agent.** Use the `Agent` tool with
   subagent_type `general-purpose`, and frame it as a senior developer
   doing code review on the PR. The agent **must** be given the project
   goals (see below) so its review weighs them. Have it post review
   comments to the PR itself with `gh pr review --comment` /
   `gh pr review --request-changes` so the user sees the same record.
4. **Address every amendment** the review agent raises before notifying
   the user. Push follow-up commits to the same PR branch; do not open
   a second PR for review fixes.
5. **Notify the user** when the PR is clean and ready for human review
   and merge. Do **not** merge the PR yourself — the user is the
   merge gate.

A reasonable review prompt template:

```
You are a senior developer doing a code review on PR #N of
nielsfilmer/victron-exhibition-apps. Read the diff via `gh pr diff N`,
the full changed files for context, and CLAUDE.md (project goals).

Critically evaluate the change against these project constraints:
- The kiosk must run 100% offline from file:// — no network calls.
- Both apps must work as standalone folders that can be copied onto
  a Mac without a build step.
- The design source of truth is the linked Figma; deviations need a
  good reason.
- Layout scales linearly from 1080p to 4K via vw-based sizing.
- Slide text is never selectable / draggable / copyable.
- Each app is configured by editing its `config.js` only.

Output: PR review comments via `gh pr review` covering correctness,
adherence to the constraints above, regressions, and any code-quality
nits worth fixing now. Don't approve unless the change is genuinely
clean — flag issues even if they're minor.
```

---

## What this project is

Two standalone HTML kiosk apps for touchscreen TVs at an exhibition stand,
plus scripts that boot a Mac into either app in Chrome kiosk mode.

- `app1-slideshow/` — Victron-branded slideshow with four layout variants,
  countdown ring + pause button, line-by-line title animation.
- `app2-chapters/` — fullscreen video with invisible hotspot buttons that
  jump to per-button timestamps. Debug overlay for hotspot calibration.
- `kiosk/` — `launch-app{1,2}.sh`, `com.intersolar.app{1,2}.plist`,
  `install.sh`. Templates `__PROJECT_DIR__` into the plists and loads
  them as a user LaunchAgent so the kiosk auto-starts on login.

## Hard project constraints

These came from the user explicitly and shape every decision:

1. **100% offline.** The kiosk runs from `file://` on a Mac with no
   guaranteed internet. Don't fetch anything from the network at runtime.
   - No CDN fonts (Museo Sans is self-hosted at
     `app1-slideshow/fonts/museosans-700.ttf`).
   - No `fetch('config.json')` — Chrome blocks `fetch` over `file://`.
     Configs are loaded via `<script src="config.js">` which sets
     `window.APP_CONFIG`.
   - Verify with `grep -nE 'https?://' index.html config.js`. The only
     `http://` that's allowed anywhere is the W3C SVG namespace URI
     (`xmlns="http://www.w3.org/2000/svg"`) — that's an XML identifier,
     not a fetch.
2. **Standalone folders.** Each app folder must be copy-pasteable onto
   a fresh Mac and "just work" by opening `index.html` in Chrome. No
   build step, no `npm install`, no server.
3. **Configurable only via `config.js`.** Non-developers should be able
   to swap slide content / hotspot coordinates / pause duration without
   touching HTML, CSS, or JS.
4. **4K primary, 1080p secondary.** Layouts target 3840×2160 first but
   must scale linearly down to 1920×1080. Done via vw-based sizing
   (width-based units even for vertical dimensions) so the design's
   1920×1080 pixel values map to vw cleanly.
5. **Non-selectable everything.** Kiosk users can't be allowed to
   accidentally highlight text, drag images, or open context menus.
   See "Common pitfalls" below for the enforcement pattern.

## Design source of truth

Figma file `roKcuVfDcxoY3PFMvJQ3UX` ( `.com - Dev Ready`). Active nodes
referenced in this project:

| Node | Variant | Notes |
|---|---|---|
| 6428:12910 | `default` | Image right, text left |
| 6428:13078 | `large-image` | Image flushed right, rounded corners, text left |
| 6437:465 | `text-right` | Mirror of default |

Fetch with the Figma MCP server (`mcp__8c512e67-...__get_design_context` /
`...__get_screenshot`) using `fileKey: "roKcuVfDcxoY3PFMvJQ3UX"`.

The Victron design system file (referenced earlier in the build) is
`8rfkB14GPsDYazeC8Uoqhw`.

---

## App 1 architecture (key decisions)

- **One `.slide` container per slide.** Each carries a `variant-*` class
  (`variant-default` / `variant-large-image` / `variant-text-right` /
  `variant-fullscreen`) that positions the inner image + text. Only one
  slide has `.is-current` at any time; image fade and text stagger live
  on inner elements so crossfades stay clean across variant changes.
- **CSS variants drive layout.** Image position, text position, and
  sinus visibility are determined by the variant class on `.slide`. The
  `fullscreen` variant fades out the sinus via
  `body.fullscreen-current #sinus-bg { opacity: 0 }`.
- **Image position for small variants** (`default` and `text-right`)
  is centered in the *space above the controls cluster* — not the full
  viewport. The calc is
  `top: calc((100vh - var(--controls-zone) - var(--img-h)) / 2)` where
  `--controls-zone = pad-edge + btn-size = 7.5vw`. This guarantees the
  image bottom clears the controls top at any viewport height.
  Using a literal Figma top (e.g. `3.698vw`) instead of the calc breaks
  at viewport heights below the design height — the image then sits
  behind the controls.
- **Title is split into per-word `<span class="word">` spans** during
  build. After `document.fonts.ready` resolves, words are grouped into
  lines by their `getBoundingClientRect().top` and each word gets a
  CSS `--delay` based on its line. The body gets a single delay = end
  of the last line's transition. The cascade is
  `.slide.is-current .slide-text .word { transition-delay: var(--delay); }`
  — note the `.is-current` lives on the slide *container*, not on
  `.slide-text` itself (this caused a regression — see "Common pitfalls").
- **Countdown ring** — single SVG `<circle>` with stroke-dasharray =
  circumference. JS const `RING_R` **must match** the `<circle r="…">`
  attribute in the markup or the dasharray won't fully cover the path
  and a partial arc is visible at fraction 0 (the "drift" bug).
- **Swipe** is bound to the whole `#stage` element with pointerId
  tracking. Threshold: `max(60px, 4% of viewport width)`, max duration
  600 ms, requires `|dx| > 1.2 × |dy|`. Control buttons stop
  propagation so a tap on a button doesn't arm a swipe.

## App 2 architecture

- Single `<video>` filling the viewport with `object-fit: cover`.
- Hotspots are absolutely-positioned `<button>` elements layered on top.
  Coordinates in `config.js` are expressed at the `designWidth /
  designHeight` reference resolution; they're rendered as percentages of
  the viewport so they stay locked to the visible video regardless of
  display resolution.
- `debug: true` in `config.js` outlines the hotspots and shows a HUD
  with the current video time — used during setup to calibrate
  coordinates against the real production video.
- No text, no font dependencies, no countdown — much simpler than App 1.

---

## Common pitfalls (encountered in this build — don't redo them)

1. **`<circle r>` and the JS `RING_R` constant must match.** They drove
   the countdown's start-state drift bug. If you change the radius in
   the SVG, change it in JS too.
2. **`.is-current` lives on `.slide` (the container), not on
   `.slide-text`.** Any selector that targets `.slide-text.is-current`
   will silently fail and text will never appear. Use
   `.slide.is-current .slide-text …` instead.
3. **Don't `fetch('config.json')` over `file://`.** Chrome blocks it.
   Use `<script src="config.js">` + `window.APP_CONFIG`.
4. **Don't inline the sinus SVG by hand.** The real asset has 12 wave
   paths; hand-copying frequently drops paths. Load the file via
   `<img src="media/sinus-bg.svg">` so the on-disk asset stays the
   single source of truth.
5. **Don't use a fixed-pixel `top` on small-image variants.** It only
   works at exactly 1080 viewport height. Use the
   centered-above-controls calc (see above).
6. **Use `vw` for vertical dimensions too**, not `vh`. The design is
   16:9 and the production targets are all 16:9; using `vw` everywhere
   keeps proportions locked to the 1920×1080 design pixel values.
   Mixing `vh` causes proportions to drift on non-16:9 dev viewports.
7. **Don't use `clamp(min, vw, max)` floors/ceilings on font sizes for
   this kiosk.** They break linear scaling at 4K. Pure `vw` values
   scale linearly from 1080p to 4K.
8. **Block all the right events for non-selectability.** Setting
   `user-select: none !important` on `body, body *` is the first line
   of defence, but you also need `selectstart`, `dragstart`, and
   `contextmenu` listeners that `preventDefault()`, plus
   `draggable="false"` on `<img>` tags and `-webkit-touch-callout: none`.

## Useful commands

```bash
# Find anything fetching from the network
grep -nE 'https?://' app1-slideshow/index.html app1-slideshow/config.js \
                      app2-chapters/index.html  app2-chapters/config.js

# Check the build runs at 1920×1080 in a fresh Chrome profile
open -na "Google Chrome" --args \
  --kiosk --autoplay-policy=no-user-gesture-required \
  --user-data-dir=/tmp/kiosk-test \
  --app="file://$PWD/app1-slideshow/index.html"

# Install the LaunchAgent that boots a Mac into App 1
./kiosk/install.sh app1
```

## File map (quick orientation)

```
intersolar-tv-apps/
├── README.md                  # user-facing setup docs
├── CLAUDE.md                  # this file — context for Claude
├── .gitignore                 # excludes .DS_Store, .claude/, *.zip, kiosk logs
├── app1-slideshow/
│   ├── index.html             # all CSS + JS inlined; loads config.js as <script>
│   ├── config.js              # window.APP_CONFIG = { slideshow: {...}, pauseMinutes }
│   ├── fonts/museosans-700.ttf
│   └── media/                 # sinus-bg.svg + slide-{1..5}.jpg (placeholders)
├── app2-chapters/
│   ├── index.html
│   ├── config.js              # window.APP_CONFIG = { video, buttons[…], debug }
│   └── media/main.mp4         # placeholder Sintel trailer (replace for production)
└── kiosk/
    ├── launch-app1.sh         # exec'd by LaunchAgent; opens Chrome --kiosk
    ├── launch-app2.sh
    ├── com.intersolar.app1.plist
    ├── com.intersolar.app2.plist
    └── install.sh             # templates plist paths + launchctl loads
```
