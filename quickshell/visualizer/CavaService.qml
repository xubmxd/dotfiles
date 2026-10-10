// Dreamcore spectrum — CAVA audio-analysis service.
//
// Owns the `cava` child process (raw ascii output over stdout, default
// playback-monitor source) and exposes normalized, smoothed spectrum data:
//   levels      — in-place-updated array of `bars` values in 0..1
//   level       — overall mean energy (0..1, smoothed)
//   audioActive — hysteresis-held activity flag for visibility
//   frameReady  — emitted per parsed frame; the renderer repaints on it
//
// Capture and rendering stay decoupled: this service never touches Canvas.
// The cava config is generated into Quickshell.cacheDir (portable, no home
// path assumptions) with `method`/`source` left at the backend default
// ("auto" monitor of the default sink) so no device name is hardcoded.
//
// Lifecycle: at most one cava instance, run directly (no shell wrapper)
// so the Process owns it exactly. Rapid-exit backoff with a pipewire→pulse
// fallback on fast startup failures only, then slow re-arm retries so
// a late `pacman -S cava` starts working without a Quickshell restart.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ---- inputs (bound from VisualizerConfig by the parent) ----
    property bool enabled: true
    property int bars: 64
    property int framerate: 30
    property real sensitivity: 1.2
    property real smoothing: 0.55
    property string inputMethod: "auto" // auto|pipewire|pulse
    property real activityThreshold: 0.02
    property int activityHoldMs: 2500

    // ---- outputs ----
    property var levels: []       // smoothed 0..1 spectrum, length == bars
    property real level: 0        // smoothed mean energy 0..1
    property bool audioActive: false
    property bool backendAvailable: false
    property string status: "idle" // idle|starting|running|waiting|error
    signal frameReady()

    // ---- internals ----
    property int clampedBars: Math.max(8, Math.min(256, bars))
    property int clampedFramerate: Math.max(10, Math.min(60, framerate))
    property real asciiMax: 100
    property int _activeStreak: 0
    property double _lastActiveAt: 0
    property bool _expectStop: false
    property int _failures: 0
    property bool _triedPulseFallback: false
    property string _effectiveMethod: "pipewire" // resolved from inputMethod
    property string _configFile: ""
    property bool _configReady: false
    property double _startedAt: 0

    readonly property string configSignature: clampedBars + "x"
        + clampedFramerate + ":" + inputMethod

    Component.onCompleted: {
        initArrays()
        if (enabled)
            writeConfig()
    }

    Component.onDestruction: {
        _expectStop = true
        cavaProc.running = false
    }

    onEnabledChanged: {
        if (enabled) {
            _failures = 0
            _triedPulseFallback = false
            initArrays()
            writeConfig()
        } else {
            _expectStop = true
            cavaProc.running = false
            rearmTimer.stop()
            root.status = "idle"
            root.backendAvailable = false
            root.audioActive = false
        }
    }

    onConfigSignatureChanged: {
        if (!enabled)
            return
        _expectStop = true
        cavaProc.running = false
        initArrays()
        writeConfig()
    }

    function initArrays() {
        var n = clampedBars, a = []
        for (var i = 0; i < n; i++) {
            a.push(0)
        }
        // levels is mutated in place per frame (no per-frame allocation);
        // a fresh array is assigned only when the band count changes.
        root.levels = a
        root.level = 0
        _activeStreak = 0
    }

    // Resolve the cava input method: explicit choice wins; "auto" prefers
    // pipewire (native on this rice) with a pulse fallback on failure.
    function resolveMethod() {
        if (inputMethod === "pulse" || inputMethod === "pipewire")
            return inputMethod
        return _triedPulseFallback ? "pulse" : "pipewire"
    }

    function cavaConfigText() {
        return "[general]\n"
            + "framerate = " + clampedFramerate + "\n"
            + "bars = " + clampedBars + "\n"
            + "autosens = 0\n"
            + "sensitivity = 100\n"
            + "\n[input]\n"
            + "method = " + _effectiveMethod + "\n"
            + "source = auto\n"
            + "\n[output]\n"
            + "method = raw\n"
            + "channels = mono\n"
            + "raw_target = /dev/stdout\n"
            + "data_format = ascii\n"
            + "ascii_max_range = " + asciiMax + "\n"
            + "bar_delimiter = 59\n"
            + "frame_delimiter = 10\n"
            + "\n[smoothing]\n"
            + "noise_reduction = 77\n"
    }

    function writeConfig() {
        _effectiveMethod = resolveMethod()
        root.status = "starting"
        _configReady = false
        // Uptime baseline for fast-failure detection (covers backends that
        // exit before onStarted ever fires).
        root._startedAt = Date.now()
        var dir = Quickshell.cacheDir + "/dreamcore-visualizer"
        var file = dir + "/cava.conf"
        _configFile = file
        // No single quotes appear in cavaConfigText(), so the heredoc below
        // cannot break out of its quoting.
        var script = "mkdir -p '" + dir + "' && cat > '" + file
            + "' <<'DREAMCORE_CAVA_EOF'\n" + cavaConfigText()
            + "DREAMCORE_CAVA_EOF\n"
            + "command -v cava >/dev/null 2>&1 || exit 127\n"
        setupProc.exec(["sh", "-c", script])
    }

    // One-shot setup: writes the config, verifies the binary exists.
    Process {
        id: setupProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            if (!root.enabled)
                return
            if (exitCode === 127) {
                root.status = "error"
                root.backendAvailable = false
                console.warn("[DreamcoreVisualizer] `cava` not found in PATH "
                    + "— install it (`pacman -S cava` on Arch; pipewire or "
                    + "pulseaudio provides the capture source) and the "
                    + "visualizer will start automatically. Rice continues "
                    + "without it.")
                scheduleRearm()
                return
            }
            if (exitCode !== 0) {
                console.warn("[DreamcoreVisualizer] could not write cava "
                    + "config (exit " + exitCode + ") — retrying")
                scheduleRearm()
                return
            }
            root._configReady = true
            root._expectStop = false
            cavaProc.running = true
        }
    }

    // The live analyser, run directly (no shell wrapper) so the Process
    // PID *is* cava: stopping the Process reaps it, leaving no orphans.
    Process {
        id: cavaProc
        running: false
        command: ["cava", "-p", root._configFile]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) { root.handleFrame(data) }
        }
        stderr: StdioCollector {}
        onStarted: {
            root.status = "running"
            root.backendAvailable = true
            root._failures = 0
            root._startedAt = Date.now()
        }
        onExited: function(exitCode) {
            if (root._expectStop) {
                root._expectStop = false
                return
            }
            if (!root.enabled)
                return
            root.backendAvailable = false
            // Method fallback only on FAST failures (broken backend at
            // startup). A backend that ran fine and then died (device
            // unplug, kill) restarts with the same method — flipping
            // methods on every late crash would wedge a healthy setup.
            var uptime = Date.now() - root._startedAt
            if (uptime < 5000 && !_triedPulseFallback && root.inputMethod === "auto"
                    && _effectiveMethod === "pipewire") {
                _triedPulseFallback = true
                console.warn("[DreamcoreVisualizer] cava (pipewire) failed "
                    + "at startup (code " + exitCode + ") — retrying with pulse input")
                writeConfig()
                return
            }
            // A failed pulse fallback reverts to the pipewire default so a
            // later re-arm retries the preferred backend, not the broken one.
            if (uptime < 5000 && _triedPulseFallback && _effectiveMethod === "pulse") {
                _triedPulseFallback = false
                console.warn("[DreamcoreVisualizer] cava (pulse) failed "
                    + "at startup (code " + exitCode + ") — reverting to pipewire")
            }
            _failures += 1
            if (_failures <= 3) {
                root.status = "waiting"
                console.warn("[DreamcoreVisualizer] cava exited (code "
                    + exitCode + ", attempt " + _failures + "/3) — retrying")
                retryTimer.restart()
            } else {
                root.status = "error"
                console.warn("[DreamcoreVisualizer] cava keeps failing — "
                    + "visualizer parked (rice unaffected). Fix audio/cava "
                    + "and it re-arms automatically.")
                scheduleRearm()
            }
        }
    }

    Timer {
        id: retryTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.enabled && !cavaProc.running) {
                root._expectStop = false
                cavaProc.running = true
            }
        }
    }

    // Slow re-arm (also covers installing cava after startup).
    Timer {
        id: rearmTimer
        interval: 30000
        repeat: false
        onTriggered: {
            if (!root.enabled)
                return
            root._failures = 0
            root.writeConfig()
        }
    }

    function scheduleRearm() {
        if (root.enabled && !rearmTimer.running)
            rearmTimer.restart()
    }

    // Silence-hold watchdog: keeps audioActive asserted for activityHoldMs
    // after the last above-threshold frame (hysteresis against quiet
    // passages flickering the visualizer).
    Timer {
        id: holdTimer
        interval: 250
        repeat: true
        running: root.enabled
        onTriggered: {
            if (root.audioActive && (Date.now() - root._lastActiveAt) > root.activityHoldMs)
                root.audioActive = false
        }
    }

    // Parse one cava ascii frame ("v;v;...;v;") and update levels in place:
    // normalize → sensitivity → attack/decay smoothing → energy bookkeeping.
    // Malformed lines are dropped silently (cava can emit a partial line on
    // restart); no exceptions may escape into bindings.
    function handleFrame(data) {
        try {
            if (typeof data !== "string" || data.length === 0)
                return
            var parts = data.split(";")
            var n = clampedBars
            if (parts.length < n)
                return
            var sens = sensitivity > 0 ? sensitivity : 1
            var sm = Math.max(0, Math.min(0.95, smoothing))
            var attack = 1 - sm * 0.4   // fast rise keeps transients alive
            var decay = 1 - sm          // slow fall gives the floaty trail
            var sum = 0
            for (var i = 0; i < n; i++) {
                var v = parseFloat(parts[i])
                if (isNaN(v) || v < 0)
                    v = 0
                var target = Math.min(1, (v / asciiMax) * sens)
                var cur = levels[i]
                if (target >= cur)
                    cur += (target - cur) * attack
                else
                    cur += (target - cur) * decay
                if (cur < 0.0005)
                    cur = target === 0 ? 0 : cur
                levels[i] = cur
                sum += cur
            }
            var mean = sum / n
            level += (mean - level) * 0.35
            backendAvailable = true
            if (status !== "running")
                status = "running"

            // Sustained-activity gate: 2 consecutive above-threshold frames
            // to fade in (rejects single-frame blips), hold timer to fade out.
            if (mean >= activityThreshold) {
                _activeStreak += 1
                _lastActiveAt = Date.now()
                if (_activeStreak >= 2 && !audioActive)
                    audioActive = true
            } else {
                _activeStreak = 0
            }
            frameReady()
        } catch (error) {
            console.warn("[DreamcoreVisualizer] dropping spectrum frame:", error)
        }
    }
}
