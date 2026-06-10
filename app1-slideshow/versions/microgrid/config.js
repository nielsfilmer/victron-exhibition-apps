// App 1 configuration. Edit this file to change the slideshow content / behaviour.
// Loaded by index.html via a <script> tag so it works over file:// (no server needed).
//
// Per slide:
//   src       — path to the media. Auto-detected by extension:
//                 .jpg/.png/.svg/etc → rendered as <img>
//                 .mp4/.webm/.ogg/.m4v/.mov → rendered as muted <video>
//               Videos play automatically when the slide becomes current
//               (from frame 0) and pause when the slide leaves — so they
//               never run in the background. Many videos can be configured
//               (preload="metadata" keeps the per-video memory cost low).
//   loop      — videos only. `false` plays once and stops on the last
//                frame; default is `true` (loop until slide changes).
//                Forced to `false` on slides that set
//                `syncProgressWithVideo: true` — see below.
//   autoAdvanceMs — optional per-slide duration in ms. Overrides the
//                global `slideshow.autoAdvanceMs` for this slide only.
//                Use a longer value to let viewers dwell on info-dense
//                slides, or `0` to make a slide stay until the viewer
//                navigates manually. Ignored when
//                `syncProgressWithVideo: true` is set on the same slide.
//   syncProgressWithVideo — videos only. `true` ties the slide to the
//                video's playback: the countdown ring tracks the
//                video's progress (currentTime / duration), the slide
//                advances when the video ends, and the pause button
//                pauses/resumes the video together with the ring.
//                Overrides `autoAdvanceMs` and forces `loop: false`
//                (the slide advances on the video's `ended` event,
//                which never fires while looping). Default `false` —
//                video slides without this flag behave as before
//                (independent timer, video loops in background).
//   variant   — layout variant. One of:
//                 "default"      → media right (~63% wide), text top-left, sinus bg
//                 "large-image"  → media fills right (larger, sharp corners), text top-left, sinus bg
//                 "text-right"   → media left, text top-right, sinus bg
//                 "fullscreen"   → media fills entire screen, no text, no sinus bg
//               omit `variant` for "default".
//   objectFit — how the media fills its frame. "cover" crops to fill;
//                "contain" letterboxes so nothing is cropped (the sinus
//                pattern shows through the gaps). Applies to images and
//                videos. Omit to use the variant default — "default" and
//                "text-right" default to "contain"; "large-image" and
//                "fullscreen" default to "cover".
//   title     — leading bold portion of the headline (rendered 100% white)
//   subtitle  — continuation rendered inline at 80% white
//   body      — paragraph below the headline. Accepts basic inline HTML
//               (e.g. <ul><li>…</li></ul>, <strong>, <br>) as well as plain
//               text — the markup is rendered, not shown literally.
//               (title/subtitle/body are ignored on the fullscreen variant)
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
//                              the bottom-left or bottom-right of the screen.
//                              Cluster order is preserved either way.
//                              When set to "right", the `large-image` variant
//                              auto-flips its image to the left edge so the
//                              controls don't sit on top of it.
//   debug                    — `false` (default) is the kiosk behaviour.
//                              `true` adds `body.debug` to the document,
//                              which today restores the native mouse cursor
//                              (useful for development / testing without a
//                              touchscreen). The class is shared with App 2
//                              so future debug toggles (FPS HUD, slide-index
//                              overlay, etc.) can hang off the same flag.
window.APP_CONFIG = {
  slideshow: {
    images: [
      {
        src: "media/video-1.mp4",
        variant: "fullscreen",
        autoAdvanceMs: 15000,
        syncProgressWithVideo: true,
        // title: "Video 1 - An example",
        // subtitle: "Video Subtitle",
        // body: "Videos play immediately when the slide becomes current and pause when it leaves, so nothing runs in the background. Use `loop: false` per slide to play once and stop on the last frame.",
      },
      {
        src: "media/video-2.mp4",
        variant: "fullscreen",
        autoAdvanceMs: 15000,
        syncProgressWithVideo: true,
        // title: "Video 2",
        // subtitle: "Video Subtitle",
        // body: "Videos play immediately when the slide becomes current and pause when it leaves, so nothing runs in the background. Use `loop: false` per slide to play once and stop on the last frame.",
      },
      {
        src: "media/video-3.mp4",
        variant: "fullscreen",
        autoAdvanceMs: 15000,
        syncProgressWithVideo: true,
        // title: "Video 3",
        // subtitle: "Video Subtitle",
        // body: "Videos play immediately when the slide becomes current and pause when it leaves, so nothing runs in the background. Use `loop: false` per slide to play once and stop on the last frame.",
      },
    ],
    autoAdvanceMs: 8000,
    transitionMs: 700,
  },
  pauseMinutes: 5,
  controlsAlign: "right",
  debug: false,
};
