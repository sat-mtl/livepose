import QtQuick
import QtQuick.Controls.Basic
import livepose

ComboBox {
    id: control
    
    font.family: appStyle.fontFamily
    font.pixelSize: appStyle.fontSizeBody
    
    delegate: ItemDelegate {
        width: control.width
        contentItem: Text {
            text: modelData
            color: appStyle.textColor
            font.family: appStyle.fontFamily
            font.pixelSize: appStyle.fontSizeBody
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        highlighted: control.highlightedIndex === index
        background: Rectangle {
            color: highlighted ? appStyle.primaryColor : appStyle.backgroundColorSecondary
        }
    }
    
    contentItem: Text {
        leftPadding: 12
        rightPadding: control.indicator.width + control.spacing
        text: control.displayText
        font.family: appStyle.fontFamily
        font.pixelSize: appStyle.fontSizeBody
        color: appStyle.textColor
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    
    background: Rectangle {
        implicitWidth: 200
        implicitHeight: appStyle.inputHeight
        color: appStyle.backgroundColorSecondary
        border.color: control.pressed ? appStyle.primaryColor : appStyle.borderColor
        border.width: 1
        radius: appStyle.borderRadius
    }
    
    popup: Popup {
        y: control.height
        width: control.width
        implicitHeight: contentItem.implicitHeight
        padding: 1
        
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }
        
        background: Rectangle {
            color: appStyle.backgroundColorSecondary
            border.color: appStyle.borderColor
            border.width: 1
            radius: appStyle.borderRadius
        }
    }
}

