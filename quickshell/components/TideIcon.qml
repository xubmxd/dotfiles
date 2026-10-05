import QtQuick
import QtQuick.Shapes

// Central vector-icon set traced from Tide-Island's QML (Shape +
// PathSvg, CurveRenderer, round caps/joins everywhere):
//
//   search  clipboard/search magnifier, 16-unit viewBox, stroke 1.4
//   close   clear-query X, 8-unit viewBox, stroke 1.3
//   chevL   previous chevron, 14-unit viewBox, stroke 1.5
//   chevR   next chevron, 14-unit viewBox, stroke 1.5
//   chevD   down chevron (chevR mirrored across the diagonal), 14-unit
//
// The path is drawn in its native viewBox and auto-scaled to this
// item's width (assumed square). Set width/height (or Layout sizes)
// at the usage site; recolor via `color`; override `strokeWidth`
// when a heavier/lighter line is needed.
Item {
    id: root

    property string name: "close"
    property color color: "#ffffff"
    property real strokeWidth: 0 // 0 = per-icon Tide default
    // Filled mode for solid glyphs (transport icons). Fill uses `color`,
    // stroke is disabled.
    property bool fill: false

    // Transport glyphs live in the same 16-unit viewBox as search.
    readonly property real viewSize: {
        switch (root.name) {
        case "search": return 16
        case "close": return 8
        case "play": return 16
        case "pause": return 16
        case "prev": return 16
        case "next": return 16
        default: return 14
        }
    }

    readonly property string path: {
        switch (root.name) {
        case "search": return "M6.5 11.5a5 5 0 1 0 0-10 5 5 0 0 0 0 10z M10 10l3.5 3.5"
        case "close": return "M1 1l6 6 M7 1l-6 6"
        case "chevL": return "M9 3L4 7.5L9 12"
        case "chevR": return "M5 3L10 7.5L5 12"
        case "chevD": return "M3 5L7.5 10L12 5"
        case "play": return "M3 2.5 L13 8 L3 13.5 Z"
        case "pause": return "M3 3.5 h3.5 v9 h-3.5 Z M9.5 3.5 h3.5 v9 h-3.5 Z"
        case "prev": return "M2.5 3.5 h2 v9 h-2 Z M12.5 3.5 L8 8 L12.5 12.5 Z M8.5 3.5 L4 8 L8.5 12.5 Z"
        case "next": return "M11.5 3.5 h2 v9 h-2 Z M3.5 3.5 L8 8 L3.5 12.5 Z M7.5 3.5 L12 8 L7.5 12.5 Z"
        default: return "M1 1l6 6 M7 1l-6 6"
        }
    }

    readonly property real defaultStroke: {
        switch (root.name) {
        case "search": return 1.4
        case "close": return 1.3
        default: return 1.5
        }
    }

    Shape {
        width: root.viewSize
        height: root.viewSize
        scale: root.width > 0 ? root.width / root.viewSize : 1
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.fill ? root.color : "transparent"
            strokeColor: root.fill ? "transparent" : root.color
            strokeWidth: root.strokeWidth > 0 ? root.strokeWidth : root.defaultStroke
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg { path: root.path }
        }
    }
}
