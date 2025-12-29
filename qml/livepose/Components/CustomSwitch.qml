import QtQuick
import QtQuick.Controls
import livepose

Switch {
    id: control

    indicator: Rectangle {
        implicitWidth: 48
        implicitHeight: 26
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: 13
        color: control.checked ? AppStyle.buttonBgActive : AppStyle.buttonBgInactive
        border.color: control.checked ? AppStyle.buttonBgActive : "#cccccc"

        Rectangle {
            x: control.checked ? parent.width - width - 2 : 2
            y: 2
            width: 22
            height: 22
            radius: 11
            color: "white"
            border.color: control.checked ? AppStyle.buttonBgActive : "#999999"

            Behavior on x {
                NumberAnimation {
                    duration: 150
                }
            }
        }
    }

    contentItem: Text {
        text: control.text
        font.pixelSize: AppStyle.fontSizeBody
        color: AppStyle.textColor
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + 8
    }
}
