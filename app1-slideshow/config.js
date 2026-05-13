// App 1 configuration. Edit this file to change the slideshow content / behaviour.
// Loaded by index.html via a <script> tag so it works over file:// (no server needed).
//
// Per slide:
//   src       — path to the image
//   variant   — layout variant. One of:
//                 "default"      → image right (~63% wide), text top-left, sinus bg
//                 "large-image"  → image fills right with rounded corners, text top-left, sinus bg
//                 "text-right"   → image left, text top-right, sinus bg
//                 "fullscreen"   → image fills entire screen, no text, no sinus bg
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
window.APP_CONFIG = {
  slideshow: {
    images: [
      // Default — image right, text left
      {
        src:      "media/slide-1.jpg",
        title:    "Solar energy at scale",
        subtitle: "Victron MPPT controllers extract every available watt",
        body:     "The intelligent maximum-power-point-tracking algorithm sweeps the array continuously, so partial shading and changing weather never cost you more than they have to."
      },
      // Large image — image takes most of the screen with rounded corners
      {
        src:      "media/slide-2.jpg",
        variant:  "large-image",
        title:    "Inverters built to last",
        subtitle: "Seamless switching between grid, generator and battery",
        body:     "MultiPlus and Quattro inverter/chargers cut over silently in under 20 ms. Pure sine-wave output keeps sensitive electronics running clean."
      },
      // Text right — mirror layout, image left, text right
      {
        src:      "media/slide-3.jpg",
        variant:  "text-right",
        title:    "Storage that scales",
        subtitle: "From a single Lithium Smart battery to a multi-MWh BESS",
        body:     "The same Victron components scale up. Add capacity later without redesigning the system, and keep using the same configuration tools and dashboards."
      },
      // Fullscreen — image fills the entire screen, no text, no sinus background
      {
        src:      "media/slide-4.jpg",
        variant:  "fullscreen"
      },
      // Default again
      {
        src:      "media/slide-5.jpg",
        title:    "Designed for off-grid life",
        subtitle: "Reliability when the grid is hundreds of kilometres away",
        body:     "Victron's component-based approach means anything that fails can be swapped on-site — no proprietary modules, no waiting weeks for a return."
      }
    ],
    autoAdvanceMs: 8000,
    transitionMs:  700
  },
  pauseMinutes: 5
};
