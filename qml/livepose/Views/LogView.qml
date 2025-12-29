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
        anchors.margins: AppStyle.padding
        spacing: AppStyle.spacing

        Label {
            text: "Application Log"
            font.bold: true
            font.pixelSize: AppStyle.fontSizeTitle
            color: AppStyle.textColor
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
                font.pixelSize: AppStyle.fontSizeBody
                color: AppStyle.textColor
            }
        }

        RowLayout {
            spacing: AppStyle.spacing

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

