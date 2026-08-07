import QtCore
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Score.UI as UI
import livepose
import ca.qc.sat.qmlcomponents

ApplicationWindow {
    id: mainWindow
    width: 1280
    height: 820
    minimumWidth: 1000
    minimumHeight: 600
    visible: true
    title: "LivePose"

    Settings {
        id: appSettings
        category: "LivePose"

        property string lastSelectedModel: ""
        property string lastBackend: ""
        property string lastSourceName: ""

        property string poseDetectorModelPath: ""

        // Folder the preset model paths (<LIBRARY>:packages/pose-detector/…) are
        // rewritten to. Empty = use PresetView's computed default.
        property string poseDetectorModelsFolder: ""

        property string oscIpAddress: "127.0.0.1"
        property string oscPortValue: "9000"
        property string lastVideoPath: ""

        property int poseDetectorOutputMode: 0
        property real poseDetectorMinConfidence: 0.3
        property bool poseDetectorDrawSkeleton: true
        property int poseDetectorDataFormat: 0

        property string poseDetectorDetectionModelPath: ""
        property bool poseDetectorTrackROI: false
        property bool poseDetectorSmoothing: true
        property real poseDetectorSmoothingAmount: 0.5
        property bool poseDetectorTrackIDs: false
        property int poseDetectorMaxInstances: 5
        property int poseDetectorDetectorCadence: 4

        // Output
        property bool poseDetectorDrawLandmarks: true
        property bool poseDetectorDrawBoxes: false
        property int poseDetectorSkeletonType: 0
        // Tracking
        property int poseDetectorTrackMemory: 30
        property int poseDetectorHoldFrames: 6
        property int poseDetectorMotionGate: 0
        property real poseDetectorMaxSpeed: 2.0
        property bool poseDetectorBirthGate: true
        property bool poseDetectorStrictConfirm: false
        // Re-ID
        property string poseDetectorReidModelPath: ""
        property bool poseDetectorReid: false
        property real poseDetectorReidWeight: 0.25
        property int poseDetectorReidPreprocess: 0
        property int poseDetectorReidMemory: 1800
        property real poseDetectorReidMargin: 0.1
        // Detection
        property int poseDetectorDetectionClass: -1
        property string poseDetectorClassNamesFile: ""
    }

    // Dark unless the OS explicitly asks for light (Unknown reads as dark).
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
    readonly property int presetsViewIndex: 1
    readonly property int logViewIndex: 2

    AboutDialog {
        id: aboutDialog
        parentWindow: mainWindow
        appName: "LivePose"
        appDescription: "A tool developed by the Société des Arts Technologiques"
        appDetails: "This tool offers a way to track people's skeletons from a live video stream, and sends the results through the network (OSC)."
        appWebsite: "https://gitlab.com/sat-mtl"
        // Relative paths would resolve against AboutDialog.qml in the submodule.
        logoPath: Qt.resolvedUrl("livepose/resources/images/LivePose_logo.png")
        partnerLogos: [
            { source: Qt.resolvedUrl("livepose/resources/images/sat_logo.png"), website: "https://www.sat.qc.ca" },
            { source: Qt.resolvedUrl("livepose/resources/images/ossia_logo.png"), website: "https://ossia.io" }
        ]
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
                    id: presetsButton
                    text: "PRESETS"
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacing
                    isActive: currentViewIndex === presetsViewIndex
                    onClicked: currentViewIndex = presetsViewIndex
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

            RunView { id: runViewItem }
            PresetView { runView: runViewItem }
            LogView {
                id: logViewInstance
                title: "Application Log"
                Component.onCompleted: mainWindow.logger = logViewInstance
            }
        }
    }
}
