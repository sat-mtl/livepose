import QtQuick
import livepose

Item {
    id: root
    
    property alias text: buttonText.text
    property alias color: buttonBackground.color
    property bool isActive: false
    signal clicked
    
    height: AppStyle.sidebarButtonHeight
    clip: false
    
    Rectangle {
        id: buttonBackground
        anchors.fill: parent
        color: AppStyle.sidebarBackgroundColor
        radius: 0
        
        Rectangle {
            id: activeIndicator
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            color: AppStyle.primaryColor
            visible: root.isActive
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: root.clicked()
            cursorShape: Qt.PointingHandCursor
        }
        
        Text {
            id: buttonText
            text: "Button"
            anchors.centerIn: parent
            color: root.isActive ? AppStyle.primaryColor : AppStyle.textColorLight
            font.pixelSize: AppStyle.fontSizeBody
            font.bold: root.isActive
        }
    }
}
