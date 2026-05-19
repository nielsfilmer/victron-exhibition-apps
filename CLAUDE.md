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
   the user — **including non-blocking nits**. "LGTM with a nit" is
   not done; fix the nit, re-run the review on the new commit, and
   only notify the user once the review comes back fully clean.
   Sub-rules:
   - **Stopping rule — cap at two review rounds.** Prime the
     round-2 reviewer with the round-1 review (paste it into the
     agent's prompt) so it verifies the specific fixes rather than
     re-evaluating from scratch. If round 2 surfaces *new* nits
     that weren't in round 1, notify the user now and mention the
     round-2+ items in the notification. The senior-dev agent
     exists to catch what Claude missed, not for open-ended
     polishing — without this cap, a critically-prompted reviewer
     can spin indefinitely. **The cap is on novel nits, not
     re-attempts**: if round 2 says "you fixed it, but
     inadequately," that's still the round-1 nit — fix it properly
     and re-review (doesn't burn a round).
   - **Code-quality, doc, and naming nits must always be fixed
     without asking** — these are exactly what the reviewer is
     there to catch.
   - **Only bounce back to the user when a nit asks for a
     product/UX decision** — different copy wording shown to
     visitors, different default value, different behaviour
     visible in the kiosk UI. Log output, debug HUDs, internal
     naming, code comments, and developer-facing wording are NOT
     product/UX decisions even if an operator might happen to see
     them — fix without asking. "I might prefer it the other way"
     on a visitor-facing decision is a user call, not Claude's.
   - **Off-topic nits get spawned as a follow-up task or separate
     PR** per "One PR = one concern" — e.g. the reviewer says
     "while we're here, the `caffeinate` orphan in pitfall #15 is
     worth fixing." Mention the spawn in the user notification so
     the nit isn't lost.
   Push follow-up commits to the same PR branch; do not open a
   second PR for review fixes on this PR's stated concern.
5. **Notify the user** when the PR is clean and ready for human review
   and merge. Do **not** merge the PR yourself — the user is the
   merge gate.

### Workflow disciplines (lessons from past sessions)

- **One PR = one concern.** Don't tack an unrelated change onto an
  open PR just because you're already editing nearby files. If the
  follow-up is orthogonal to the PR's stated goal, branch off `main`
  for it. (Got this wrong once during the layout work: bundled the
  image-margin change into the `controlsAlign` PR and had to extract
  it into its own PR after the user called it out.)
- **No personal info in public docs.** Strip names, emails, Apple
  IDs, passwords, and "contact me at…" sections out of any new file
  before opening the PR. Operational contact details belong in a
  separate ops vault, not in the repo. (Got this wrong with an
  early INSTALL.md "Show-floor escalation" chapter.)
- **Update file maps when adding/removing files.** Both `README.md`'s
  project-tree code block and CLAUDE.md's File map section need
  refreshing whenever a file is added to the project root or
  `kiosk/`. PR reviewers have caught this twice.
- **Permissions for the workflow** are configured at
  `.claude/settings.json` (project-scoped) and grant `Bash(git *)`,
  `Bash(gh pr create *)`, `Bash(gh pr review *)`. Don't expect them
  to be granted globally — they're per-project on purpose. If
  permission prompts start interrupting common flows, add the
  pattern to `.claude/settings.json`, not to `~/.claude/settings.json`.

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

Three standalone HTML kiosk apps for touchscreen TVs at an exhibition stand,
plus scripts that boot a Mac into any of them in Chrome kiosk mode.

- `app1-slideshow/` — Victron-branded slideshow with four layout variants,
  countdown ring + pause button, line-by-line title animation.
- `app2-chapters/` — fullscreen video with invisible hotspot buttons that
  jump to per-button timestamps. Debug overlay for hotspot calibration.
- `app3-multi-screen/` — synced 3-screen slideshow. The same HTML file
  runs in three Chrome `--kiosk` instances (one per display); a
  `?role=center|left|right` URL parameter selects which screen's
  media + controls it renders. The center is authoritative and
  broadcasts state to the others via a tiny localhost-only Go
  WebSocket relay (`kiosk/ws-relay/` source, `kiosk/bin/` prebuilt
  binaries). See "App 3 architecture" below + the carve-out in
  "Hard project constraints" for the relay rationale.
- `kiosk/` — `launch-app{1,2}.sh`, App 3's four launch scripts
  (`launch-app3-{ws,center,left,right}.sh`), `com.intersolar.app{1,2}.plist`,
  the four App 3 plists, and `install.sh`. Templates `__PROJECT_DIR__`
  into the plists and loads them as user LaunchAgents so the kiosk
  auto-starts on login.
  `update.sh` pulls the latest `main` from GitHub (fast-forward
  only, refuses on uncommitted local changes or off-main HEAD) and
  uses `launchctl kickstart -k` to KILL + restart the loaded
  LaunchAgent (Chrome doesn't reliably react to SIGTERM in
  `--kiosk` mode, so a plain `unload` + `load` would leave the
  old Chrome running and the operator wouldn't see the update —
  `kickstart -k` is bullet-proof).
- `kiosk/content-update.sh` + `kiosk/content-url.txt` — separate
  flow for the content team's bulk drops. Reads the URL from
  `content-url.txt` (one URL per file, comment lines `#` ignored),
  downloads + unzips, then for each of the three apps it locates
  `app{N}-…/media/` and/or `app{N}-…/config.js` inside the
  extracted tree (accepts flat or one-level-deep nested layouts)
  and REPLACES whichever it finds locally. Each app's media + config
  is independent — a zip may include either, both, or neither for
  any given app, and anything missing is left untouched. **HTML,
  CSS, fonts, launch scripts, plists, the ws-relay binary, and
  `kiosk/app3-displays.env` are NEVER touched** by content-update —
  those belong to dev / ops, not the content team. After replacing,
  deletes the temp extraction and `kickstart -k`-restarts any
  loaded LaunchAgent.
  The URL parsing is a pure-bash read loop (NOT `grep | head`) on
  purpose — `set -o pipefail` would kill the script when grep
  finds no matches (i.e. the file ships with only comments), and
  we want to fall through to the friendly "no URL set" error.
  `find_in_zip` uses `test "$flag" "$path"` instead of
  `[[ $flag $path ]]` because bash parses `[[ ]]` operators at
  parse time, not eval time — the operator flag has to come from
  a variable so `test` is the only option.
  Recovery from a bad content drop:
  `git checkout -- app1-slideshow/{media,config.js} app2-chapters/{media,config.js} app3-multi-screen/{media,config.js}`
  restores the committed defaults. The kiosk's on-screen error
  overlay ("config.js did not set window.APP_CONFIG…") is the
  signal to roll back when a malformed config gets shipped.
- **Project root `*.command` files** — `Install App 1.command`,
  `Install App 2.command`, `Install App 3.command`, `Update.command`,
  `Update media.command`.
  Double-click-from-Finder wrappers around `kiosk/install.sh` /
  `kiosk/update.sh` / `kiosk/content-update.sh` for non-developer
  operators. Each one `cd`s to its own folder so Finder's launch
  directory doesn't matter, runs the underlying shell script, prints
  a banner + success/failure summary, and pauses on "Press any key"
  so the Terminal window stays open long enough to read. Don't
  change the filenames (operators bookmark them) and keep the +x bit
  committed in git so a fresh clone is double-clickable straight
  away.

## Hard project constraints

These came from the user explicitly and shape every decision:

1. **100% offline.** The kiosk runs from `file://` on a Mac with no
   guaranteed internet. Don't fetch anything from the network at runtime.
   - No CDN fonts (Museo Sans is self-hosted at
     `app1-slideshow/fonts/museosans-700.ttf` and
     `app3-multi-screen/fonts/museosans-700.ttf`).
   - No `fetch('config.json')` — Chrome blocks `fetch` over `file://`.
     Configs are loaded via `<script src="config.js">` which sets
     `window.APP_CONFIG`.
   - Verify with `grep -nE 'https?://' index.html config.js`. The only
     `http://` that's allowed anywhere is the W3C SVG namespace URI
     (`xmlns="http://www.w3.org/2000/svg"`) — that's an XML identifier,
     not a fetch.
   - **App 3 exception:** `app3-multi-screen/index.html` opens a
     WebSocket to `ws://127.0.0.1:8743/ws` — see constraint #6.
2. **Standalone folders.** Each app folder must be copy-pasteable onto
   a fresh Mac and "just work" by opening `index.html` in Chrome. No
   build step, no `npm install`, no server.
   - **App 3 exception:** App 3 by design needs the `kiosk-ws-relay`
     binary to be running for the three screens to sync. The binary
     is prebuilt and committed (`kiosk/bin/`), so no toolchain is
     needed on the kiosk Mac, but App 3 won't function without it.
3. **Configurable only via `config.js`.** Non-developers should be able
   to swap slide content / hotspot coordinates / pause duration without
   touching HTML, CSS, or JS. App 3 has one additional operator-edited
   file — `kiosk/app3-displays.env` — for per-Mac display geometry
   (resolution + left/right display coordinates).
4. **4K primary, 1080p secondary.** Layouts target 3840×2160 first but
   must scale linearly down to 1920×1080. Done via vw-based sizing
   (width-based units even for vertical dimensions) so the design's
   1920×1080 pixel values map to vw cleanly.
5. **Non-selectable everything.** Kiosk users can't be allowed to
   accidentally highlight text, drag images, or open context menus.
   See "Common pitfalls" below for the enforcement pattern.
6. **Local WebSocket relay is the ONLY allowed "server" — and only
   for App 3.** App 3 needs three Chrome `--kiosk` processes to stay
   in sync; the file:// origin model rules out BroadcastChannel /
   localStorage / postMessage across separate Chrome instances, and
   collapsing them into one process loses per-display `--kiosk`
   coverage. The relay binary (`kiosk/bin/kiosk-ws-relay-{arm64,x86_64}`,
   ~5 MB, Go, source in `kiosk/ws-relay/`) listens on `127.0.0.1` only,
   has no auth (it's loopback-only), and is started as its own
   LaunchAgent (`com.intersolar.app3-ws`). Rules:
   - **Loopback only — never bind to `0.0.0.0` or any external
     interface.** The relay must remain unreachable from the network.
   - **No other app may add a server.** This carve-out is App 3's
     alone. Any future feature that's tempted to reach for a server
     (analytics, multi-Mac sync across stands, etc.) needs an
     explicit user sign-off before opening the door wider.
   - **Don't add HTTP routes beyond `/ws` and `/health`.** The
     simpler the relay's attack surface, the better.
   - **Update the prebuilt binaries when changing `main.go`** —
     `cd kiosk/ws-relay && ./build.sh` produces both arch binaries;
     commit them in the same PR as the source change.

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
- **Videos use `background: transparent`.** `<video>` has a black
  user-agent default background that bleeds through the letterbox
  bars when the video's aspect doesn't match the frame. Setting
  `background: transparent` on `.slide-img` (which both `<img>` and
  `<video>` share) makes the bars consistent with images — the
  sinus pattern shows through both. Don't remove the rule; the
  black bars would come back for videos only.
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
- **`debug` global config** — `false` (default) hides the mouse
  cursor everywhere via the universal `*` rule (see pitfall #12).
  `true` adds `body.debug`, which a sibling CSS rule keys off to
  restore native cursors (`cursor: auto`) for testing without a
  touchscreen. Class name matches App 2's existing `body.debug`
  convention so future debug toggles can hang off the same class
  in both apps. No other effect on App 1 right now — room to
  grow.

## App 2 architecture

- Single `<video>` filling the viewport with `object-fit: cover`.
- Hotspots are absolutely-positioned `<button>` elements layered on top.
  Coordinates in `config.js` are expressed at the `designWidth /
  designHeight` reference resolution; they're rendered as percentages of
  the viewport so they stay locked to the visible video regardless of
  display resolution.
- `debug: true` in `config.js` outlines the hotspots, shows a HUD
  with the current video time, AND restores the native mouse cursor
  (which is hidden everywhere else by the universal `*` rule) —
  all useful during setup to calibrate coordinates against the
  real production video. **The checked-in `app2-chapters/config.js`
  currently has `debug: true`** because the production video and
  final coordinates haven't been provided yet. **Flip it to `false`
  before the show** or visitors will see red calibration outlines
  over every hotspot AND a mouse cursor on the touchscreen.
- No text, no font dependencies, no countdown — much simpler than App 1.

## App 3 architecture (key decisions)

- **Three Chrome `--kiosk` instances**, one per display, each with
  its own `--user-data-dir`. We tried collapsing to one Chrome
  process with three windows (postMessage / BroadcastChannel for
  sync) but `--kiosk` only covers one display at a time on macOS;
  three separate processes are the only way to get all three
  displays into true kiosk lockdown.
- **WebSocket relay binds 127.0.0.1 only.** The Go relay
  (`kiosk/ws-relay/main.go`) listens on `127.0.0.1:8743/ws`. Each
  Chrome connects, the center broadcasts state, the relay rebroadcasts
  to all OTHER connections (sender doesn't get its own echo), and the
  relay caches the last message + replays it to new connects so late-
  joining satellites catch up immediately. **Never bind to `0.0.0.0`**
  (see hard constraint #6).
- **Center is authoritative.** Only the center responds to user input
  (buttons + swipe) and runs the auto-advance countdown. Satellites
  pass `applyState()` over every received message; their button
  listeners aren't bound. This keeps the slideshow's "source of
  truth" in one place — splitting authority across windows is
  needlessly complicated.
- **`?role=center|left|right` URL parameter** selects which screen
  this Chrome instance renders. Same `index.html` for all three; the
  role is set via `body.role-{center,left,right}` class plus a
  `ROLE_TO_FIELD` map that translates the role to the config-side
  field name (`center` → `middle`; `left` → `left`; `right` → `right`).
- **Per-role DOM is built once at boot.** Each slide container has
  exactly ONE media element — the role's source. Saves DOM weight
  and per-video preload pressure on satellites (no point loading
  middle's video on the left machine).
- **Message format is `{type:'state', index, paused, ts}`.** Single
  message type that covers both slide-position and pause sync. `ts`
  is `Date.now()` from the sender; receivers drop messages with
  `ts <= lastAppliedTs`. The relay doesn't parse — it forwards bytes
  verbatim and caches the most-recent text frame.
- **Center re-broadcasts on every WS (re)connect**, even if state
  hasn't changed. This overwrites any stale cached state in the
  relay (e.g. after the center crashed and a satellite reconnected
  in the meantime).
- **Center ignores incoming state messages** — only it originates
  them. Without this guard, the center could mirror its own old
  cached state after a reconnect and lose any in-flight changes.
- **Auto-reconnect with exponential backoff** (500ms → 8s cap).
  Both center and satellites reconnect; the relay LaunchAgent has
  `KeepAlive` so if the relay process crashes, launchd restarts
  it within ThrottleInterval (10s) and the kiosks reconnect.
- **Display geometry is operator-edited** in `kiosk/app3-displays.env`.
  The three `launch-app3-{center,left,right}.sh` scripts source it
  and pass `--window-position` + `--window-size` to Chrome. Chrome
  then `--kiosk`-fullscreens on whichever display contains the
  specified point. The defaults (3× 1920×1080, center as macOS Main
  Display, left=-1920, right=+1920) cover the most common setup.
- **No text, no variants, no sinus background.** App 3 is the
  simplest of the three on the rendering side — just fullscreen
  media + the App 1 controls cluster on the center. Don't add text
  overlays to App 3 without an explicit ask; the spec calls for
  pure fullscreen photos.
- **Pause behaviour propagates via state.** Center sets
  `isPaused: true`, broadcasts, satellites mirror — pausing their
  videos too (so videos on the satellites don't keep playing when
  the operator pauses the slideshow). Auto-resume timer is
  center-only; satellites just receive the eventual "unpaused"
  broadcast.
- **`debug: true`** restores the cursor (same as App 1/2) AND shows
  a top-left HUD with role / WS state / current slide / last applied
  ts. Useful for verifying the sync flow during setup.

## kiosk/ws-relay/ (App 3 sync relay)

- **Tiny Go program**, ~150 lines, single dependency on
  `github.com/gorilla/websocket`. Binds 127.0.0.1 only.
- **Prebuilt binaries committed to `kiosk/bin/`** for both Apple
  Silicon (`kiosk-ws-relay-arm64`) and Intel (`kiosk-ws-relay-x86_64`).
  The launch script picks the right one via `uname -m`. Don't
  forget to rebuild + commit both when changing `main.go` — the
  kiosk Mac has no Go toolchain. `cd kiosk/ws-relay && ./build.sh`
  rebuilds both.
- **Build flags**: `-trimpath -ldflags="-s -w"` for reproducible
  builds across developer machines + stripped symbols (~30% smaller
  binary).
- **Two HTTP endpoints**: `/ws` for the WebSocket upgrade, `/health`
  returns plain `ok` so an operator can `curl http://127.0.0.1:8743/health`
  without needing a WebSocket client. Don't add more — see hard
  constraint #6.
- **Cache-and-replay** for late joiners: the relay holds the most
  recent text frame in `lastMsg` and writes it to every new
  connection at `add()` time. This means a satellite that starts up
  after the center has already broadcast immediately sees the
  current state without waiting for the next auto-advance.

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
11. **TCC-protected folders silently break the LaunchAgent.** If
   `$PROJECT_DIR` is inside `~/Documents/`, `~/Desktop/`,
   `~/Downloads/`, `~/Pictures/`, `~/Movies/`, or `~/Music/`,
   `/bin/bash` can't read the launch script and the agent fails with
   EPERM ("Operation not permitted") — Chrome never starts, and there's
   no UI prompt to grant access. `kiosk/install.sh` has a
   `refuse_if_protected_path` check that fires before writing
   anything to `~/Library/LaunchAgents`. Don't remove that check, and
   don't recommend `~/Documents/` (or sibling folders) in any docs;
   `~/` is the canonical install location.
12. **Universal `* { cursor: none }` is how the kiosk hides the
   cursor everywhere.** Body-level `cursor: none` alone doesn't work
   — the user-agent stylesheet sets `cursor: pointer` on every
   `<button>`/`<a>` and beats body's inherited cursor. The universal
   `*, *::before, *::after { cursor: none; }` rule (in both apps)
   beats the UA stylesheet on specificity (author wins) and removes
   the need for per-element overrides. Don't replace it with a
   body-only rule. Toggle off for testing via the `debug` config
   flag — see App 1 / App 2 architecture sections.
13. **Countdown ring must live INSIDE the `<button>` element**, not as
   a sibling. When it was a sibling: (a) the button's background
   painted on top of it (DOM-order = paint-order), so the ring
   "slipped behind" on `:active` press; (b) the ring didn't inherit
   the button's `transform: scale(.95)` press animation. Both fixed
   by nesting. Don't move the SVG back outside the button.
14. **Countdown ring uses `inset: -1px` to cover the button's 1 px
   border.** `.ctrl-btn` is `width: 96px` with `box-sizing:
   border-box` and a `1 px solid` border, so the content (padding)
   box is 94×94. Without `inset: -1px` the ring SVG renders 94×94
   and a 1 px blue rim shows outside the white stroke. Don't drop
   the negative inset.
15. **`caffeinate` is orphaned by the launch scripts.** Pre-existing
   bug, flagged by the PR #14 reviewer: the `trap '… $CAFFEINATE_PID
   …' EXIT` in `launch-app{1,2}.sh` and the three App 3 Chrome
   launchers (`launch-app3-{center,left,right}.sh`) is discarded by
   the subsequent `exec "$CHROME"`, so the background
   `caffeinate -dimsu` outlives the LaunchAgent restart cycle and
   accumulates across restarts. Not yet fixed — worth a dedicated PR.
   If you're writing the fix, the canonical pattern is to spawn
   caffeinate, then `wait` for `$CHROME` in the foreground so the
   trap fires when Chrome exits. **`launch-app3-ws.sh` is unaffected
   — the ws relay doesn't `caffeinate`** (it's a tiny long-running
   Go process with no display-sleep concern), so a fix only needs
   to touch the five Chrome launchers.
16. **App 3: WS relay must bind 127.0.0.1, never 0.0.0.0.** The kiosk
   Mac is often on a public exhibition Wi-Fi. Binding to all interfaces
   would expose the relay to anyone on the same network, who could
   then push arbitrary `state` messages and drive the kiosk's slide
   index. `kiosk/launch-app3-ws.sh` passes `-addr 127.0.0.1:8743`
   explicitly even though the binary defaults to it — belt-and-braces
   + in-script documentation that this is deliberate. See hard
   constraint #6.
17. **App 3: rebuild + commit BOTH arch binaries when changing
   `kiosk/ws-relay/main.go`.** The kiosk Mac has no Go toolchain;
   `kiosk/launch-app3-ws.sh` picks `kiosk/bin/kiosk-ws-relay-$(uname -m)`.
   `uname -m` returns `arm64` on Apple Silicon and `x86_64` on Intel
   — those are the exact suffixes `kiosk/ws-relay/build.sh`
   produces. If you push a `main.go` change without re-running
   `build.sh` + committing the resulting binaries, the App 3 install
   succeeds but the relay never starts and the satellites never sync.
18. **App 3: config field is `middle`, role is `center`.** The
   geographic field name (`middle`) and the UI-meaningful role name
   (`center` — the one with the controls) don't match. There's a
   `ROLE_TO_FIELD = { center: 'middle', left: 'left', right: 'right' }`
   map in `app3-multi-screen/index.html` that bridges them once at
   boot. If you rename either side, rename both — and update the
   inline comment that explains the divergence.
19. **App 3: relay's lastMsg cache is load-bearing for satellite
   startup.** On boot, satellites have no way to ask the center for
   the current state — they just open a WebSocket and wait. Without
   the relay's `lastMsg`-on-connect replay, a satellite that
   starts AFTER the center has already broadcast will display its
   default slide (index 0) until the next center-side broadcast,
   which could be up to `autoAdvanceMs` later. Don't remove the
   replay path from `kiosk/ws-relay/main.go`. If you ever need
   multiple message types, cache per-type rather than dropping the
   cache entirely.
20. **App 3: `--window-position` + `--kiosk` decides which display.**
   Chrome doesn't have a `--display=N` flag. The launch scripts
   pass `--window-position=X,Y --window-size=W,H` from
   `app3-displays.env`, then `--kiosk` fullscreens whatever window
   it's about to create on the display containing (X,Y). This
   relies on the coordinates in `app3-displays.env` matching the
   actual macOS display arrangement — see INSTALL.md §3.7 for the
   pre-install steps that get the arrangement right.

## Useful commands

```bash
# Find anything fetching from the network at runtime. Scoped to the runtime
# HTML/JS only on purpose — broadening to the whole repo would pick up
# README links and the W3C SVG namespace identifier in `sinus-bg.svg`, which
# are not actual fetches.
grep -nE 'https?://' app1-slideshow/index.html app1-slideshow/config.js \
                      app2-chapters/index.html  app2-chapters/config.js \
                      app3-multi-screen/index.html app3-multi-screen/config.js
# App 3's index.html contains `ws://127.0.0.1:8743/ws` — that's the
# expected loopback WebSocket, not a network call. It's the only ws://
# in any runtime file. Hard constraint #6 documents why.

# Check the build runs at 1920×1080 in a fresh Chrome profile
open -na "Google Chrome" --args \
  --kiosk --autoplay-policy=no-user-gesture-required \
  --user-data-dir=/tmp/kiosk-test \
  --app="file://$PWD/app1-slideshow/index.html"

# Install the LaunchAgent that boots a Mac into App 1
./kiosk/install.sh app1

# Build (or rebuild) the App 3 WebSocket relay binaries — only needed
# on the developer machine when changing kiosk/ws-relay/main.go.
# Produces both arm64 + x86_64 in kiosk/bin/.
cd kiosk/ws-relay && ./build.sh && cd ../..

# Smoke-test the relay locally (without installing the LaunchAgent)
./kiosk/bin/kiosk-ws-relay-$(uname -m) &
curl -sf http://127.0.0.1:8743/health  # expect "ok"
# Then open app3-multi-screen/index.html in 3 Chrome windows with
# different ?role= params to verify the sync visually.
kill %1

# Regenerate the .docx user manual from kiosk/INSTALL.md. First run
# `npm install`s `docx` + `marked` into kiosk/build-docx/node_modules/
# (gitignored, locked by the committed package-lock.json); subsequent
# runs are fast. The generated file lands at
# ~/Downloads/Victron Exhibition Kiosk Apps — User Manual <YYYY-MM-DD>.docx
# for upload to Google Drive — drag-and-drop replace into the existing
# "Victron Exhibition Kiosk Apps — User Manual" doc.
./kiosk/build-docx.sh
```

## File map (quick orientation)

Working-directory name is `intersolar-tv-apps/` (legacy — see naming
note at the top); repo on GitHub is `nielsfilmer/victron-exhibition-apps`.

```
intersolar-tv-apps/                  # local folder; repo is victron-exhibition-apps
├── README.md                       # user-facing app-internals docs
├── CLAUDE.md                       # this file — context for Claude
├── .gitignore                      # excludes .DS_Store, .claude/, *.zip, kiosk logs, app3 profiles
├── .claude/settings.json           # project-scoped permissions (git/gh pr create+review)
├── Install App 1.command           # Finder double-click → installs App 1 kiosk
├── Install App 2.command           # Finder double-click → installs App 2 kiosk
├── Install App 3.command           # Finder double-click → installs App 3 (4 LaunchAgents)
├── Update.command                  # Finder double-click → git pull + restart kiosk
├── Update media.command            # Finder double-click → pull content zip + restart
├── app1-slideshow/
│   ├── index.html                  # all CSS + JS inlined; loads config.js as <script>
│   ├── config.js                   # window.APP_CONFIG = { slideshow: {...}, pauseMinutes }
│   ├── fonts/museosans-700.ttf
│   └── media/                      # sinus-bg.svg + slide-{1..5}.jpg (placeholders)
├── app2-chapters/
│   ├── index.html
│   ├── config.js                   # window.APP_CONFIG = { video, buttons[…], debug }
│   └── media/main.mp4              # placeholder Sintel trailer (replace for production)
├── app3-multi-screen/
│   ├── index.html                  # reads ?role=center|left|right; renders accordingly
│   ├── config.js                   # window.APP_CONFIG = { slideshow: { images: [{left,middle,right}] }, wsUrl }
│   ├── fonts/museosans-700.ttf
│   └── media/                      # slide-{1..N}-{left,middle,right}.jpg
└── kiosk/
    ├── INSTALL.md                  # full setup + show-floor ops manual (incl. §3.7 App 3)
    ├── install.sh                  # templates plist paths + launchctl loads (app1/app2/app3)
    ├── update.sh                   # git pull + launchctl kickstart -k the kiosk
    ├── content-update.sh           # download content zip + replace media/ + config.js per app
    ├── content-url.txt             # plain-text URL the content-update script reads
    ├── launch-app1.sh              # exec'd by LaunchAgent; opens Chrome --kiosk
    ├── launch-app2.sh
    ├── com.intersolar.app1.plist
    ├── com.intersolar.app2.plist
    ├── app3-displays.env           # operator-edited display geometry for App 3
    ├── launch-app3-ws.sh           # picks kiosk/bin/kiosk-ws-relay-$(uname -m)
    ├── launch-app3-center.sh       # Chrome --kiosk on the macOS Main Display
    ├── launch-app3-left.sh         # Chrome --kiosk on the left display
    ├── launch-app3-right.sh        # Chrome --kiosk on the right display
    ├── com.intersolar.app3-ws.plist
    ├── com.intersolar.app3-center.plist
    ├── com.intersolar.app3-left.plist
    ├── com.intersolar.app3-right.plist
    ├── ws-relay/                   # Go source for the App 3 sync relay
    │   ├── main.go
    │   ├── go.mod / go.sum
    │   ├── build.sh                # builds both arch binaries into ../bin/
    │   └── README.md
    ├── bin/                        # prebuilt relay binaries (committed)
    │   ├── kiosk-ws-relay-arm64
    │   └── kiosk-ws-relay-x86_64
    ├── build-docx.sh               # wrapper for build-docx/build.js (dev tool, not a kiosk runtime)
    └── build-docx/                 # MD→DOCX user-manual generator (Node.js + marked + docx)
        ├── build.js                # reads kiosk/INSTALL.md → writes ~/Downloads/…User Manual <date>.docx
        ├── package.json + package-lock.json
        └── .gitignore              # excludes node_modules/ (installed on first run)
```
