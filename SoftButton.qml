import QtQuick
import qs.Commons

// The quiet buttons under the primary one: a translucent pill with an icon and
// a label. Same press feedback as the primary, a much lower voice.
Item {
  id: root

  property string label: ""
  property string glyph: ""
  property color ink: "#DCE5F5"
  property string fontFamily: "Inter"
  property string glyphFamily: "JetBrainsMono Nerd Font"

  signal clicked()

  readonly property real s: Style.fontScale
  function px(n) { return Math.max(1, Math.round(n * s)) }

  implicitWidth: px(110)
  implicitHeight: px(40)
  scale: press.pressed ? 0.98 : 1.0
  Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

  Rectangle {
    id: face
    anchors.fill: parent
    radius: root.px(12)
    color: press.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.055)
    border.width: 1
    border.color: press.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.09)
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }
  }

  Row {
    anchors.centerIn: parent
    spacing: root.px(7)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.glyph !== ""
      text: root.glyph
      color: root.ink
      font.family: root.glyphFamily
      font.pixelSize: root.px(12)
      renderType: Text.NativeRendering
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      color: root.ink
      font.family: root.fontFamily
      font.pixelSize: root.px(13)
    }
  }

  MouseArea {
    id: press
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
