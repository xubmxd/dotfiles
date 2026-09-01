pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// ================================================================
// BLUETOOTH SERVICE
// ----------------------------------------------------------------
// Thin, reactive wrapper around Quickshell's native Quickshell.Bluetooth
// module (BlueZ over DBus). This replaces shelling out to `bluetoothctl`
// with real, event-driven state so the UI never has to poll.
//
// Drop this file in services/ next to your other singletons (e.g.
// NotificationService) — `pragma Singleton` plus this project's existing
// `import "services"` directory import is all that's needed, no qmldir
// entry required, exactly like the rest of services/.
// ================================================================

QtObject {
    id: root

    // ------------------------------------------------------------
    // ADAPTER
    // ------------------------------------------------------------

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null

    readonly property bool powered: available && adapter.enabled
    readonly property bool discovering: available && adapter.discovering
    readonly property string adapterName: available ? adapter.name : ""

    function setPowered(on) {
        if (available)
            adapter.enabled = on
    }

    function setDiscovering(on) {
        if (available && adapter.enabled)
            adapter.discovering = on
    }

    // ------------------------------------------------------------
    // DEVICE LISTS
    // ------------------------------------------------------------
    // Quickshell exposes devices as an ObjectModel; we re-derive plain
    // JS arrays so QML ListViews can section them the way macOS/iOS do:
    // connected first, then other known ("my") devices, then nearby
    // unpaired devices discovered while scanning.

    readonly property var _deviceModel: available ? adapter.devices : null

    readonly property int deviceCount: _deviceModel ? _deviceModel.count : 0

    readonly property var connectedDevices: {
        const out = []
        if (!_deviceModel) return out
        for (let i = 0; i < _deviceModel.count; i++) {
            const d = _deviceModel.get(i)
            if (d && d.connected) out.push(d)
        }
        return out
    }

    readonly property var myDevices: {
        const out = []
        if (!_deviceModel) return out
        for (let i = 0; i < _deviceModel.count; i++) {
            const d = _deviceModel.get(i)
            if (d && d.paired && !d.connected) out.push(d)
        }
        return out
    }

    readonly property var otherDevices: {
        const out = []
        if (!_deviceModel) return out
        for (let i = 0; i < _deviceModel.count; i++) {
            const d = _deviceModel.get(i)
            if (d && !d.paired) out.push(d)
        }
        return out
    }

    readonly property int connectedCount: connectedDevices.length

    // A short label for compact surfaces (dashboard card, idle pill, etc.)
    readonly property string summaryLabel: {
        if (!powered) return "Off"
        if (connectedCount === 0) return "On"
        if (connectedCount === 1) return connectedDevices[0].name
        return connectedCount + " Connected"
    }

    // ------------------------------------------------------------
    // ACTIONS
    // ------------------------------------------------------------
    // All of these are thin pass-throughs — kept here so views never
    // touch BlueZ objects directly and so behavior can be centralized
    // (logging, toasts, etc.) later without touching the UI.

    function connectDevice(device) {
        if (device) device.connect()
    }

    function disconnectDevice(device) {
        if (device) device.disconnect()
    }

    function pairDevice(device) {
        if (device) device.pair()
    }

    function cancelPair(device) {
        if (device) device.cancelPair()
    }

    function forgetDevice(device) {
        if (device) device.forget()
    }

    function setTrusted(device, trusted) {
        if (device) device.trusted = trusted
    }

    // Apple-style single tap behavior:
    //  - unpaired device  -> pair (BlueZ auto-connects most profiles post-pair)
    //  - paired, offline  -> connect
    //  - paired, online   -> disconnect
    function toggleDevice(device) {
        if (!device) return
        if (!device.paired) {
            pairDevice(device)
        } else if (device.connected) {
            disconnectDevice(device)
        } else {
            connectDevice(device)
        }
    }

    // ------------------------------------------------------------
    // ICON HELPERS
    // ------------------------------------------------------------
    // Glyph icons (Nerd Font) are used instead of themed raster icons to
    // stay visually consistent with the rest of the island. `device.icon`
    // is a standard freedesktop icon name BlueZ reports (e.g.
    // "audio-headset", "input-mouse", "input-keyboard") — a ready-made
    // hook for per-device-type icons. Only the single Bluetooth glyph
    // already used elsewhere in this project (U+F00AF) is wired up by
    // default, since Nerd Font codepoints for Material Design Icons
    // differ between font versions/builds and a wrong guess renders as
    // tofu. Look up exact codepoints for your installed font at
    // nerdfonts.com/cheat-sheet and extend the cases below if you want
    // per-type icons.

    function glyphFor(device) {
        const hint = (device && device.icon) ? device.icon.toLowerCase() : ""

        // Example extension points (commented out until you've confirmed
        // the codepoints against your own font):
        // if (hint.indexOf("headset") !== -1) return "\uXXXXX"
        // if (hint.indexOf("mouse") !== -1)    return "\uXXXXX"
        // if (hint.indexOf("keyboard") !== -1) return "\uXXXXX"

        return "\u{f00af}" // 󰂯 bluetooth glyph — verified present in this project's font
    }

    // Human status label used by the row + detail sheet.
    function statusFor(device) {
        if (!device) return ""
        if (device.pairing) return "Pairing…"
        if (device.connected) return "Connected"
        if (device.paired) return "Not Connected"
        return "Not Paired"
    }
}
