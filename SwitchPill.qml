import QtQuick
import qs.Commons

// A gradient pill switch. The kit's ToggleSwitch follows the theme's flat
// accent; on this panel the "on" face is the same violet-to-blue as the
// primary button, so state reads at a glance.
Item {
  id: root

  property bool checked: false
  signal toggled()

  readonly property real s: Style.fontScale
  function px(n) { return Math.max(1, Math.round(n * s)) }

  implicitWidth: px(44)
  implicitHeight: px(24)

  Rectangle {
    id: track
    anchors.fill: parent
    radius: height / 2
    color: Qt.rgba(1, 1, 1, 0.13)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)
  }

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    opacity: root.checked ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    gradient: Gradient {
      GradientStop { position: 0.0; color: "#8A6BFF" }
      GradientStop { position: 1.0; color: "#3D7DFF" }
    }
  }

  Rectangle {
    id: knob
    width: root.px(18)
    height: width
    radius: height / 2
    y: (parent.height - height) / 2
    x: root.checked ? parent.width - width - root.px(3) : root.px(3)
    color: "#F7FAFF"
    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    // A faint slate rim keeps the knob from dissolving into the blue face.
    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.10)
    }
  }

  MouseArea {
    anchors.fill: parent
    anchors.margins: -root.px(4)
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled()
  }
}
