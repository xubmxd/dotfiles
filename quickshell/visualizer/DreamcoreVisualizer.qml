// Dreamcore spectrum — bottom-centred music visualizer overlay.
//
// A transparent layer-shell window showing one composition: a thin organic
// glowing waveform with fine vertical spectrum bars, driven by live CAVA
// data (CavaService) and coloured from the pywal palette (VisualizerTheme).
// No album art, metadata, controls, cards, or backgrounds — the dynamic
// island keeps those jobs.
//
// Window behaviour: Bottom layer, zero exclusive zone, empty input mask
// (click-through, never steals focus), hidden entirely while inactive so no
// rendering work happens when silent.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root

    // Optional MPRIS source for the "mpris" visibility policy (bind the
    // island's MusicPlayerData). Unused in the default "auto" policy.
    property var musicData: null

    VisualizerConfig {
        id: config
    }

    VisualizerTheme {
        id: theme
        palettePath: config.palettePath
        primarySlot: config.primarySlot
        secondarySlot: config.secondarySlot
        glowSlot: config.glowSlot
        brighten: config.waveBrighten
    }

    CavaService {
        id: analyser
        enabled: config.enabled
        bars: config.bars
        framerate: config.framerate
        sensitivity: config.sensitivity
        smoothing: config.smoothing
        inputMethod: config.inputMethod
        activityThreshold: config.activityThreshold
        activityHoldMs: config.silenceTimeoutMs
        onFrameReady: {
            if (!root.shown)
                return
            var now = Date.now()
            // Rate cap: analysis runs at full framerate (smoothing and
            // activity detection stay fluid) while the canvas redraws at
            // most every 16 ms (~60 fps target).
            if (now - spectrum._lastPaintMs < 16)
                return
            // Content-static skip: repaint only when the painted picture
            // would actually change. During steady tones or quiet passages
            // the wave converges and paints drop to near zero; transients
            // still render at full rate. The 500 ms backstop bounds any
            // drift well below a pixel.
            var lv = analyser.levels, pv = root._paintLevels
            var eps = config.repaintEpsilon > 0 ? config.repaintEpsilon : 0.004
            var maxGap = config.repaintMaxIntervalMs > 0 ? config.repaintMaxIntervalMs : 500
            var dirty = (now - spectrum._lastPaintMs > maxGap)
            if (!dirty) {
                if (!pv || pv.length !== lv.length) {
                    dirty = true
                } else {
                    for (var i = 0; i < lv.length; i++) {
                        var d = lv[i] - pv[i]
                        if (d > eps || d < -eps) {
                            dirty = true
                            break
                        }
                    }
                }
            }
            if (!dirty)
                return
            spectrum._lastPaintMs = now
            root._paintLevels = lv.slice()
            spectrum.requestPaint()
        }
    }

    // Snapshot of levels at the last repaint; compared against live
    // levels to skip visually identical frames. Small, bounded, stable.
    property var _paintLevels: []

    // "auto" leaves placement to the compositor (exactly like the dynamic
    // island, which sets no screen): the binding below stays inactive.
    // "focused" follows Hyprland; any other value pins a matching name.
    property var targetScreenObj: {
        var policy = config.targetScreen
        if (!policy || policy === "auto")
            return null
        var screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return null
        if (policy === "focused") {
            var focused = Hyprland.focusedMonitor
            var name = focused ? focused.name : ""
            for (var i = 0; i < screens.length; i++) {
                if (screens[i].name === name)
                    return screens[i]
            }
            return null
        }
        for (var j = 0; j < screens.length; j++) {
            if (screens[j].name === policy)
                return screens[j]
        }
        return null
    }

    Binding {
        target: root
        property: "screen"
        value: root.targetScreenObj
        when: config.targetScreen !== "auto" && root.targetScreenObj !== null
    }

    // ----------------------------------------------------------
    // Transparent overlay plumbing.
    // ----------------------------------------------------------
    color: "transparent"
    focusable: false
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "dreamcore-visualizer"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Empty mask: the strip never intercepts mouse clicks.
    mask: Region {}

    anchors {
        left: true
        right: true
        bottom: true
    }
    margins.bottom: Math.round(config.bottomOffsetPx)

    implicitHeight: Math.round(config.canvasHeightPx + config.canvasPadPx)

    // Hidden when disabled or faded out: no window, no repaints.
    visible: config.enabled && root.shown

    // ----------------------------------------------------------
    // Visibility state machine (fade in on activity, hold through
    // quiet passages via the service hold timer, fade out after).
    // ----------------------------------------------------------
    property bool shown: false

    readonly property bool mprisPlaying: (musicData !== null
        && musicData !== undefined) && musicData.isPlaying === true

    readonly property bool wantVisible: {
        if (!config.enabled)
            return false
        if (config.visibilityPolicy === "always")
            return true
        if (config.visibilityPolicy === "mpris")
            return mprisPlaying
        return analyser.audioActive
    }

    onWantVisibleChanged: {
        if (wantVisible) {
            hideTimer.stop()
            if (!shown) {
                shown = true
                spectrum.requestPaint()
            }
        } else if (shown) {
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: config.fadeOutMs + 80
        repeat: false
        onTriggered: {
            if (!root.wantVisible)
                root.shown = false
        }
    }

    // ----------------------------------------------------------
    // Centred composition.
    // ----------------------------------------------------------
    readonly property real screenW: (screen && screen.width > 0)
        ? screen.width : 1920
    readonly property real visW: Math.max(0, Math.min(screenW * config.widthFraction,
        config.maxWidthPx) - 2 * config.sideMarginPx)
    readonly property real visH: config.canvasHeightPx

    Item {
        id: stage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        width: Math.round(root.visW)
        height: Math.round(root.visH + config.canvasPadPx)
        opacity: root.wantVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.wantVisible ? config.fadeInMs : config.fadeOutMs
                easing.type: Easing.InOutQuad
            }
        }

        // Static contrast veil on its own layer: identical output to a
        // per-frame fill, but repainted only when geometry, theme, or
        // opacity change — the expensive radial gradient stays out of
        // the 20 fps animation loop entirely.
        Canvas {
            id: veil
            anchors.fill: parent
            renderTarget: Canvas.Image
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            function withAlpha(c, a) {
                return Qt.rgba(c.r, c.g, c.b, a)
            }

            onPaint: {
                var ctx = getContext("2d")
                var W = width, H = height
                ctx.reset()
                if (W <= 0 || H <= 0)
                    return
                // Elliptical radial gradient sized to stay fully inside
                // the canvas, fading to zero before any edge — separation
                // with no panel, border, or rectangular boundary.
                if (config.backdropOpacity <= 0.001)
                    return
                var vrx = W * 0.5, vry = H * 0.44
                ctx.save()
                ctx.translate(W / 2, H * 0.55)
                ctx.scale(1, vry / vrx)
                var vg = ctx.createRadialGradient(0, 0, 0, 0, 0, vrx)
                vg.addColorStop(0, withAlpha(theme.backdrop, config.backdropOpacity))
                vg.addColorStop(0.6, withAlpha(theme.backdrop, config.backdropOpacity * 0.45))
                vg.addColorStop(1, withAlpha(theme.backdrop, 0))
                ctx.fillStyle = vg
                ctx.beginPath()
                ctx.arc(0, 0, vrx, 0, Math.PI * 2)
                ctx.fill()
                ctx.restore()
            }
        }

        Canvas {
            id: spectrum
            anchors.fill: parent
            renderTarget: Canvas.Image
            property double _lastPaintMs: 0
            onWidthChanged: if (root.shown) requestPaint()
            onHeightChanged: if (root.shown) requestPaint()

            // Previous-frame wave heights: the faint redraw that reads as
            // a luminous trail. Updated only while visible.
            property var trail: []

            function withAlpha(c, a) {
                return Qt.rgba(c.r, c.g, c.b, a)
            }

            // Classic smoothstep: 0 below e0, eased 0..1 through the
            // interval, 1 above e1. The building block of the edge fade.
            function smoothstep(e0, e1, x) {
                var t = Math.max(0, Math.min(1, (x - e0) / (e1 - e0)))
                return t * t * (3 - 2 * t)
            }

            // Horizontal visibility envelope shared by EVERY visual layer.
            // Full strength through the central region, smoothstep fade to
            // exactly zero at both outer edges (t in 0..1 across the full
            // width). Opacity only — audio data is never touched for this.
            function edgeEnv(t) {
                var f = Math.max(0, Math.min(0.45, config.edgeFadeFraction))
                if (f <= 0.001)
                    return 1
                return smoothstep(0, f, t) * smoothstep(0, f, 1 - t)
            }

            // Gradient stroke sampling the envelope at several stops, so
            // wave, bars, under-stroke, glow, and trails all dissolve with
            // the same long soft fade. End stops are pure transparency:
            // edges genuinely disappear (alpha compositing) instead of
            // darkening, on any wallpaper.
            function fadeGrad(ctx, w, c, peak) {
                var g = ctx.createLinearGradient(0, 0, w, 0)
                var stops = [0, 0.06, 0.12, 0.2, 0.32, 0.5, 0.68, 0.8, 0.88, 0.94, 1]
                for (var k = 0; k < stops.length; k++)
                    g.addColorStop(stops[k], withAlpha(c, peak * edgeEnv(stops[k])))
                return g
            }

            // Centre-weighted taper: full response in the middle, dissolving
            // toward the edges (t in 0..1 across the width).
            function taper(t) {
                var d = (t - 0.5) / 0.33
                return 0.10 + 0.90 * Math.exp(-d * d)
            }

            function strokeSmooth(ctx, xs, ys) {
                var m = xs.length
                ctx.beginPath()
                ctx.moveTo(xs[0], ys[0])
                for (var j = 1; j < m - 1; j++) {
                    var mx = (xs[j] + xs[j + 1]) / 2
                    var my = (ys[j] + ys[j + 1]) / 2
                    ctx.quadraticCurveTo(xs[j], ys[j], mx, my)
                }
                ctx.lineTo(xs[m - 1], ys[m - 1])
                ctx.stroke()
            }

            onPaint: {
                var ctx = getContext("2d")
                var W = width, H = height
                ctx.reset()
                if (W <= 0 || H <= 0)
                    return
                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                var glowI = Math.max(0, Math.min(1.5, config.glowIntensity))
                var levels = analyser.levels
                var n = (levels && levels.length > 0) ? levels.length : 0

                // Resample the N bands into M smooth wave points. Gamma < 1
                // lifts quiet mid-levels perceptually; values stay in 0..1
                // so loud passages saturate gracefully instead of clipping.
                var M = 110
                var xs = [], ys = []
                // Centre slightly below middle: air above for crests and
                // bar tips (see canvasPadPx), room below for the reflection.
                var midY = H * 0.55
                var amp = H * config.waveAmplitudeFraction
                var gamma = config.waveGamma > 0 ? config.waveGamma : 1
                for (var j = 0; j < M; j++) {
                    var t = M === 1 ? 0.5 : j / (M - 1)
                    var x = t * W
                    var v = 0
                    if (n > 0) {
                        var pos = t * (n - 1)
                        var i0 = Math.floor(pos)
                        var i1 = Math.min(n - 1, i0 + 1)
                        var f = pos - i0
                        v = levels[i0] * (1 - f) + levels[i1] * f
                    }
                    v = Math.pow(Math.max(0, Math.min(1, v)), gamma) * taper(t)
                    xs.push(x)
                    ys.push(midY - v * amp)
                }

                // 1. Trail: previous wave, very faint.
                if (trail.length === M) {
                    ctx.lineWidth = 4.0
                    ctx.strokeStyle = fadeGrad(ctx, W, theme.glow, 0.12 * glowI + 0.03)
                    strokeSmooth(ctx, xs, trail)
                }

                // 2. Reflection: mirrored wave below the centre.
                var refl = []
                for (var k = 0; k < M; k++)
                    refl.push(midY + (midY - ys[k]) * 0.55)
                ctx.lineWidth = 1.4
                ctx.strokeStyle = fadeGrad(ctx, W, theme.glow, 0.20 * glowI + 0.04)
                strokeSmooth(ctx, xs, refl)

                // 3. Bars: subordinate texture straddling the wave itself —
                // half above, half below — so they read as the ribbon's
                // grain rather than a separate equalizer row. A dark
                // under-stroke pass keeps each tick distinct on bright
                // wallpaper; the bright pass carries the colour.
                if (n > 0) {
                    var maxBarH = H * config.maxBarHeightFraction
                    var segs = []
                    for (var i = 0; i < n; i++) {
                        var bt = n === 1 ? 0.5 : i / (n - 1)
                        var bx = (i + 0.5) / n * W
                        // Same gamma lift as the wave: bars and curve move
                        // as one voice across quiet and loud passages.
                        var bv = Math.pow(Math.max(0, Math.min(1, levels[i])), gamma)
                        var bh = bv * taper(bt) * maxBarH
                        if (bh < 0.6)
                            continue
                        // Wave height at this band (same resampling as above).
                        var bpos = bt * (M - 1)
                        var b0 = Math.floor(bpos)
                        var b1 = Math.min(M - 1, b0 + 1)
                        var bf = bpos - b0
                        var by = ys[b0] * (1 - bf) + ys[b1] * bf
                        // Hard guarantee: bar tips can never leave the
                        // canvas (Canvas clips at its bounds, which read
                        // as chopped peaks). Only bites at full scale.
                        var y1 = Math.max(2, by - bh / 2)
                        var y2 = Math.min(H - 2, by + bh / 2)
                        if (y2 - y1 < 0.6)
                            continue
                        segs.push(bx, y1, bx, y2)
                    }
                    if (segs.length > 0) {
                        ctx.lineWidth = Math.max(1, config.barWidthPx) + 1.2
                        ctx.strokeStyle = fadeGrad(ctx, W, theme.shadow, config.shadowOpacity * 0.6)
                        ctx.beginPath()
                        for (var s = 0; s < segs.length; s += 4) {
                            ctx.moveTo(segs[s], segs[s + 1])
                            ctx.lineTo(segs[s + 2], segs[s + 3])
                        }
                        ctx.stroke()
                        ctx.lineWidth = Math.max(1, config.barWidthPx)
                        ctx.strokeStyle = fadeGrad(ctx, W, theme.barCore, 0.5)
                        ctx.beginPath()
                        for (var q = 0; q < segs.length; q += 4) {
                            ctx.moveTo(segs[q], segs[q + 1])
                            ctx.lineTo(segs[q + 2], segs[q + 3])
                        }
                        ctx.stroke()
                    }
                }

                // 4. Wave stack: contrasting under-stroke (definition where
                // glow would wash out), soft halo, then the crisp bright
                // core — one organic ribbon of sound.
                ctx.lineWidth = config.coreWidthPx + 3.2
                ctx.strokeStyle = fadeGrad(ctx, W, theme.shadow, config.shadowOpacity)
                strokeSmooth(ctx, xs, ys)
                ctx.lineWidth = config.glowWidthPx
                ctx.strokeStyle = fadeGrad(ctx, W, theme.glow, 0.16 * glowI + 0.04)
                strokeSmooth(ctx, xs, ys)
                ctx.lineWidth = config.glowWidthPx * 0.45
                ctx.strokeStyle = fadeGrad(ctx, W, theme.primary, 0.38 * glowI + 0.08)
                strokeSmooth(ctx, xs, ys)
                ctx.lineWidth = config.coreWidthPx
                ctx.strokeStyle = fadeGrad(ctx, W, theme.core, 0.95)
                strokeSmooth(ctx, xs, ys)

                // Snapshot for the next frame's trail (only while shown;
                // paint stops entirely once hidden).
                trail = ys.slice()
            }
        }

        // Repaint when derived colours change so wallpaper switches
        // recolour live (backdrop/shadow/core track the palette too).
        // The static veil repaints on its own schedule; the wave canvas
        // repaints immediately (bypassing the animation throttle).
        Connections {
            target: theme
            function onPrimaryChanged() { if (root.shown) spectrum.requestPaint() }
            function onSecondaryChanged() { if (root.shown) spectrum.requestPaint() }
            function onGlowChanged() { if (root.shown) spectrum.requestPaint() }
            function onCoreChanged() { if (root.shown) spectrum.requestPaint() }
            function onShadowChanged() { if (root.shown) spectrum.requestPaint() }
            function onBackdropChanged() { veil.requestPaint(); if (root.shown) spectrum.requestPaint() }
        }

        Connections {
            target: config
            function onBackdropOpacityChanged() { veil.requestPaint() }
        }
    }

    Component.onDestruction: {
        hideTimer.stop()
    }
}
