import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Score.UI as UI
import livepose

// Live video preview + transport, shared by the RUN and PRESETS views. All
// pipeline state and actions are delegated to `target` (a RunView), so the
// preview is identical wherever it appears and a preset clicked in the PRESETS
// view shows up in this preview immediately.
Item {
    id: root

    property var target

    // Whether THIS panel owns the live preview. Exactly one PreviewPanel may be
    // active at a time: two TextureSources on the same GFX process spin up two
    // render lists, each re-initialising the Pose Detector's ONNX session, which
    // crashes. The views set this so only the visible preview renders.
    property bool active: true

    readonly property bool running: target ? target.isRunning : false
    readonly property bool paused: target ? target.isPaused : false

    ColumnLayout {
        anchors.fill: parent
        spacing: appStyle.spacing

        CustomLabel {
            text: "Video Preview"
            font.bold: true
            font.pixelSize: appStyle.fontSizeSubtitle
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: width / aspectRatio
            Layout.minimumWidth: 360
            Layout.minimumHeight: 200
            color: "transparent"
            radius: appStyle.borderRadius
            border.color: appStyle.borderColor
            border.width: 1

            readonly property real aspectRatio: 16 / 9
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: appStyle.borderRadius - 1
                color: appStyle.backgroundColorTertiary
                clip: true
                layer.enabled: true
                layer.smooth: true

                UI.TextureSource {
                    id: textureSource
                    width: 1280
                    height: 720
                    process: (root.active && root.running) ? "livepose preview" : ""
                    port: 0
                    visible: root.active && root.running
                }
                ShaderEffectSource {
                    anchors.fill: parent
                    sourceItem: textureSource
                    hideSource: true
                }
                Text {
                    anchors.centerIn: parent
                    text: root.target ? root.target.statusText : ""
                    color: appStyle.textColorSecondary
                    font.family: appStyle.fontFamily
                    font.pixelSize: appStyle.fontSizeBody
                    visible: !root.running
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Button {
                text: root.running ? "Stop" : "Start"
                font.family: appStyle.fontFamily
                font.pixelSize: appStyle.fontSizeBody
                onClicked: {
                    if (!root.target) return
                    if (root.running) root.target.stopCurrentProcess()
                    else root.target.startTriggeredScenario()
                }
            }

            Button {
                text: root.paused ? "Resume" : "Pause"
                visible: root.running
                font.family: appStyle.fontFamily
                font.pixelSize: appStyle.fontSizeBody
                onClicked: if (root.target) root.target.togglePause()
            }

            CustomLabel {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.target ? root.target.statusText : ""
            }
        }

        Item { Layout.fillHeight: true }
    }
}
