import QtQuick
import qs.Commons

// The product mark: a raised violet tile with a bevelled edge, a specular
// line and a knocked-out play glyph. Built from layers rather than a camera —
// shadow, face gradient, inner shade, top light — because at 40 px that stack
// is what reads as a physical object.
Item {
  id: root

  property string glyph: "\uf04b"        // nf-fa-play
  property color ink: "#FFFFFF"
  property string glyphFamily: "JetBrainsMono Nerd Font"

  readonly property real s: Style.fontScale
  function px(n) { return Math.max(1, Math.round(n * s)) }

  implicitWidth: px(40)
  implicitHeight: px(40)

  // Cast shadow: two soft steps down, so the tile sits on the card.
  Rectangle {
    anchors.fill: face
    anchors.topMargin: root.px(3)
    radius: face.radius
    color: "#07040F"
    opacity: 0.38
  }

  Rectangle {
    id: face
    anchors.fill: parent
    anchors.bottomMargin: root.px(2)
    radius: root.px(12)
    gradient: Gradient {
      GradientStop { position: 0.0; color: "#B9A2FF" }
      GradientStop { position: 0.42; color: "#8365F5" }
      GradientStop { position: 0.78; color: "#5F44D8" }
      GradientStop { position: 1.0; color: "#4630B8" }
    }
  }

  // Inner shade across the lower half: the face turns away from the light.
  Rectangle {
    anchors.fill: face
    radius: face.radius
    gradient: Gradient {
      GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.0) }
      GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.30) }
    }
  }

  // Specular along the top edge, inset so it never touches the corners.
  Rectangle {
    anchors.left: face.left
    anchors.right: face.right
    anchors.top: face.top
    anchors.margins: root.px(3)
    height: root.px(1.4)
    radius: height / 2
    color: Qt.rgba(1, 1, 1, 0.55)
  }

  // A rim of the same light, one pixel, so the tile's edge stays crisp on a
  // dark card.
  Rectangle {
    anchors.fill: face
    radius: face.radius
    color: "transparent"
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.22)
  }

  // Glyph with its own pinch of shadow: the knock-out needs to look like a
  // cut in the face, not a sticker on top of it.
  Text {
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: root.px(1)
    anchors.verticalCenterOffset: root.px(1)
    text: root.glyph
    color: Qt.rgba(0.10, 0.06, 0.28, 0.55)
    font.family: root.glyphFamily
    font.pixelSize: root.px(15)
    renderType: Text.NativeRendering
  }

  Text {
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: root.px(1)
    text: root.glyph
    color: root.ink
    font.family: root.glyphFamily
    font.pixelSize: root.px(15)
    renderType: Text.NativeRendering
  }
}
