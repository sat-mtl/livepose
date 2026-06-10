import QtCore
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Score.UI as UI
import livepose
import ca.qc.sat.qmlcomponents

ApplicationWindow {
    id: mainWindow
    width: Theme.windowWidth
    height: Theme.windowHeight
    minimumWidth: Theme.windowMinWidth
    minimumHeight: Theme.windowMinHeight
    visible: true
    title: "LivePose"

    Settings {
        id: appSettings
        category: "LivePose"

        property string lastSelectedModel: ""
        property string lastBackend: ""
        property string lastSourceName: ""

        property string poseDetectorModelPath: ""
        property string objectDetectorModelPath: ""
        property string objectDetectorClassesPath: ""

        property string oscIpAddress: "127.0.0.1"
        property string oscPortValue: "9000"
        property string lastVideoPath: ""

        property int poseDetectorOutputMode: 0
        property real poseDetectorMinConfidence: 0.5
        property bool poseDetectorDrawSkeleton: true
        property int poseDetectorDataFormat: 0
    }

    // Drive the shared Theme singleton from the OS colour scheme (dark unless
    // the system explicitly asks for light), replacing the old appStyle switch.
    Binding {
        target: Theme
        property: "dark"
        value: Application.styleHints.colorScheme !== Qt.ColorScheme.Light
    }

    palette {
        // Text colors
        text: Theme.textColor
        windowText: Theme.textColor
        buttonText: Theme.textColor
        brightText: Theme.textColorOnAccent
        placeholderText: Theme.textColorSecondary

        // Background colors
        window: Theme.backgroundColor
        base: Theme.backgroundColorSecondary
        alternateBase: Theme.backgroundColorTertiary

        // Used by FileDialog header/footer
        light: Theme.backgroundColorSecondary
        midlight: Theme.backgroundColorTertiary
        mid: Theme.borderColor
        dark: Theme.borderColor
        shadow: Theme.backgroundColor

        // Interactive elements
        button: Theme.buttonBgInactive
        highlight: Theme.primaryColor
        highlightedText: Theme.textColorOnAccent

        // Links
        link: Theme.primaryColor
        linkVisited: Theme.secondaryColor
    }

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
        appName: "LivePose"
        appDescription: "A tool developed by the Société des Arts Technologiques"
        appDetails: "This tool offers a way to track people's skeletons from a live video stream, and sends the results through the network (OSC)."
        appWebsite: "https://gitlab.com/sat-mtl"
        logoPath: "livepose/resources/images/LivePose_logo.png"
        satLogoPath: "livepose/resources/images/sat_logo.png"
        ossiaLogoPath: "livepose/resources/images/ossia_logo.png"
    }

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: sidebar
            width: Theme.sidebarWidth
            Layout.fillHeight: true
            color: Theme.sidebarBackgroundColor

            ColumnLayout {
                id: sidebarColumn
                anchors.fill: parent
                anchors.leftMargin: 0
                anchors.topMargin: Theme.padding
                anchors.rightMargin: 0
                anchors.bottomMargin: Theme.padding
                spacing: Theme.spacing

                Image {
                    id: logoImage
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 60
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Theme.padding
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
                    text: "RUN"
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacing
                    isActive: currentViewIndex === runViewIndex
                    onClicked: currentViewIndex = runViewIndex
                }

                CustomButton {
                    id: logButton
                    text: "LOGS"
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacing
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
            LogView {
                id: logViewInstance
                title: "Application Log"
                Component.onCompleted: mainWindow.logger = logViewInstance
            }
        }
    }
}
