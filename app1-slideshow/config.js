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
//   autoAdvanceMs — optional per-slide duration in ms. Overrides the
//                global `slideshow.autoAdvanceMs` for this slide only.
//                Use a longer value to let viewers dwell on info-dense
//                slides, or `0` to make a slide stay until the viewer
//                navigates manually.
//   variant   — layout variant. One of:
//                 "default"      → media right (~63% wide), text top-left, sinus bg
//                 "large-image"  → media fills right (larger, sharp corners), text top-left, sinus bg
//                 "text-right"   → media left, text top-right, sinus bg
//                 "fullscreen"   → media fills entire screen, no text, no sinus bg
//               omit `variant` for "default".
//   title     — leading bold portion of the headline (rendered 100% white)
//   subtitle  — continuation rendered inline at 80% white
//   body      — paragraph below the headline
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
//   debug                    — `false` (default) hides the mouse cursor
//                              everywhere (kiosk behaviour). Set `true` for
//                              development / testing without a touchscreen
//                              so you can see the cursor over buttons and
//                              swipe areas. No other effect right now.
window.APP_CONFIG = {
  slideshow: {
    images: [
      // Default — image right, text left
      {
        src: "media/slide-1.jpg",
        title: "Solar energy at scale",
        subtitle: "Victron MPPT controllers extract every available watt",
        body: "The intelligent maximum-power-point-tracking algorithm sweeps the array continuously, so partial shading and changing weather never cost you more than they have to.",
      },
      // Large image — image takes most of the screen with rounded corners
      {
        src: "media/slide-2.jpg",
        variant: "large-image",
        title: "Inverters built to last",
        subtitle: "Seamless switching between grid, generator and battery",
        body: "MultiPlus and Quattro inverter/chargers cut over silently in under 20 ms. Pure sine-wave output keeps sensitive electronics running clean.",
      },
      // Text right — mirror layout, image left, text right
      {
        src: "media/slide-3.jpg",
        variant: "text-right",
        title: "Storage that scales",
        subtitle: "From a single Lithium Smart battery to a multi-MWh BESS",
        body: "The same Victron components scale up. Add capacity later without redesigning the system, and keep using the same configuration tools and dashboards.",
      },
      // Fullscreen — image fills the entire screen, no text, no sinus background.
      // Lingers 12s on this slide instead of the global 8s (per-slide override).
      {
        src: "media/slide-4.jpg",
        variant: "fullscreen",
        autoAdvanceMs: 12000,
      },
      // VIDEO slide — muted, looped, plays from frame 0 every time the slide
      // becomes current and pauses on leave. Layout variants and text fields
      // work the same as for images. Holds for 15s so a bit more of the
      // video is seen before advancing.
      {
        src: "media/sample-video.mp4",
        autoAdvanceMs: 15000,
        title: "Real-world install footage",
        subtitle:
          "Drop in any .mp4 / .webm / .ogg — it's auto-detected by extension",
        body: "Videos play immediately when the slide becomes current and pause when it leaves, so nothing runs in the background. Use `loop: false` per slide to play once and stop on the last frame.",
      },
      // Default again
      {
        src: "media/slide-5.jpg",
        title: "Designed for off-grid life",
        subtitle: "Reliability when the grid is hundreds of kilometres away",
        body: "Victron's component-based approach means anything that fails can be swapped on-site — no proprietary modules, no waiting weeks for a return.",
      },
    ],
    autoAdvanceMs: 8000,
    transitionMs: 700,
  },
  pauseMinutes: 5,
  controlsAlign: "right",
  debug: false,
};
