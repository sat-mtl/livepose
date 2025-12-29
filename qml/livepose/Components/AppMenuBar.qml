import QtQuick
import QtQuick.Controls
import livepose

MenuBar {
    id: menuBar
    
    property var aboutDialog: null
    
    Menu {
        title: qsTr("&Help")
        Action {
            text: qsTr("&About")
            enabled: aboutDialog !== null
            onTriggered: {
                if (aboutDialog) {
                    aboutDialog.open()
                }
            }
        }
    }
}

