import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Dialogs
import Score.UI as UI
import livepose

import "../js/CameraUtils.js" as CameraUtils
import "../js/ScenarioUtils.js" as ScenarioUtils
import "../js/ValidationUtils.js" as ValidationUtils
import "../js/ScoreUtils.js" as ScoreUtils
import "../js/ProcessControl.js" as ProcessControl

Pane {
    id: runView
    background: Rectangle {
        color: appStyle.backgroundColor
    }


    property var logger: mainWindow.logger

    property var deviceEnumerator
    property var cameraList: []
    property var cameraPrettyNamesList: []
    property var availableProcesses: []
    property var currentProcess: null

    property bool isStarting: false
    property bool isRunning: false
    property bool oscReady: false
    
    property bool showModelError: false
    property bool showCameraError: false
    property bool showModelFileError: false
    property bool showClassesFileError: false
    property var modelPaths: ({})
    property var classesPaths: ({})

    function updateModelPath() {
        if (!currentProcess) return
        
        var filePath = modelFilePathField.text
        if (!filePath) return
        
        ScoreUtils.updateModelPath(Score, currentProcess, filePath, {
            blazePose: blaze_Pose,
            yoloPose: yOLO_Pose,
            resnetDetector: resnet_detector
        })
    }

    function saveAllFieldsToScore() {
        updateModelPath()
        ScoreUtils.saveClassesFile(Score, currentProcess, classesFilePathField.text, resnet_detector)
    }

    Item {
        id: objects
        QtObject { id: livepose_ossia_gui
            property var process_object : Score.find("good_state");
        }
        
        QtObject { id: blaze_Pose
            property var process_object : Score.find("Blaze Pose");
            property var input : Score.inlet(process_object, 0);
            property var model : Score.inlet(process_object, 1);
            property var model_input_resolution : Score.inlet(process_object, 2);
            property var minimum_confidence : Score.inlet(process_object, 3);
            property var out : Score.outlet(process_object, 0);
            property var detection : Score.outlet(process_object, 1);
        }
        
        QtObject { id: yOLO_Pose
            property var process_object : Score.find("YOLO Pose");
            property var input : Score.inlet(process_object, 0);
            property var model : Score.inlet(process_object, 1);
            property var model_input_resolution : Score.inlet(process_object, 2);
            property var out : Score.outlet(process_object, 0);
            property var detection : Score.outlet(process_object, 1);
        }
        
        QtObject { id: resnet_detector
            property var process_object : Score.find("Resnet detector");
            property var input : Score.inlet(process_object, 0);
            property var model : Score.inlet(process_object, 1);
            property var classes : Score.inlet(process_object, 2);
            property var model_input_resolution : Score.inlet(process_object, 3);
            property var out : Score.outlet(process_object, 0);
            property var detection : Score.outlet(process_object, 1);
        }
    }

    function getVideoInPortViaMapper(videoMapperLabel) {
        return ScenarioUtils.getVideoInPortViaMapper(Score, videoMapperLabel)
    }

    function findAllScenarios() {
        var result = ScenarioUtils.findAllScenarios(Score, logger)
        availableProcesses = result.availableProcesses

        if (availableProcesses.length > 0) {
            backendSelector.model = result.modelList
            backendSelector.currentIndex = 1
            currentProcess = availableProcesses[0]
            logger.log("Auto-selected model: " + availableProcesses[0].scenarioLabel)
        } else {
            backendSelector.model = [" "]
            logger.log("No scenarios found")
        }
    }

    function enumerateCameras() {
        var result = CameraUtils.enumerateCameras(Score, logger)
        deviceEnumerator = result.deviceEnumerator
        cameraList = result.cameraList
        cameraPrettyNamesList = result.cameraPrettyNamesList
        cameraSelector.model = [" ", ...cameraPrettyNamesList]
    }

    function validateBeforeStart() {
        var result = ValidationUtils.validateBeforeStart({
            currentProcess: currentProcess,
            hasValidModelPath: modelFilePathField.hasValidPath,
            hasValidClassesPath: classesFilePathField.hasValidPath,
            cameraIndex: cameraSelector.currentIndex,
            logger: logger
        })
        
        showModelError = result.errors.showModelError
        showCameraError = result.errors.showCameraError
        showModelFileError = result.errors.showModelFileError
        showClassesFileError = result.errors.showClassesFileError
        
        return result.valid
    }

    function startTriggeredScenario() {
        if (!validateBeforeStart()) {
            return
        }
        if (isStarting) return
        isStarting = true
        saveAllFieldsToScore()
        
        var oscWasSetup = ProcessControl.startTriggeredScenario({
            Score: Score,
            currentProcess: currentProcess,
            logger: logger,
            cameraName: cameraPrettyNamesList[cameraSelector.currentIndex - 1],
            cameraSettings: cameraList[cameraSelector.currentIndex - 1].settings,
            oscHost: oscIpAddress.text,
            oscPort: oscPort.text,
            oscReady: oscReady,
            getVideoInPort: function() {
                return getVideoInPortViaMapper(currentProcess.videoMapperLabel)
            }
        })
        
        if (oscWasSetup) {
            oscReady = true
        }
        
        isRunning = true
        isStarting = false
    }

    function stopCurrentProcess() {
        ProcessControl.stopCurrentProcess(Score, logger)
        isRunning = false
        isStarting = false
        oscReady = false
    }

    function restartIfRunning() {
       if (runStopSwitch.checked) {
            runStopSwitch.checked = false;
            restartTimer.restart();
       }
    }

    Component.onCompleted: {
        logger.log("RunView initialized")
        enumerateCameras()
        findAllScenarios()
    }

    Component.onDestruction: {
        saveAllFieldsToScore()
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: appStyle.spacing * 0.75
            anchors.margins: appStyle.padding

            CustomLabel {
                text: "Model Configuration"
                font.bold: true
                font.pixelSize: appStyle.fontSizeTitle
                Layout.topMargin: appStyle.padding
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
            }

            // --- Model Selection ---
            CustomLabel {
                text: "Choose AI Model"
                font.bold: true
                font.pixelSize: appStyle.fontSizeSubtitle
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
            }

            ComboBox {
                id: backendSelector
                Layout.fillWidth: true
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
                font.family: appStyle.fontFamily
                model: [" "]

                onCurrentIndexChanged: {
                    restartIfRunning()
                    showModelError = false  // Clear error when selection changes
                    if (currentProcess && currentProcess.scenarioLabel) {
                        var oldLabel = currentProcess.scenarioLabel
                        if (modelFilePathField.text) {
                            modelPaths[oldLabel] = modelFilePathField.text
                        }
                        if (classesFilePathField.text) {
                            classesPaths[oldLabel] = classesFilePathField.text
                        }
                    }
                    if (currentIndex > 0) {
                        currentProcess = availableProcesses[currentIndex - 1]
                        var newLabel = currentProcess.scenarioLabel
                        logger.log("Selected model: " + newLabel)
                        
                        modelFilePathField.text = modelPaths[newLabel] || ""
                        classesFilePathField.text = classesPaths[newLabel] || ""
                    }
                    else {
                        currentProcess = null
                        modelFilePathField.text = ""
                        classesFilePathField.text = ""
                    }
                }
            }
            
            // Validation feedback for model
            CustomLabel {
                visible: showModelError
                text: "Please select a model"
                color: appStyle.errorColor
                font.pixelSize: appStyle.fontSizeSmall
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: appStyle.padding * 2
                Layout.rightMargin: appStyle.padding
                visible: currentProcess !== null
                spacing: appStyle.spacing

                CustomLabel {
                    text: "ONNX Model File"
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    
                    CustomTextField { 
                        id: modelFilePathField
                        Layout.fillWidth: true
                        text: ""  // QML is source of truth
                        
                        property bool hasValidPath: text !== "" && text.indexOf(".onnx") >= 0
                        
                        placeholderText: {
                            if (!runView.currentProcess) {
                                return "Select a model first..."
                            }
                            var modelName = runView.currentProcess.scenarioLabel
                            if (hasValidPath) {
                                return "Model file loaded"
                            } else {
                                return "/path/to/" + modelName + "_model.onnx"
                            }
                        }
                        
                        property var currentModelPort: {
                            if (!runView.currentProcess) return null
                            var scenario = runView.currentProcess.scenarioLabel
                            try {
                                if (scenario === "blazepose" && typeof blaze_Pose !== "undefined" && blaze_Pose) return blaze_Pose.model
                                if (scenario === "yolov8_pose" && typeof yOLO_Pose !== "undefined" && yOLO_Pose) return yOLO_Pose.model
                                if (scenario === "resnet" && typeof resnet_detector !== "undefined" && resnet_detector) return resnet_detector.model
                            } catch(e) {
                                console.log("Error accessing model port:", e)
                            }
                            return null
                        }
                        
                        onTextChanged: {
                            showModelFileError = false
                            if (currentModelPort) {
                                try {
                                    Score.setValue(currentModelPort, text)
                                    if (runView.logger && text !== "") {
                                        runView.logger.log("Model file updated: " + text)
                                    }
                                } catch(e) {
                                    console.log("Error setting model file:", e)
                                }
                            }
                        }
                        
                        onCurrentModelPortChanged: {
                            if (currentModelPort) {
                                Qt.callLater(function() {
                                    try {
                                        // Push the QML value to Score (will be empty string on model switch)
                                        Score.setValue(currentModelPort, text)
                                    } catch(e) {
                                        console.log("Error syncing model to Score:", e)
                                    }
                                })
                            }
                        }
                    }
                    
                    Button {
                        text: "Browse"
                        font.family: appStyle.fontFamily
                        font.pixelSize: appStyle.fontSizeBody
                        onClicked: onnxFileDialog.open()
                    }
                }
                
                FileDialog {
                    id: onnxFileDialog
                    title: "Select ONNX Model File"
                    nameFilters: ["ONNX Files (*.onnx)", "All Files (*)"]
                    onAccepted: {
                        if (!selectedFile) {
                            console.log("No file selected")
                            return
                        }
                        var filePath = selectedFile.toString()
                        if (filePath.startsWith("file://")) {
                            filePath = filePath.substring(7)
                        }
                        modelFilePathField.text = filePath
                    }
                }

                CustomLabel {
                    visible: showModelFileError
                    text: "Please select an ONNX model file"
                    color: appStyle.errorColor
                    font.pixelSize: appStyle.fontSizeSmall
                }

                CustomLabel {
                    text: "Classes File (.txt)"
                    font.bold: true
                    visible: currentProcess && currentProcess.scenarioLabel === "resnet" // only visible for resnet
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: currentProcess && currentProcess.scenarioLabel === "resnet"
                    
                    CustomTextField {
                        id: classesFilePathField
                        Layout.fillWidth: true
                        text: ""  // QML is source of truth
                        
                        property bool hasValidPath: text !== "" && text.indexOf(".txt") >= 0
                        
                        placeholderText: "/path/to/classes.txt"
                        
                        property var currentClassesPort: {
                            if (!runView.currentProcess || runView.currentProcess.scenarioLabel !== "resnet") return null
                            try {
                                if (typeof resnet_detector !== "undefined" && resnet_detector) return resnet_detector.classes
                            } catch(e) {
                                console.log("Error accessing classes port:", e)
                            }
                            return null
                        }
                        
                        onTextChanged: {
                            showClassesFileError = false
                            if (currentClassesPort) {
                                try {
                                    Score.setValue(currentClassesPort, text)
                                    if (runView.logger && text !== "") {
                                        runView.logger.log("Classes file updated: " + text)
                                    }
                                } catch(e) {
                                    console.log("Error setting classes file:", e)
                                }
                            }
                        }
                        
                        onCurrentClassesPortChanged: {
                            if (currentClassesPort) {
                                Qt.callLater(function() {
                                    try {
                                        Score.setValue(currentClassesPort, text)
                                    } catch(e) {
                                        console.log("Error syncing classes to Score:", e)
                                    }
                                })
                            }
                        }
                    }
                    
                    Button {
                        text: "Browse"
                        font.family: appStyle.fontFamily
                        font.pixelSize: appStyle.fontSizeBody
                        onClicked: classesFileDialog.open()
                    }
                }
                
                CustomLabel {
                    visible: showClassesFileError && currentProcess && currentProcess.scenarioLabel === "resnet"
                    text: "Please select a classes file"
                    color: appStyle.errorColor
                    font.pixelSize: appStyle.fontSizeSmall
                }
                
                FileDialog {
                    id: classesFileDialog
                    title: "Select Classes File"
                    nameFilters: ["Text Files (*.txt)", "All Files (*)"]
                    onAccepted: {
                        if (!selectedFile) {
                            console.log("No file selected")
                            return
                        }
                        console.log(Qt.platform.os);
                        console.log(selectedFile);
                        console.log( new URL(selectedFile).pathname);
                        var filePath = new URL(selectedFile).pathname.substr(Qt.platform.os === "windows" ? 1 : 0);
                        classesFilePathField.text = filePath
                    }
                }
            }

            // --- Camera Input ---
            CustomLabel {
                text: "Select Camera"
                font.bold: true
                font.pixelSize: appStyle.fontSizeSubtitle
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
            }

            Timer {
                id: restartTimer
                interval: 250
                running: false
                repeat: false
                onTriggered: runStopSwitch.checked = true
            }
            ComboBox {
                id: cameraSelector
                Layout.fillWidth: true
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
                font.family: appStyle.fontFamily
                model: [" ", ...cameraPrettyNamesList]
                
                onCurrentIndexChanged: {
                    showCameraError = false  // Clear error when selection changes
                    if (currentIndex <= 0) 
                        return;
                    Score.startMacro()
                    
                    const camera_name = cameraPrettyNamesList[currentIndex - 1]
                    const camera_settings = cameraList[currentIndex - 1].settings
                    logger.log("Selected camera: " + camera_name)
                    
                    ScoreUtils.setupCamera(Score, camera_settings, 
                        currentProcess ? getVideoInPortViaMapper(currentProcess.videoMapperLabel) : null)
                    
                    Score.endMacro()
                }
            }
            
            // Validation feedback for camera
            CustomLabel {
                visible: showCameraError
                text: "Please select a camera"
                color: appStyle.errorColor
                font.pixelSize: appStyle.fontSizeSmall
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
            }

            // --- Output ---
            CustomLabel {
                text: "OSC Output Settings"
                font.bold: true
                font.pixelSize: appStyle.fontSizeSubtitle
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
            }

            CustomTextField {
                id: oscIpAddress
                Layout.fillWidth: true
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
                placeholderText: "IP (e.g. 127.0.0.1)"
                text: "127.0.0.1"
                enabled: !runStopSwitch.checked
            }

            CustomTextField {
                id: oscPort
                Layout.fillWidth: true
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
                placeholderText: "Port (e.g. 9000)"
                text: "9000"
                enabled: !runStopSwitch.checked
                validator: IntValidator { bottom: 1; top: 65535 }
            }

            // --- Expose model properties ---
            CustomLabel {
                text: "Video Preview"
                font.bold: true
                font.pixelSize: appStyle.fontSizeSubtitle
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
            }

            Rectangle {
                id: videoPreviewFrame
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 360
                Layout.minimumHeight: 200
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
                color: "transparent"
                radius: appStyle.borderRadius
                border.color: appStyle.borderColor
                border.width: 1
                
                width: height * .9
                // Inner container that clips content to rounded corners
                Rectangle {
                    id: videoPreviewClip
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: appStyle.borderRadius - 1
                    color: appStyle.backgroundColorTertiary
                    clip: true
                    layer.enabled: true
                    layer.smooth: true
                    
                    UI.TextureSource {
                        anchors.fill: parent
                        process: currentProcess ? currentProcess.videoMapperLabel : "" 
                        port: 0
                        visible: runStopSwitch.checked
                    }
                    
                    // Placeholder when video is not showing
                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (!currentProcess) {
                                return "Please select a model"
                            } else if (!modelFilePathField.hasValidPath) {
                                return "Please select an ONNX model file"
                            } else if (cameraSelector.currentIndex <= 0) {
                                return "Please select a camera"
                            } else {
                                return "Ready to start: " + currentProcess.scenarioLabel
                            }
                        }
                        color: appStyle.textColorSecondary
                        font.family: appStyle.fontFamily
                        font.pixelSize: appStyle.fontSizeBody
                        visible: !runStopSwitch.checked
                    }
                }
            }



            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
                Layout.bottomMargin: appStyle.padding

                CustomSwitch {
                    id: runStopSwitch
                    text: runStopSwitch.checked ? "Running" : "Stopped"
                    // Always enabled - validation will show feedback
                    onCheckedChanged: {
                        if (checked) {
                            if (validateBeforeStart()) {
                                startTriggeredScenario()
                            } else {
                                // Validation failed, uncheck the switch and show feedback
                                runStopSwitch.checked = false
                            }
                        } else {
                            if (isRunning) {
                                stopCurrentProcess()
                            }
                        }
                    }
                }

                CustomLabel {
                    text: {
                        if (!currentProcess) {
                            return "Please select a model"
                        } else if (!modelFilePathField.hasValidPath) {
                            return "Please select an ONNX model file"
                        } else if (cameraSelector.currentIndex <= 0) {
                            return "Please select a camera"
                        } else if (isRunning) {
                            return "Current model running: " + currentProcess.scenarioLabel
                        } else {
                            return "Ready to start: " + currentProcess.scenarioLabel
                        }
                    }
                }
            }
        }
    }
}
