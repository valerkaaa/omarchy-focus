import QtQuick
import qs.Commons
import qs.Commons as Commons

// One "− value +" length row inside the LENGTHS block. The figure is the
// thing being set, so it keeps its own column between the two steppers and
// never collapses into the label's sentence.
Item {
  id: root

  property string label: ""
  property int value: 25
  property int from: 1
  property int to: 180
  property int stepSize: 5
  property string suffix: "min"
  property color ink: "#E9EFFB"
  property string fontFamily: "Inter"

  signal changed(int value)

  readonly property real s: Style.fontScale
  function px(n) { return Math.max(1, Math.round(n * s)) }

  implicitHeight: px(42)
  width: parent ? parent.width : implicitWidth

  function step(delta) {
    var next = Math.max(root.from, Math.min(root.to, root.value + delta))
    if (next !== root.value) root.changed(next)
  }

  Text {
    id: labelText
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    anchors.right: controls.left
    anchors.rightMargin: root.px(8)
    textFormat: Text.PlainText
    text: root.label
    color: root.ink
    elide: Text.ElideRight
    font.family: root.fontFamily
    font.pixelSize: root.px(13)
  }

  Row {
    id: controls
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.px(4)

    component Step: Item {
      id: stepRoot
      property string glyph: ""
      signal pressed()
      width: root.px(26)
      height: root.px(26)

      Rectangle {
        anchors.fill: parent
        radius: root.px(8)
        color: stepArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
        Behavior on color { ColorAnimation { duration: 100 } }
      }

      Text {
        anchors.centerIn: parent
        text: stepRoot.glyph
        color: Qt.rgba(1, 1, 1, 0.92)
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: root.px(11)
        renderType: Text.NativeRendering
      }

      MouseArea {
        id: stepArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: stepRoot.pressed()
      }
    }

    Step {
      glyph: "\uf068"   // nf-fa-minus
      onPressed: root.step(-root.stepSize)
    }

    Item {
      width: root.px(54)
      height: root.px(26)

      Row {
        anchors.centerIn: parent
        spacing: root.px(3)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: Commons.I18n.formatNumber(root.value)
          color: root.ink
          font.family: root.fontFamily
          font.pixelSize: root.px(13)
          font.weight: Font.DemiBold
        }

        Text {
          id: unit
          textFormat: Text.PlainText
          text: root.suffix
          color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.62)
          font.family: root.fontFamily
          font.pixelSize: root.px(11)
        }
      }
    }

    Step {
      glyph: "\uf067"   // nf-fa-plus
      onPressed: root.step(root.stepSize)
    }
  }
}
