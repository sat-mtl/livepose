import QtQuick
import QtQuick.Controls.Basic
import livepose

TextField {
    id: root
    
    font.family: appStyle.fontFamily
    font.pixelSize: appStyle.fontSizeBody
    color: enabled ? appStyle.textColor : appStyle.textColorSecondary
    height: appStyle.inputHeight
}

