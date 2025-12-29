import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Score.UI as UI
import livepose

ApplicationWindow {
    id: mainWindow
    width: AppStyle.windowWidth
    height: AppStyle.windowHeight
    minimumWidth: AppStyle.windowMinWidth
    minimumHeight: AppStyle.windowMinHeight
    visible: true
    title: "LivePose"
    
    property var logger: QtObject {
        function log(message) {
            console.log(message);
        }
        function clear() {
        }
    }
    
    property int currentViewIndex: 0
    readonly property int runViewIndex: 0
    readonly property int logViewIndex: 1
    
    AboutDialog {
        id: aboutDialog
        parentWindow: mainWindow
    }
    
    menuBar: AppMenuBar {
        aboutDialog: aboutDialog
    }
    
    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: 0
        
        Rectangle {
            id: sidebar
            width: AppStyle.sidebarWidth
            Layout.fillHeight: true
            color: AppStyle.sidebarBackgroundColor
            
            ColumnLayout {
                id: sidebarColumn
                anchors.fill: parent
                anchors.leftMargin: 0
                anchors.topMargin: AppStyle.padding
                anchors.rightMargin: 0
                anchors.bottomMargin: AppStyle.padding
                spacing: AppStyle.spacing
                
                Image {
                    id: logoImage
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 60
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: AppStyle.padding
                    source: "livepose/resources/images/LivePose_logo.png"
                    fillMode: Image.PreserveAspectFit
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: aboutDialog.open()
                        cursorShape: Qt.PointingHandCursor
                    }
                }
                
                CustomButton {
                    id: runButton
                    text: "Run"
                    Layout.fillWidth: true
                    Layout.topMargin: AppStyle.spacing
                    isActive: currentViewIndex === runViewIndex
                    onClicked: currentViewIndex = runViewIndex
                }
                
                CustomButton {
                    id: logButton
                    text: "Log"
                    Layout.fillWidth: true
                    Layout.topMargin: AppStyle.spacing
                    isActive: currentViewIndex === logViewIndex
                    onClicked: currentViewIndex = logViewIndex
                }
                
                Item {
                    Layout.fillHeight: true
                }
            }
        }
        
        StackLayout {
            id: stackView
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: currentViewIndex
            
            RunView { }
            LogView { }
        }
    }
}
