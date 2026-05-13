# Claude project notes — Victron exhibition apps

> ## ⚠️ Top-line principle (load-bearing for every change)
>
> **This is a local-only app that must run fully offline on the latest
> version of Google Chrome.** No internet connection at runtime, no CDN
> fonts, no remote assets, no analytics, no `fetch()` calls. The kiosk
> Mac runs the latest stable Chrome on the latest macOS — that's the
> only supported runtime.
>
> Every code review (human or agent-spawned) **must** apply this as the
> primary lens. Any change that introduces a network call, a build
> step, a server requirement, or a dependency on a browser other than
> current-stable Chrome is automatically a blocking issue and must be
> rejected or rewritten — regardless of how convenient it is.

Persistent context for future Claude sessions on this repo. Read this first
before making changes.

> **Naming note.** The local working directory is `intersolar-tv-apps/` and
> the LaunchAgent bundles are `com.intersolar.app{1,2}` for legacy reasons
> (the repo was renamed to `victron-exhibition-apps` after the LaunchAgent
> identifiers and folder name had been baked in). **Do not "fix" the
> `com.intersolar.*` plist labels** — `kiosk/install.sh` looks them up by
> that exact name and renaming would break the auto-boot.

---

## Workflow (mandatory)

Every task ends with a pull request. Do **not** push directly to `main`.

1. **Work on a feature branch** — branch off `main` with a short
   descriptive name (e.g. `add-fullscreen-variant`, `fix-countdown-drift`).
2. **Commit and push the branch**, then open a PR against `main` via
   `gh pr create`. Title is concise; description summarises the change
   and lists anything the reviewer should pay extra attention to.
3. **Spawn a senior-developer review agent.** Use the agent-spawn tool
   exposed by your harness (`Agent` in the current Claude Code build,
   sometimes `Task` in older builds) with `subagent_type: "general-purpose"`,
   and frame it as a senior developer doing code review on the PR. The
   agent **must** be given the project goals (see below) so its review
   weighs them. Have it post review comments to the PR itself with
   `gh pr review N --comment --body "..."` (or `--request-changes` for
   blocking issues — but note GitHub blocks self-review if the agent's
   gh token is the same account as the PR author, so it'll be forced to
   `--comment`; flag any blocking items explicitly in the body in that
   case). The user sees the review on the PR.
4. **Address every amendment** the review agent raises before notifying
   the user. Push follow-up commits to the same PR branch; do not open
   a second PR for review fixes.
5. **Notify the user** when the PR is clean and ready for human review
   and merge. Do **not** merge the PR yourself — the user is the
   merge gate.

A reasonable review prompt template (refers to the canonical constraint
list in this file rather than duplicating it, so the two never drift):

