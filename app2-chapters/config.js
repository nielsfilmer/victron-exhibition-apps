// App 2 configuration. Edit this file to change the video / hotspot buttons.
// Loaded by index.html via a <script> tag so it works over file:// (no server needed).
window.APP_CONFIG = {
  video: "media/main.mp4",
  loop: true,
  muted: true,
  designWidth: 3840,
  designHeight: 2160,
  debug: true,
  buttons: [
    { x: 80, y: 80, width: 480, height: 220, timestamp: 0, label: "Chapter 1" },
    {
      x: 80,
      y: 340,
      width: 480,
      height: 220,
      timestamp: 12,
      label: "Chapter 2",
    },
    {
      x: 80,
      y: 600,
      width: 480,
      height: 220,
      timestamp: 24,
      label: "Chapter 3",
    },
    {
      x: 80,
      y: 860,
      width: 480,
      height: 220,
      timestamp: 36,
      label: "Chapter 4",
    },
  ],
};
