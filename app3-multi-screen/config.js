// App 3 configuration. Edit this file to change the slideshow content / behaviour.
// Loaded by index.html via a <script> tag so it works over file:// (no server needed).
//
// App 3 runs as THREE separate Chrome --kiosk instances (one per
// screen) plus a tiny WebSocket relay that syncs them. The middle
// screen hosts the controls + is authoritative; left/right are
// passive receivers. See kiosk/INSTALL.md §3.7 for the multi-screen
// setup; see kiosk/ws-relay/README.md for the relay.
//
// Per slide:
//   left      — path to the media shown on the LEFT screen
//   middle    — path to the media shown on the MIDDLE screen
//   right     — path to the media shown on the RIGHT screen
//                 Each is auto-detected by extension:
//                   .jpg/.png/.svg/etc → <img>
//                   .mp4/.webm/.ogg/.m4v/.mov → muted <video>
//                 Per-screen — left can be a video while middle is
//                 an image, etc. Videos play from frame 0 when the
//                 slide becomes current and pause on leave, so
//                 nothing runs in the background.
//   loop      — videos only. `false` plays once and stops on the
//                 last frame; default is `true` (loop until slide
//                 changes). Applies to ALL three screens for this
//                 slide; if a slide has a mix of image + video the
//                 flag is ignored on the image(s).
//   autoAdvanceMs — optional per-slide duration in ms. Overrides
//                 the global `slideshow.autoAdvanceMs` for this
//                 slide only. `0` disables auto-advance — the
//                 slide stays until the user advances manually.
//
// Top level:
//   slideshow.autoAdvanceMs  — how long the countdown ring takes to fill (default 8000)
//   slideshow.transitionMs   — slide crossfade duration (default 700)
//   pauseMinutes             — minutes the slideshow stays paused after the pause
//                              button is pressed; after this elapses the countdown
//                              starts over from empty (default 5; set 0 to pause
//                              indefinitely until manually resumed).
//   controlsAlign            — "left" (default) or "right". Pins the controls
//                              cluster (back / X-of-Y / next+ring / pause) to
//                              the bottom-left or bottom-right of the MIDDLE
//                              screen. Cluster order is preserved either way.
//   debug                    — `false` (default) is the kiosk behaviour.
//                              `true` adds `body.debug` to the document,
//                              which today restores the native mouse cursor
//                              and shows the role + sync state in the top-
//                              left HUD (useful for development / testing
//                              without a touchscreen). Class is shared with
//                              App 1 / App 2 so future debug toggles can hang
//                              off the same flag.
//   wsUrl                    — WebSocket relay address (default
//                              "ws://127.0.0.1:8743/ws"). Only change if
//                              you also change the `-addr` flag in
//                              kiosk/launch-app3-ws.sh.
window.APP_CONFIG = {
  slideshow: {
    images: [
      {
        left:   "media/slide-1-left.jpg",
        middle: "media/slide-1-middle.jpg",
        right:  "media/slide-1-right.jpg",
      },
      {
        left:   "media/slide-2-left.jpg",
        middle: "media/slide-2-middle.jpg",
        right:  "media/slide-2-right.jpg",
        autoAdvanceMs: 12000,
      },
    ],
    autoAdvanceMs: 8000,
    transitionMs: 700,
  },
  pauseMinutes: 5,
  controlsAlign: "right",
  debug: false,
  wsUrl: "ws://127.0.0.1:8743/ws",
};
