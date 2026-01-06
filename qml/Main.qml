import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Score.UI as UI
import livepose

ApplicationWindow {
    id: mainWindow
    width: appStyle.windowWidth
    height: appStyle.windowHeight
    minimumWidth: appStyle.windowMinWidth
    minimumHeight: appStyle.windowMinHeight
    visible: true
    title: "LivePose"
    DarkStyle {
        id: dark_style
    }
    LightStyle {
        id: light_style
    }
    property var appStyle:  Application.styleHints.colorScheme === Qt.ColorScheme.Dark ? dark_style : light_style
    
    Component.onCompleted: console.log( Application.styleHints.colorScheme)
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
            width: appStyle.sidebarWidth
            Layout.fillHeight: true
            color: appStyle.sidebarBackgroundColor
            
            ColumnLayout {
                id: sidebarColumn
                anchors.fill: parent
                anchors.leftMargin: 0
                anchors.topMargin: appStyle.padding
                anchors.rightMargin: 0
                anchors.bottomMargin: appStyle.padding
                spacing: appStyle.spacing
                
                Image {
                    id: logoImage
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 60
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: appStyle.padding
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
                    Layout.topMargin: appStyle.spacing
                    isActive: currentViewIndex === runViewIndex
                    onClicked: currentViewIndex = runViewIndex
                }
                
                CustomButton {
                    id: logButton
                    text: "Log"
                    Layout.fillWidth: true
                    Layout.topMargin: appStyle.spacing
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
