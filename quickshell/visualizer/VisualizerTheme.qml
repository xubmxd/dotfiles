// Dreamcore spectrum — Pywal theme integration.
//
// Watches the generated pywal palette (default: $HOME/.cache/wal/colors.json,
// the same file the dynamic island reads) and derives the visualizer colours
// from it. With autoAccent (default) the most vivid palette colour becomes
// the wave, a hue-distinct runner-up tints the bars, and the glow follows
// the brighter accent — all guarded for contrast against the palette
// background, so colourful, muted, dark, light, and monochrome wallpapers
// keep the same visual identity. No wallpaper-specific colour is hardcoded:
// when the palette is missing or malformed, neutral fallbacks keep the
// component alive and it picks up the real palette on the next wallpaper
// change without a Quickshell restart.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string palettePath: ""
    property bool autoAccent: true
    property string primarySlot: "color4"
    property string secondarySlot: "color5"
    property string glowSlot: "color6"

    // Legibility lift (0..1), bound from the visualizer config. Applied
    // toward the readable extreme (white on dark themes, black on light
    // ones) so the bright core always means contrast, never wash-out.
    property real brighten: 0.25

    // Standard palette location, resolved at runtime (never hardcoded to a
    // specific user's home). Matches the island's FileView convention.
    readonly property string resolvedPath: palettePath !== ""
        ? palettePath
        : Quickshell.env("HOME") + "/.cache/wal/colors.json"

    // True once a valid palette has been parsed at least once.
    property bool paletteReady: false

    // Raw palette object (keys color0..color15 + special). Never throws to
    // bindings: malformed JSON yields the neutral fallback instead.
    property var palette: {
        try {
            var parsed = JSON.parse(paletteFile.text())
            if (parsed && parsed.colors)
                return parsed.colors
        } catch (error) {
            // Fall through to the fallback below (warned once per change).
        }
        return null
    }

    property var fallbackPalette: ({
        color0: "#14141a", color1: "#8b8b9e", color2: "#9a9ab0",
        color3: "#a8a8bd", color4: "#b9b9d6", color5: "#c9c2e0",
        color6: "#d6cfe8", color7: "#e2e2ee", color8: "#55556a",
        color9: "#8b8b9e", color10: "#9a9ab0", color11: "#a8a8bd",
        color12: "#b9b9d6", color13: "#c9c2e0", color14: "#d6cfe8",
        color15: "#f0f0f8"
    })

    // ---- colour science helpers (all derived from the live palette) ----
    function hexToRgb(hex) {
        return {
            r: parseInt(hex.substr(1, 2), 16) / 255,
            g: parseInt(hex.substr(3, 2), 16) / 255,
            b: parseInt(hex.substr(5, 2), 16) / 255
        }
    }

    function saturationOf(c) {
        var mx = Math.max(c.r, c.g, c.b), mn = Math.min(c.r, c.g, c.b)
        if (mx <= 0)
            return 0
        return (mx - mn) / mx
    }

    function lightnessOf(c) {
        return (Math.max(c.r, c.g, c.b) + Math.min(c.r, c.g, c.b)) / 2
    }

    function hueOf(c) {
        var mx = Math.max(c.r, c.g, c.b), mn = Math.min(c.r, c.g, c.b)
        if (mx === mn)
            return -1 // achromatic
        var d = mx - mn, h = 0
        if (mx === c.r)
            h = ((c.g - c.b) / d) % 6
        else if (mx === c.g)
            h = (c.b - c.r) / d + 2
        else
            h = (c.r - c.g) / d + 4
        h *= 60
        if (h < 0)
            h += 360
        return h
    }

    function rgbToHex(c) {
        function ch(v) {
            var s = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)
            return s.length === 1 ? "0" + s : s
        }
        return "#" + ch(c.r) + ch(c.g) + ch(c.b)
    }

    function mixToward(c, target, amount) {
        return {
            r: c.r + (target.r - c.r) * amount,
            g: c.g + (target.g - c.g) * amount,
            b: c.b + (target.b - c.b) * amount
        }
    }

    function isValidHex(v) {
        return typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v)
    }

    // Accent slots worth considering: the saturated normal + bright rows.
    // color0/8 (backgrounds) and color7/15 (foregrounds) are excluded from
    // the vivid search; they serve as contrast references instead.
    readonly property var accentSlots: ["color1", "color2", "color3",
        "color4", "color5", "color6", "color9", "color10",
        "color11", "color12", "color13", "color14"]

    // Ranked vivid candidates from the live (or fallback) palette.
    function rankedAccents() {
        var pal = palette ? palette : fallbackPalette
        var bg = isValidHex(pal.color0) ? hexToRgb(pal.color0) : {r: 0, g: 0, b: 0}
        var bgLight = lightnessOf(bg) > 0.6
        var extreme = bgLight ? {r: 0, g: 0, b: 0} : {r: 1, g: 1, b: 1}
        var out = []
        for (var i = 0; i < accentSlots.length; i++) {
            var v = pal[accentSlots[i]]
            if (!isValidHex(v))
                continue
            var c = hexToRgb(v)
            var sat = saturationOf(c), li = lightnessOf(c)
            if (sat < 0.12 || li < 0.2 || li > 0.9)
                continue // grey, near-black, or near-white: not an accent
            // Contrast guard vs the palette background: nudge washed-out
            // picks toward the readable extreme instead of going invisible.
            if (Math.abs(li - lightnessOf(bg)) < 0.25)
                c = mixToward(c, extreme, 0.35)
            out.push({hex: rgbToHex(c), sat: sat, hue: hueOf(c)})
        }
        out.sort(function(a, b) { return b.sat - a.sat })
        return {list: out, bgLight: bgLight, bg: bg}
    }

    // Monochrome/muted fallback: a readable tone derived from the palette's
    // own foreground/background (light tone on dark wallpapers, dark tone
    // on light ones). Achromatic black/white are only mixing references.
    function monoTone(ranked, order) {
        var pal = palette ? palette : fallbackPalette
        var bg = ranked.bg, bgLight = ranked.bgLight
        var fg = isValidHex(pal.color7)
            ? hexToRgb(pal.color7) : (bgLight ? {r: 0, g: 0, b: 0} : {r: 1, g: 1, b: 1})
        var extreme = bgLight ? {r: 0, g: 0, b: 0} : {r: 1, g: 1, b: 1}
        var c = mixToward(fg, extreme, order === 0 ? 0.15 : 0.45)
        if (Math.abs(lightnessOf(c) - lightnessOf(bg)) < 0.3)
            c = mixToward(c, extreme, 0.4)
        return rgbToHex(c)
    }

    function autoColor(order) {
        var ranked = rankedAccents()
        if (ranked.list.length === 0)
            return monoTone(ranked, order)
        if (order === 0)
            return ranked.list[0].hex
        // Runner-up: hue-distinct from the primary so wave and bars read
        // as two voices; otherwise the next most vivid colour.
        var first = ranked.list[0]
        for (var i = 1; i < ranked.list.length; i++) {
            var h = ranked.list[i].hue, h0 = first.hue
            var dh = (h < 0 || h0 < 0) ? 999 : Math.abs(h - h0)
            if (dh > 180)
                dh = 360 - dh
            if (dh > 25)
                return ranked.list[i].hex
        }
        return ranked.list.length > 1 ? ranked.list[1].hex : ranked.list[0].hex
    }

    function slotColor(slot, fallbackKey) {
        var pal = palette ? palette : fallbackPalette
        var v = pal[slot]
        if (isValidHex(v))
            return v
        return fallbackPalette[fallbackKey]
    }

    // Derived semantic colours. Auto mode analyses the palette; manual mode
    // honours the configured slots (the pre-existing behaviour).
    readonly property color primary: autoAccent
        ? autoColor(0) : slotColor(primarySlot, "color4")
    readonly property color secondary: autoAccent
        ? autoColor(1) : slotColor(secondarySlot, "color5")
    readonly property color glow: {
        if (!autoAccent)
            return slotColor(glowSlot, "color6")
        // The glow follows the brighter accent for a lit-from-within feel.
        var a = hexToRgb(autoColor(0)), b = hexToRgb(autoColor(1))
        return lightnessOf(a) >= lightnessOf(b) ? autoColor(0) : autoColor(1)
    }
    readonly property color foreground: slotColor("color7", "color7")

    // ---- legibility roles (contrast-aware, still palette-derived) ----
    // Achromatic extreme farthest from the palette background: white on
    // dark themes, black on light ones. Used as the "readable" direction
    // for the bright core and as the veil/shadow base — never a blind
    // copy of the palette background, which may match the local wallpaper
    // and offer no separation at all.
    readonly property var contrastExtreme: {
        var pal = palette ? palette : fallbackPalette
        var bg = isValidHex(pal.color0) ? hexToRgb(pal.color0) : {r: 0, g: 0, b: 0}
        return lightnessOf(bg) > 0.6 ? {r: 0, g: 0, b: 0} : {r: 1, g: 1, b: 1}
    }

    function lift(hex, amount) {
        if (!isValidHex(hex))
            return hex
        return rgbToHex(mixToward(hexToRgb(hex), contrastExtreme, amount))
    }

    // Bright readable core for the wave and bars (amount from config).
    readonly property color core: lift(
        autoAccent ? autoColor(0) : slotColor(primarySlot, "color4"), brighten)
    readonly property color barCore: lift(
        autoAccent ? autoColor(1) : slotColor(secondarySlot, "color5"), brighten)

    // Contrasting under-stroke tone: hugs the palette background (dark on
    // dark themes, light on light ones) so it rings the bright core with
    // the opposite value — defining the wave exactly where the wallpaper
    // is brightest and glow alone would wash out. Kept near-bg so the
    // ring reads as depth, not as an outline.
    readonly property color shadow: {
        var pal = palette ? palette : fallbackPalette
        var bg = isValidHex(pal.color0) ? hexToRgb(pal.color0) : {r: 0, g: 0, b: 0}
        return rgbToHex(mixToward(bg, contrastExtreme, 0.08))
    }

    // Localized veil tone: background-family, so the veil melts into the
    // theme instead of reading as a tinted panel. Separation comes from
    // density, not hue: over bright wallpaper detail a bg-toned veil dims
    // the area behind the ribbon (dark themes) or lifts it (light themes),
    // while over matching areas it simply disappears. Fully transparent
    // at its edges by construction (see the renderer).
    readonly property color backdrop: {
        var pal = palette ? palette : fallbackPalette
        var bg = isValidHex(pal.color0) ? hexToRgb(pal.color0) : {r: 0, g: 0, b: 0}
        return rgbToHex(mixToward(bg, contrastExtreme, 0.2))
    }

    FileView {
        id: paletteFile
        path: root.resolvedPath
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    // Track palette health without spamming: flip paletteReady when the
    // parse result changes between null and non-null.
    onPaletteChanged: {
        var ok = palette !== null
        if (ok && !paletteReady) {
            paletteReady = true
        } else if (!ok && paletteReady) {
            paletteReady = false
            console.warn("[DreamcoreVisualizer] pywal palette unreadable at "
                + resolvedPath + " — using neutral fallback until it regenerates")
        }
    }
}
