// Dreamcore spectrum visualizer — central user configuration.
//
// Every tunable lives here with a documented default, so a fresh install
// gets the intended design with no customization. Nothing in this file may
// reference a username, home path, monitor name, audio device, player, or
// wallpaper-specific colour: only portable defaults and standard locations
// (resolved at runtime, never hardcoded here).
//
// Copy overrides by editing the property defaults below (quickshell
// auto-reloads on save, so tuning is live within a second or two).
import QtQuick

QtObject {
    id: root

    // Master switch. When false no audio backend is started and no window
    // is shown. The rest of the rice is unaffected.
    property bool enabled: true

    // Visibility policy:
    //   "auto"   — show on sustained system-audio activity, hide after
    //              silenceTimeoutMs (works with any app: players,
    //              browsers, streams — no per-app assumptions).
    //   "mpris"  — show while the island's MPRIS service reports playback.
    //              Useful if the monitor source is noisy on your hardware.
    //   "always" — always show (debugging / screenshots).
    property string visibilityPolicy: "auto"

    // Target-screen policy:
    //   "auto"    — default layer-shell placement (same behaviour as the
    //              dynamic island: one window, compositor-placed).
    //   "focused" — follow the Hyprland focused monitor.
    //   "<name>"  — pin to the output with this name (see `hyprctl monitors`).
    property string targetScreen: "auto"

    // Geometry, in Qt logical pixels (display scaling handled by Qt).
    // Full-width soundscape: the stage spans the target screen (minus a
    // small configurable side inset) so the waveform stretches across the
    // desktop and dissolves into the wallpaper at both ends. maxWidthPx is
    // intentionally generous — it only caps absurd widths on request.
    // Narrower screens shrink the composition proportionally; the wave
    // shape, taper, and fades are all width-relative, never pixel-fixed.
    property real widthFraction: 0.5
    property real maxWidthPx: 7680
    property real sideMarginPx: 24
    property real canvasHeightPx: 160
    property real bottomOffsetPx: 0

    // Headroom around the composition. The canvas is taller than the wave
    // area so crests and bar tips never touch its top edge (Canvas clips
    // at its bounds). Worst case: crest at ~0.13H + bar tip above it —
    // this padding keeps ~16 px of air there; reflection gets ~28 px
    // below. Total stage/canvas height = canvasHeightPx + canvasPadPx.
    property real canvasPadPx: 80

    // Horizontal edge fade: each end dissolves over this fraction of the
    // total width (smoothstep easing, fully transparent outer edges).
    // Long and soft by default so the ribbon emerges from the desktop
    // instead of looking chopped off. 0 disables the fade.
    property real edgeFadeFraction: 0.22

    // Adaptive repaint: frames whose levels differ from the last painted
    // frame by less than repaintEpsilon (≈1 px at default sizes) are
    // skipped — steady tones/quiet passages cost ~idle while transients
    // still render at full rate. repaintMaxIntervalMs bounds drift.
    property real repaintEpsilon: 0.004
    property int repaintMaxIntervalMs: 500

    // Audio analysis tuning.
    property int bars: 96             // cava bands (8..256, clamped)
    property int framerate: 60       // cava frames per second (10..60)
    property real sensitivity: 1.5   // linear amplitude multiplier
    property real smoothing: 0.55    // 0 = raw, 0.95 = very floaty
    property string inputMethod: "auto" // auto|pipewire|pulse (auto falls back)

    // Activity / visibility tuning.
    property real activityThreshold: 0.02 // mean level (0..1) counting as sound
    property int silenceTimeoutMs: 2500   // hold time before fading out
    property int fadeInMs: 600
    property int fadeOutMs: 1200

    // Waveform presence. The wave is the dominant element: amplitude is a
    // large fraction of the canvas so undulations read clearly, and gamma
    // < 1 lifts quiet mid-levels perceptually (no clipping: values stay
    // in 0..1, loud passages simply saturate the peak gracefully).
    property real waveAmplitudeFraction: 0.42
    property real waveGamma: 0.7

    // Glow and stroke styling (layered strokes: broad faint halo + sharp
    // core). glowIntensity scales the halo layers; the core stays bright.
    property real glowIntensity: 0.9
    property real glowWidthPx: 14.0
    property real coreWidthPx: 2.4

    // Legibility treatment for busy or bright wallpapers. A localized veil
    // (elliptical gradient fading to full transparency — never a card,
    // pill, or panel) separates the ribbon from wallpaper detail, and a
    // contrasting under-stroke defines the wave where glow alone would
    // wash out on bright areas. Veil/shadow tones derive from the palette
    // (dark veil on dark themes, light veil on light ones); set
    // backdropOpacity to 0 to disable the veil entirely.
    property real backdropOpacity: 0.38
    property real shadowOpacity: 0.55
    property real waveBrighten: 0.25   // core lift toward the readable extreme

    // Bars are subordinate texture riding the wave (centred on the curve),
    // never a separate equalizer row. Kept short enough that bar tips at
    // a full-scale crest stay inside the padded canvas (see canvasPadPx).
    property real barWidthPx: 1.4
    property real maxBarHeightFraction: 0.26 // of canvas height

    // Pywal integration. Empty palettePath means "standard location"
    // ($HOME/.cache/wal/colors.json, resolved at runtime).
    //
    // autoAccent (default) picks the most vivid palette colour for the wave
    // and a hue-distinct runner-up for the bars, with a contrast guard
    // against the palette background — so colourful, muted, dark, light,
    // and monochrome wallpapers all stay legible with the same identity.
    // Set autoAccent false to pin palette slots manually instead.
    property string palettePath: ""
    property bool autoAccent: true
    property string primarySlot: "color4"
    property string secondarySlot: "color5"
    property string glowSlot: "color6"
}



