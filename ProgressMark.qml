import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Commons as Commons

// The bar mark: a countdown ring around a small state glyph.
//
// Drawn rather than typed so the ring can shrink with the remaining time.
// The centre glyph is the state — play before the first block, a dot while it
// runs, pause bars while it is held — so a glance at the bar says both "how
// much is left" and "is it running" without reading the digits.
Item {
  id: root

  property real fraction: 1.0          // 0..1, share of the phase left
  property color color: Commons.Color.foreground
  property color trackColor: Util.alpha(root.color, 0.18)
  property string mark: "idle"         // idle | running | paused
  // 0..1, fired once when a phase ends: the mark takes a step outward and a
  // halo blooms under it, which is the only signal the bar gives for an event
  // that happens while the reader is looking at another window.
  property real pulse: 0
  property real thickness: Math.max(1, Math.round(root.width / 11))

  implicitWidth: Style.bar.iconCanvas
  implicitHeight: Style.bar.iconCanvas
  scale: 1 + root.pulse * 0.12

  readonly property real radius: Math.max(1, Math.min(width, height) / 2 - root.thickness / 2 - 0.5)
  readonly property real sweep: Math.max(0.01, 360 * Math.max(0, Math.min(1, root.fraction)))

  Rectangle {
    anchors.centerIn: parent
    width: parent.width * (1 + root.pulse * 0.55)
    height: width
    radius: height / 2
    visible: root.pulse > 0.01
    color: Util.alpha(root.color, 0.22 * root.pulse)
  }

  Shape {
    id: ring
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    // The track: a full circle, faint, so an empty ring still reads as a ring.
    ShapePath {
      strokeColor: root.trackColor
      strokeWidth: root.thickness
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      startX: root.width / 2
      startY: root.height / 2 - root.radius
      PathAngleArc {
        centerX: root.width / 2
        centerY: root.height / 2
        radiusX: root.radius
        radiusY: root.radius
        startAngle: -90
        sweepAngle: 359.99
      }
    }

    // What is left of the block, running clockwise from twelve.
    ShapePath {
      strokeColor: root.color
      strokeWidth: root.thickness
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      startX: root.width / 2
      startY: root.height / 2 - root.radius
      PathAngleArc {
        centerX: root.width / 2
        centerY: root.height / 2
        radiusX: root.radius
        radiusY: root.radius
        startAngle: -90
        sweepAngle: root.sweep
      }
    }
  }

  // Centre mark. Play reads as "not started"; a dot as "counting"; pause
  // bars as "held". Nothing animates: this is a status mark, not a control.
  Shape {
    visible: root.mark === "idle"
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: root.color
      strokeColor: "transparent"
      startX: root.width / 2 - root.width * 0.09
      startY: root.height / 2 - root.height * 0.13
      PathLine { x: root.width / 2 + root.width * 0.14; y: root.height / 2 }
      PathLine { x: root.width / 2 - root.width * 0.09; y: root.height / 2 + root.height * 0.13 }
      PathLine { x: root.width / 2 - root.width * 0.09; y: root.height / 2 - root.height * 0.13 }
    }
  }

  Rectangle {
    id: dot
    visible: root.mark === "running"
    anchors.centerIn: parent
    width: Math.max(3, Math.round(root.width * 0.24))
    height: width
    radius: width / 2
    color: root.color
  }

  Row {
    visible: root.mark === "paused"
    anchors.centerIn: parent
    spacing: Math.max(2, Math.round(root.width * 0.11))

    Repeater {
      model: 2

      Rectangle {
        width: Math.max(2, Math.round(root.width * 0.1))
        height: Math.max(4, Math.round(root.height * 0.3))
        radius: width / 2
        color: root.color
      }
    }
  }
}
