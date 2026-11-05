import QtQuick
import qs.Commons

// The panel's one primary action: a full-width button with a violet-to-blue
// face, a light top edge and a small lift under the cursor. Hand-built because
// the kit's Button paints flat theme fills and has no gradient face.
Item {
  id: root

  property string label: ""
  property string glyph: ""
  property bool running: false
  property color tintFrom: "#7C5CFF"
  property color tintTo: "#2F6BE0"
  property color ink: "#F7FAFF"
  property string fontFamily: "Inter Display"
  property string glyphFamily: "JetBrainsMono Nerd Font"

  signal clicked()

  readonly property real s: Style.fontScale
  function px(n) { return Math.max(1, Math.round(n * s)) }

  implicitWidth: px(320)
  implicitHeight: px(54)
  scale: press.pressed ? 0.985 : 1.0
  Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

  Rectangle {
    id: face
    anchors.fill: parent
    radius: root.px(16)
    gradient: Gradient {
      GradientStop { position: 0.0; color: root.running ? "#7FA0FF" : "#A78BFF" }
      GradientStop { position: 0.45; color: root.tintFrom }
      GradientStop { position: 1.0; color: root.tintTo }
    }
  }

  // A one-pixel specular along the top edge: that line is what makes the face
  // read as a lit surface rather than a flat rectangle of colour.
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: root.px(3)
    height: 1
    radius: 1
    color: Qt.rgba(1, 1, 1, 0.45)
  }

  Rectangle {
    anchors.fill: parent
    radius: root.px(16)
    color: Qt.rgba(1, 1, 1, press.containsMouse ? 0.10 : 0.0)
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  Row {
    anchors.centerIn: parent
    spacing: root.px(9)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.glyph !== ""
      text: root.glyph
      color: root.ink
      font.family: root.glyphFamily
      font.pixelSize: root.px(15)
      renderType: Text.NativeRendering
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      color: root.ink
      font.family: root.fontFamily
      font.pixelSize: root.px(16)
      font.weight: Font.DemiBold
      font.letterSpacing: 0.2
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