```
You are a senior developer doing a code review on PR #N of
nielsfilmer/victron-exhibition-apps. Read the diff via `gh pr diff N
-R nielsfilmer/victron-exhibition-apps`, the full changed files for
context, and CLAUDE.md in this repo (sections "Hard project constraints"
and "Common pitfalls").

Critically evaluate the change against EVERY constraint and pitfall
listed in those two sections. Treat them as load-bearing — even minor
deviations are worth flagging.

Output: PR review comments via `gh pr review N
-R nielsfilmer/victron-exhibition-apps --comment` (or
`--request-changes` if your gh account is allowed to). Don't approve
unless the change is genuinely clean. If GitHub blocks the
request-changes review (self-review on your own PR), fall back to
`--comment` and flag blocking issues explicitly in the body.
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
  uses the Figma 6437:465 box size (1204×815 → `var(--img-w)`/
  `var(--img-h)`) at 47 px from the appropriate horizontal edge.
  The vertical position is centred in the space above the controls
  cluster:
  `top: calc((100vh - var(--controls-zone) - var(--img-h)) / 2)`
  where `--controls-zone = pad-edge + btn-size = 7.5vw`. So the
  gap above the image equals the gap between image and controls
  top — regardless of viewport height. `large-image` and
  `fullscreen` are unaffected; their positioning is independent.
- **`object-fit` is per-variant.** Default rule on `.slide-img` is
  `cover`, which `large-image` and `fullscreen` use (they're sized
  to dominate the layout, cropping is acceptable). The two
  small-image variants override to `contain` so source images are
  letterboxed, not cropped — the sinus pattern shows through where
  the image doesn't fill the frame. Don't widen the override to all
  variants without an explicit ask.
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
- **Pause behaviour** — `pauseMinutes: 5` keeps the slideshow paused
  for 5 minutes then auto-resumes (countdown restarts from empty per
  spec). `pauseMinutes: 0` is the special case "stay paused until the
  user manually resumes" (the auto-resume `setTimeout` is skipped).
- **Body-text font fallback** — `--font-body` declares `"Inter"` first
  and silently falls back to the system stack on a fresh Mac (Inter
  isn't a macOS system font and isn't bundled). Acceptable visually
  for the body at kiosk viewing distance; if you need an exact match
  to Figma, ship Inter alongside Museo Sans in `app1-slideshow/fonts/`.
- **Image vs video media** — slides accept either; the renderer
  auto-detects by `src` file extension (`VIDEO_EXT` regex in the JS).
  Videos are rendered as `<video muted playsinline loop preload="metadata">`
  so they're cheap to ship many of (only metadata is held per video,
  full data streams from disk on play). On slide-enter the video is
  reset to `currentTime = 0` and `play()` is called; on slide-leave
  `pause()` is called — videos never run in the background. The
  `.slide-img` CSS class is shared by both element types.
- **Per-slide `autoAdvanceMs`** — slides may set their own
  `autoAdvanceMs` to override `slideshow.autoAdvanceMs` for that slide
  only. `effectiveAutoAdvanceMs(i)` returns the per-slide value if it's
  a number, otherwise the global. `0` (or negative) means "stay
  indefinitely until manual navigation" — same semantics as the global.
  The value is captured into `currentMs` at countdown start so a
  mid-flight slide-config change can't drift the in-progress ring.
- **`controlsAlign` global config** — `"left"` (default) or `"right"`.
  JS reads it once at boot and adds `body.controls-right` when set to
  `"right"`. CSS swaps the `left`/`right` anchor on `#controls` via the
  class selector. Cluster order (back → pagination → next → pause) is
  preserved either way. The `large-image` variant **auto-flips** with
  the controls — its image is flushed right by default, but when
  `body.controls-right` is set the same rule pulls the image to the
  left edge instead, so the controls never sit on top of the image.
  Don't add per-image overrides for this; it's a single class-driven
  CSS swap.
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
  coordinates against the real production video. **The checked-in
  `app2-chapters/config.js` currently has `debug: true`** because the
  production video and final coordinates haven't been provided yet.
  **Flip it to `false` before the show** or the kiosk will display
  red calibration outlines over every hotspot.
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
5. **Small-image variants centre vertically above the controls** —
   see the architecture section above. The frame uses the Figma
   6437:465 box size (1204×815), but the vertical position is
   `calc((100vh - var(--controls-zone) - var(--img-h)) / 2)` rather
   than Figma's literal `top: 71px`. This was tried both ways during
   the build: Figma-exact only works at 1920×1080; the calc keeps the
   image clear of the controls and symmetrically padded at any
   viewport height. **Don't replace the calc with a fixed `top`**
   without an explicit ask.
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
9. **Video autoplay needs `muted` AND `playsinline`.** Chrome blocks
   autoplay of any video with sound or without `playsinline` unless
   the user has interacted with the page. The kiosk launcher passes
   `--autoplay-policy=no-user-gesture-required` as a belt-and-braces
   fallback. If you ever add a per-video `muted: false` config option,
   videos will silently fail to autoplay outside the kiosk launcher.
10. **`font-display: block` is intentional.** App 1's `@font-face` for
   Museo Sans uses `font-display: block` and the boot path gates the
   first slide reveal on `document.fonts.ready` (with a 1500 ms safety-
   net `setTimeout`). The trade-off: if the TTF ever fails to load,
   slide 1's words stay invisible until the safety net fires (≤1.5 s),
   then they render in the Inter fallback. This is deliberate — `block`
   avoids a flash of incorrect font (Inter → Museo Sans glyph re-flow),
   and the gate ensures line-wrap measurements happen with the final
   glyph widths so the per-line stagger lands on the right words.

## Useful commands

```bash
# Find anything fetching from the network at runtime. Scoped to the runtime
# HTML/JS only on purpose — broadening to the whole repo would pick up
# README links and the W3C SVG namespace identifier in `sinus-bg.svg`, which
# are not actual fetches.
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

Working-directory name is `intersolar-tv-apps/` (legacy — see naming
note at the top); repo on GitHub is `nielsfilmer/victron-exhibition-apps`.

```
intersolar-tv-apps/             # local folder; repo is victron-exhibition-apps
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
