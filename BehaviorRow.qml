import QtQuick
import qs.Commons

// A behaviour row: an icon tile, the title, one line of what it does, and the
// gradient switch. The whole row is the click target, the switch is the state
// read-out, so a click anywhere flips it.
Item {
  id: root

  property string glyph: ""
  property string label: ""
  property string description: ""
  property bool checked: false
  property color ink: "#E9EFFB"
  property string fontFamily: "Inter"
  property string glyphFamily: "JetBrainsMono Nerd Font"

  signal toggled()

  readonly property real s: Style.fontScale
  function px(n) { return Math.max(1, Math.round(n * s)) }

  implicitHeight: Math.max(px(46), textColumn.implicitHeight + px(14))
  width: parent ? parent.width : implicitWidth

  Rectangle {
    anchors.fill: parent
    radius: root.px(10)
    color: hover.containsMouse ? Qt.rgba(1, 1, 1, 0.035) : "transparent"
    Behavior on color { ColorAnimation { duration: 110 } }
  }

  Rectangle {
    id: tile
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: root.px(28)
    height: width
    radius: root.px(8)
    color: Qt.rgba(0.545, 0.42, 1.0, 0.16)
    border.width: 1
    border.color: Qt.rgba(0.545, 0.42, 1.0, 0.26)

    Text {
      anchors.centerIn: parent
      text: root.glyph
      color: "#C3B2FF"
      font.family: root.glyphFamily
      font.pixelSize: root.px(12)
      renderType: Text.NativeRendering
    }
  }

  Column {
    id: textColumn
    anchors.left: tile.right
    anchors.leftMargin: root.px(10)
    anchors.right: switchPill.left
    anchors.rightMargin: root.px(10)
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.px(1)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: root.label
      color: root.ink
      elide: Text.ElideRight
      font.family: root.fontFamily
      font.pixelSize: root.px(13)
    }

    Text {
      width: parent.width
      visible: root.description !== ""
      textFormat: Text.PlainText
      text: root.description
      color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.70)
      wrapMode: Text.WordWrap
      font.family: root.fontFamily
      font.pixelSize: root.px(11)
    }
  }

  SwitchPill {
    id: switchPill
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    checked: root.checked
    onToggled: root.toggled()
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    // The switch draws its own hit area; everything else in the row is here.
    onClicked: root.toggled()
  }
}
