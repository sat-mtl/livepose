import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import livepose

Pane {
    id: logView

    function log(message) {
        var time = new Date();
        var timestamp = time.getHours() + ":" + 
                       (time.getMinutes() < 10 ? "0" : "") + time.getMinutes() + ":" + 
                       (time.getSeconds() < 10 ? "0" : "") + time.getSeconds();
        logTextArea.append("[" + timestamp + "] " + message);
        console.log(message);
    }
    
    function clear() {
        logTextArea.text = "";
    }

    Component.onCompleted: {
        if (mainWindow) {
            mainWindow.logger = logView;
        }
        log("Log view initialized");
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: appStyle.padding
        spacing: appStyle.spacing

        Label {
            text: "Application Log"
            font.bold: true
            font.pixelSize: appStyle.fontSizeTitle
            color: appStyle.textColor
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextArea {
                id: logTextArea
                text: ""
                readOnly: true
                wrapMode: TextEdit.Wrap
                font.family: "Courier"
                font.pixelSize: appStyle.fontSizeBody
                color: appStyle.textColor
            }
        }

        RowLayout {
            spacing: appStyle.spacing

            Button {
                text: "Clear Log"
                onClicked: {
                    logView.clear()
                }
            }

            Button {
                text: "Test Log"
                onClicked: {
                    logView.log("Test log message at " + new Date().toLocaleTimeString())
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }
}

