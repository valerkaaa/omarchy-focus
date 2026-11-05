import QtQuick
import QtQuick.Shapes
import qs.Commons

// The progress ring inside the panel hero: a faint track, a gradient sweep
// with a lit head, and a halo behind it. Pure graphics — the digits live on
// top of it, owned by the panel.
Item {
  id: root

  property real fraction: 1.0              // 1..0, share of the phase left
  property bool paused: false
  property bool running: false
  // 0..1, driven by the spring below: the head pips outward on a start or a
  // pause and settles back, which is the one physical gesture in the panel.
  property real kick: 0
  // Degrees the whole minute scale clicks round with the head. Small on
  // purpose: the scale should feel sprung, not spin.
  readonly property real scaleKick: root.kick * 3
  // Counted so the gesture can be proven from IPC: a still screenshot cannot
  // say whether the spring fired.
  property int kicks: 0
  property color tintFrom: "#9C86FF"
  property color tintTo: "#3D7DFF"
  property real thickness: 8                // in design units, scaled below

  readonly property real s: Style.fontScale
  function px(n) { return Math.max(1, Math.round(n * s)) }

  readonly property real stroke: root.px(root.thickness)
  // Room for the minute scale outside the sweep: the ticks are part of the
  // instrument, so the ring sits one band in from the edge.
  readonly property real tickBand: root.px(11)
  readonly property real radius: Math.max(1, Math.min(width, height) / 2 - stroke / 2 - root.tickBand)
  readonly property real tickLength: root.px(4)
  readonly property real sweep: 360 * Math.max(0, Math.min(1, root.fraction))
  readonly property real headAngle: (-90 + root.sweep) * Math.PI / 180
  readonly property real headX: width / 2 + (radius + root.kick * root.px(4)) * Math.cos(headAngle)
  readonly property real headY: height / 2 + (radius + root.kick * root.px(4)) * Math.sin(headAngle)

  // A start winds the head out and lets it settle; a pause does the same, so
  // both edges of the state feel mechanical rather than like a repaint.
  SequentialAnimation {
    id: kickAnim
    NumberAnimation {
      target: root; property: "kick"; to: 1.0
      duration: 130; easing.type: Easing.OutBack; easing.overshoot: 2.6
    }
    NumberAnimation {
      target: root; property: "kick"; to: 0.0
      duration: 320; easing.type: Easing.OutCubic
    }
  }
  onRunningChanged: { root.kicks += 1; kickAnim.restart() }
  onPausedChanged: if (root.paused) { root.kicks += 1; kickAnim.restart() }

  // The alpha a given tick is actually painted with, so the fade can be
  // proven from IPC instead of guessed from a screenshot.
  function tickAlpha(index) {
    var tick = ticksRepeater.itemAt(index)
    return tick ? Math.round(tick.color.a * 1000) / 1000 : -1
  }

  opacity: root.paused ? 0.55 : 1.0
  Behavior on opacity { NumberAnimation { duration: 180 } }

  // The bloom behind the ring: a soft violet disc, so the ring sits in light
  // instead of on a flat fill.
  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: "transparent"
      fillGradient: RadialGradient {
        centerX: root.width / 2
        centerY: root.height / 2
        centerRadius: root.width * 0.52
        focalX: root.width / 2
        focalY: root.height / 2
        focalRadius: 0
        GradientStop { position: 0.0; color: Qt.rgba(0.42, 0.32, 0.95, 0.11) }
        GradientStop { position: 0.62; color: Qt.rgba(0.28, 0.24, 0.72, 0.07) }
        GradientStop { position: 1.0; color: Qt.rgba(0.10, 0.12, 0.35, 0.0) }
      }
      startX: root.width / 2
      startY: root.height / 2 - root.width * 0.52
      PathAngleArc {
        centerX: root.width / 2
        centerY: root.height / 2
        radiusX: root.width * 0.52
        radiusY: root.width * 0.52
        startAngle: -90
        sweepAngle: 359.99
      }
    }
  }


  // Minute scale: sixty ticks, every fifth one long. Drawn as rectangles
  // rotated about the centre rather than as a Shape, so it costs nothing to
  // keep static while the sweep animates.
  Repeater {
    id: ticksRepeater
    model: 60

    Rectangle {
      objectName: "tick"
      required property int index
      readonly property bool major: index % 5 === 0
      width: root.px(major ? 1.6 : 1.1)
      height: root.px(major ? 6.5 : 3.4)
      radius: width / 2
      // A tick behind the head is time already spent: it fades instead of
      // competing with the ticks that still count.
      readonly property real pos: index * 6
      readonly property bool spent: pos > root.sweep + 0.5
      color: Qt.rgba(1, 1, 1, (major ? 0.30 : 0.14) * (spent ? 0.34 : 1.0))
      x: root.width / 2 - width / 2
      y: root.width / 2 - root.radius - root.stroke / 2 - root.tickBand + root.px(1)
      transform: Rotation {
        origin.x: root.width / 2 - x
        origin.y: root.height / 2 - y
        angle: index * 6 + root.scaleKick
      }
    }
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    // Track: a full circle, faint, so an empty ring still reads as a ring.
    ShapePath {
      strokeColor: Qt.rgba(1, 1, 1, 0.09)
      strokeWidth: root.stroke * 0.4
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

    // Bloom of the same sweep, wider and faint, under the sharp arc.
    ShapePath {
      strokeColor: Qt.rgba(0.48, 0.38, 1.0, 0.12)
      strokeWidth: root.stroke * 1.5
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

    // What is left of the block, running clockwise from twelve.
    ShapePath {
      strokeWidth: root.stroke
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      strokeGradient: LinearGradient {
        x1: 0
        y1: 0
        x2: root.width
        y2: root.height
        GradientStop { position: 0.0; color: root.tintFrom }
        GradientStop { position: 0.55; color: root.tintFrom }
        GradientStop { position: 1.0; color: root.tintTo }
      }
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

  // The lit head: the arc ends in a bright pip, which is what makes it read
  // as a moving instrument rather than a filled gauge.
  Item {
    visible: root.sweep > 2 && root.sweep < 356
    x: root.headX - width / 2
    y: root.headY - height / 2
    width: root.px(22) * (1 + root.kick * 0.45)
    height: width

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(0.75, 0.68, 1.0, 0.55) }
        GradientStop { position: 1.0; color: Qt.rgba(0.55, 0.45, 1.0, 0.0) }
      }
    }

    Rectangle {
      anchors.centerIn: parent
      width: root.px(8) * (1 + root.kick * 0.25)
      height: width
      radius: width / 2
      color: "#FFFFFF"
    }
  }
}
