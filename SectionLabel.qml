import QtQuick
import qs.Commons

// Section header for the popup: small caps, wide tracking, dim enough to stay
// subordinate to the rows it introduces but still legible at 11 px and up.
Item {
  id: root

  property string text: ""
  property color ink: "#F4F7FF"
  property string fontFamily: "Inter"

  readonly property real s: Style.fontScale
  function px(n) { return Math.max(1, Math.round(n * s)) }

  implicitHeight: label.implicitHeight + px(2)
  width: parent ? parent.width : 0

  Text {
    id: label
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: root.text
    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.68)
    font.family: root.fontFamily
    font.pixelSize: root.px(12)
    font.weight: Font.DemiBold
    font.letterSpacing: root.px(1.2)
  }
}
