import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import Score.UI as UI
import livepose

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
    property bool pendingRestart: false
    
    property bool showModelError: false
    property bool showCameraError: false
    property bool showModelFileError: false
    property bool showClassesFileError: false
    property var modelPaths: ({})
    property var classesPaths: ({})

    // Connect to Score transport signals for play/stop events
    Connections {
        target: Score.transport()

        function onPlay() {
            console.log("[Transport] Play signal received");
            isRunning = true;
            isStarting = false;
            // Sync switch state (in case playback started externally)
            runStopSwitch.checked = true;
        }

        function onStop() {
            console.log("[Transport] Stop signal received");
            isRunning = false;
            isStarting = false;
            oscReady = false;

            // If a restart was requested, start again now that stop is confirmed
            if (pendingRestart) {
                pendingRestart = false;
                runStopSwitch.checked = true;
            } else {
                // Sync switch state (in case playback stopped externally)
                runStopSwitch.checked = false;
            }
        }
    }
    
    property var poseDetectorWorkflows: [
        "BlazePose",
        "RTMPose_COCO", 
        "RTMPose_Whole",
        "ViTPose",
        "YOLOPose",
        "MediaPipeHands",
        "FaceMesh",
        "BlazeFace",
        "MobileFaceNet"
    ]
    property var poseDetectorOutputModes: ["SkeletonOnImage", "SkeletonOnly"]
    property var poseDetectorDataFormats: ["Raw", "XYArray", "XYZArray", "LineArray"]

    function updateModelPath() {
        if (!currentProcess) return
        
        var filePath = modelFilePathField.text
        if (!filePath) return
        
        var modelPort = null
        if (currentProcess.isPoseDetector) {
            modelPort = pose_Detector.model
        } else if (currentProcess.isObjectDetector) {
            modelPort = object_Detector.model
        }
        
        if (modelPort) {
            Score.setValue(modelPort, filePath)
        }
    }

    function saveAllFieldsToScore() {
        updateModelPath()
        if (currentProcess && currentProcess.isObjectDetector && object_Detector.classes) {
            try { Score.setValue(object_Detector.classes, classesFilePathField.text) } catch(e) { }
        }
        if (currentProcess && currentProcess.isPoseDetector) {
            syncPoseDetectorSettings()
        }
    }
    
    function syncPoseDetectorSettings() {
        if (!pose_Detector.process_object || !currentProcess || !currentProcess.isPoseDetector) return
        try {
            if (pose_Detector.workflow) Score.setValue(pose_Detector.workflow, currentProcess.scenarioLabel)
            if (pose_Detector.output_Mode) Score.setValue(pose_Detector.output_Mode, poseDetectorOutputModes[outputModeSelector.currentIndex])
            if (pose_Detector.min_Confidence) Score.setValue(pose_Detector.min_Confidence, minConfidenceSlider.value)
            if (pose_Detector.draw_Skeleton) Score.setValue(pose_Detector.draw_Skeleton, drawSkeletonSwitch.checked)
            if (pose_Detector.data_Format) Score.setValue(pose_Detector.data_Format, poseDetectorDataFormats[dataFormatSelector.currentIndex])
        } catch(e) { }
    }
    
        
        if (currentProcess && currentProcess.scenarioLabel === "resnet" && resnet_detector.classes) {
            try {
                Score.setValue(resnet_detector.classes, classesFilePathField.text)
            } catch(e) {
                console.log("Error saving classes file:", e)
            }
        }
    }

    Item {
        id: objects
        QtObject { id: object_Detector
            property var process_object : Score.find("Object Detector");
            property var input : Score.inlet(process_object, 0);
            property var model : Score.inlet(process_object, 1);
            property var classes : Score.inlet(process_object, 2);
            property var model_input_resolution : Score.inlet(process_object, 3);
            property var out : Score.outlet(process_object, 0);
            property var detection : Score.outlet(process_object, 1);
        }
        QtObject { id: pose_Detector
            property var process_object : Score.find("Pose Detector");
            property var input : Score.inlet(process_object, 0);
            property var model : Score.inlet(process_object, 1);
            property var workflow : Score.inlet(process_object, 2);
            property var output_Mode : Score.inlet(process_object, 3);
            property var min_Confidence : Score.inlet(process_object, 4);
            property var draw_Skeleton : Score.inlet(process_object, 5);
            property var data_Format : Score.inlet(process_object, 6);
            property var out : Score.outlet(process_object, 0);
            property var detection : Score.outlet(process_object, 1);
            property var geometry : Score.outlet(process_object, 2);
        }
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

    // get the video in port via the video mapper
    function getVideoInPortViaMapper(videoMapperLabel) {
         if (!videoMapperLabel) return null;
         var videoMapper = Score.find(videoMapperLabel);
         if (!videoMapper) return null 
         return Score.port(videoMapper, "in");
     }

    function findAllScenarios() {
        availableProcesses = []
        var poseDetectorMapper = Score.find("pose_detector Video Mapper")
        if (poseDetectorMapper) {
            for (var w = 0; w < poseDetectorWorkflows.length; w++) {
                availableProcesses.push({
                    scenarioLabel: poseDetectorWorkflows[w],
                    videoMapperLabel: "pose_detector Video Mapper",
                    process: poseDetectorMapper,
                    triggerName: "pose_detectortrigger",
                    isPoseDetector: true,
                    isObjectDetector: false
                })
            }
        }
        
        var objectDetectorMapper = Score.find("object_detector Video Mapper")
        if (objectDetectorMapper) {
            availableProcesses.push({
                scenarioLabel: "ResNET (Object Detection)",
                videoMapperLabel: "object_detector Video Mapper",
                process: objectDetectorMapper,
                triggerName: "object_detectortrigger",
                isPoseDetector: false,
                isObjectDetector: true
            })
        }
    
        var modelList = [" "]
        for (var j = 0; j < availableProcesses.length; j++) {
            modelList.push(availableProcesses[j].scenarioLabel)
        }

        if (availableProcesses.length > 0) {
            backendSelector.model = modelList
            backendSelector.currentIndex = 1
            currentProcess = availableProcesses[0]
        } else {
            backendSelector.model = [" "]
        }
    }

    function enumerateCameras() {
        try {
            deviceEnumerator = Score.enumerateDevices("d615690b-f2e2-447b-b70e-a800552db69c")
            deviceEnumerator.enumerate = true
            cameraList = []
            cameraPrettyNamesList = []
            for (let dev of deviceEnumerator.devices) {
                cameraList.push(dev)
                cameraPrettyNamesList.push(dev.category + ": " + dev.name)
            }
            cameraSelector.model = [" ", ...cameraPrettyNamesList]
        } catch (error) {
            logger.log("Error enumerating cameras: " + error)
        }
    }

    function validateBeforeStart() {
        showModelError = false
        showCameraError = false
        showModelFileError = false
        showClassesFileError = false
        
        if (!currentProcess || !currentProcess.process) {
            logger.log("Error: Please select a model first")
            showModelError = true
            return false
        }
        if (!modelFilePathField.hasValidPath) {
            logger.log("Error: Please select an ONNX model file")
            showModelFileError = true
            return false
        }
        if (currentProcess.scenarioLabel === "resnet" && !classesFilePathField.hasValidPath) {
            logger.log("Error: Please select a classes file")
            showClassesFileError = true
            return false
        }
        if (cameraSelector.currentIndex <= 0) {
            logger.log("Error: Please select a camera first")
            showCameraError = true
            return false
        }
        return true
    }

    function startTriggeredScenario() {
        if (!validateBeforeStart()) return;
        if (isStarting || isRunning) return;
        isStarting = true;
        saveAllFieldsToScore()

        Score.startMacro()

        // Camera is required (validated above)
        const cameraSettings = cameraList[cameraSelector.currentIndex - 1].settings
        Score.removeDevice("Camera")
        Score.createDevice("Camera", "d615690b-f2e2-447b-b70e-a800552db69c", cameraSettings)
        const inputPort = getVideoInPortViaMapper(currentProcess.videoMapperLabel);
        if (inputPort) Score.setAddress(inputPort, "Camera:/")

        if (!oscReady) {
            try { Score.removeDevice("MyOSC"); } catch(e) {}
            const host   = (oscIpAddress.text || "127.0.0.1").trim();
            const outPort = parseInt(oscPort.text) || 9000;
            const inPort  = (outPort === 9000 ? 9001 : outPort + 1);
            console.log(`[OSC] createOSCDevice MyOSC → ${host} (in:${inPort} out:${outPort})`);
            Score.createOSCDevice("MyOSC", host, inPort, outPort);

            try { Score.createAddress("MyOSC:/skeleton", "List"); } catch (_) {}
            oscReady = true;
        }

        Score.endMacro();
        Score.play();
        const trigger = Score.find(currentProcess.triggerName);
        if (trigger && typeof trigger.triggeredByGui === 'function')
            trigger.triggeredByGui();
        // State (isRunning, isStarting) is now managed by transport onPlay signal
        logger.log("Scenario started successfully");
    }

    function stopCurrentProcess() {
        var modelName = currentProcess ? currentProcess.scenarioLabel : "unknown"
        Score.stop();
        Score.startMacro();
        try { Score.removeDevice("MyOSC"); } catch(e) {}
        try { Score.removeDevice("Camera"); } catch(e) {}
        Score.endMacro();
        isRunning = false;
        isStarting = false;
        oscReady = false;
        logger.log("Stopped: " + modelName);
        
        if (pendingRestart) {
            pendingRestart = false;
            Qt.callLater(function() {
                if (validateBeforeStart()) startTriggeredScenario()
            })
        }
    }

    function restartIfRunning() {
        if (isRunning) {
            pendingRestart = true;
            stopCurrentProcess();
        }
    }

    Component.onCompleted: {
        enumerateCameras();
        findAllScenarios();

        restoreSavedSettings();
    }

    function restoreSavedSettings() {

        modelPaths["pose_detector"] = appSettings.poseDetectorModelPath
        modelPaths["object_detector"] = appSettings.objectDetectorModelPath
        classesPaths["object_detector"] = appSettings.objectDetectorClassesPath

        oscIpAddress.text = appSettings.oscIpAddress
        oscPort.text = appSettings.oscPortValue
        if (appSettings.poseDetectorOutputMode >= 0 && appSettings.poseDetectorOutputMode < poseDetectorOutputModes.length) {
            outputModeSelector.currentIndex = appSettings.poseDetectorOutputMode
        }
        if (appSettings.poseDetectorMinConfidence >= 0 && appSettings.poseDetectorMinConfidence <= 1) {
            minConfidenceSlider.value = appSettings.poseDetectorMinConfidence
        }
        drawSkeletonSwitch.checked = appSettings.poseDetectorDrawSkeleton !== false // default to true
        if (appSettings.poseDetectorDataFormat >= 0 && appSettings.poseDetectorDataFormat < poseDetectorDataFormats.length) {
            dataFormatSelector.currentIndex = appSettings.poseDetectorDataFormat
        }

        if (appSettings.lastSelectedModel !== "" && availableProcesses.length > 0) {
            for (var i = 0; i < availableProcesses.length; i++) {
                if (availableProcesses[i].scenarioLabel === appSettings.lastSelectedModel) {
                    backendSelector.currentIndex = i + 1; 
                    backendSelector.updateModel(backendSelector.currentIndex);
                    break;
                }
            }
        }

        if (appSettings.lastCameraName !== "" && cameraPrettyNamesList.length > 0) {
            for (var j = 0; j < cameraPrettyNamesList.length; j++) {
                if (cameraPrettyNamesList[j] === appSettings.lastCameraName) {
                    cameraSelector.currentIndex = j + 1;
                    break;
                }
            }
        }
    }

    Component.onDestruction: {
        saveAllFieldsToScore()
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            x: appStyle.padding
            width: parent.width - 2 * appStyle.padding
            spacing: appStyle.spacing * 0.75

            CustomLabel {
                text: "Model Configuration"
                font.bold: true
                font.pixelSize: appStyle.fontSizeTitle
                Layout.topMargin: appStyle.padding
            }

            CustomLabel {
                text: "Choose AI Model"
                font.bold: true
                font.pixelSize: appStyle.fontSizeSubtitle
            }

            CustomComboBox {
                id: backendSelector
                Layout.fillWidth: true
                model: [" "]
                
                function updateModel(currentIndex) {
                    restartIfRunning()
                    showModelError = false
                    if (currentProcess && currentProcess.scenarioLabel) {
                        var oldLabel = currentProcess.scenarioLabel
                        var saveKey = currentProcess.isPoseDetector ? "pose_detector" : 
                                      currentProcess.isObjectDetector ? "object_detector" : oldLabel
                        if (modelFilePathField.text) modelPaths[saveKey] = modelFilePathField.text
                        if (classesFilePathField.text && currentProcess.isObjectDetector) classesPaths["object_detector"] = classesFilePathField.text
                    }
                    if (currentIndex > 0) {
                        currentProcess = availableProcesses[currentIndex - 1];
                        var newLabel = currentProcess.scenarioLabel;
                        appSettings.lastSelectedModel = newLabel;
                        var loadKey = currentProcess.isPoseDetector ? "pose_detector" : 
                                      currentProcess.isObjectDetector ? "object_detector" : newLabel
                        modelFilePathField.text = modelPaths[loadKey] || "";
                        classesFilePathField.text = currentProcess.isObjectDetector ? (classesPaths["object_detector"] || "") : "";
                        if (currentProcess.isPoseDetector && pose_Detector.workflow) {
                            try { Score.setValue(pose_Detector.workflow, newLabel) } catch(e) { }
                        }
                    } else {
                        currentProcess = null;
                        modelFilePathField.text = "";
                        classesFilePathField.text = "";
                    }
                }

                onCurrentIndexChanged: updateModel(currentIndex)
            }
            
            CustomLabel {
                visible: showModelError
                text: "Please select a model"
                color: appStyle.errorColor
                font.pixelSize: appStyle.fontSizeSmall
            }

            ColumnLayout {
                Layout.fillWidth: true
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
                        text: ""
                        
                        property bool hasValidPath: text !== "" && text.indexOf(".onnx") >= 0
                        placeholderText: "Select ONNX model file..."
                        
                        property var currentModelPort: {
                            if (!runView.currentProcess) return null
                            try {
                                if (runView.currentProcess.isPoseDetector && pose_Detector) return pose_Detector.model
                                if (runView.currentProcess.isObjectDetector && object_Detector) return object_Detector.model
                            } catch(e) { }
                            return null
                        }
                        
                        onTextChanged: {
                            showModelFileError = false
                            if (currentModelPort) {
                                try { Score.setValue(currentModelPort, text) } catch(e) { }
                            }
                            if (runView.currentProcess) {
                                if (runView.currentProcess.isPoseDetector) appSettings.poseDetectorModelPath = text
                                else if (runView.currentProcess.isObjectDetector) appSettings.objectDetectorModelPath = text
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
                        if (!selectedFile) return
                        var filePath = selectedFile.toString()
                        if (filePath.startsWith("file://")) filePath = filePath.substring(7)
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
                    text: "Output Mode"
                    font.bold: true
                    visible: currentProcess && currentProcess.isPoseDetector
                }
                
                CustomComboBox {
                    id: outputModeSelector
                    Layout.fillWidth: true
                    visible: currentProcess && currentProcess.isPoseDetector
                    model: poseDetectorOutputModes
                    currentIndex: 0
                    
                    onCurrentIndexChanged: {
                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.output_Mode) {
                            try {
                                var modeValue = poseDetectorOutputModes[currentIndex]
                                Score.setValue(pose_Detector.output_Mode, modeValue)
                                appSettings.poseDetectorOutputMode = currentIndex
                            } catch(e) { }
                        }
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    visible: currentProcess && currentProcess.isPoseDetector
                    spacing: appStyle.spacing
                    
                    CustomLabel {
                        text: "Confidence: " + minConfidenceSlider.value.toFixed(2)
                        font.bold: true
                    }
                    
                    Slider {
                        id: minConfidenceSlider
                        Layout.fillWidth: true
                        Layout.minimumWidth: 80
                        from: 0.0
                        to: 1.0
                        value: 0.5
                        stepSize: 0.01
                        onValueChanged: {
                            if (currentProcess && currentProcess.isPoseDetector && pose_Detector.min_Confidence) {
                                try {
                                    Score.setValue(pose_Detector.min_Confidence, value)
                                    appSettings.poseDetectorMinConfidence = value
                                } catch(e) { }
                            }
                        }
                    }
                    
                    CheckBox {
                        id: drawSkeletonSwitch
                        text: "Draw Skeleton"
                        checked: true
                        Layout.leftMargin: appStyle.spacing
                        onCheckedChanged: {
                            if (currentProcess && currentProcess.isPoseDetector && pose_Detector.draw_Skeleton) {
                                try {
                                    Score.setValue(pose_Detector.draw_Skeleton, checked)
                                    appSettings.poseDetectorDrawSkeleton = checked
                                } catch(e) { }
                            }
                        }
                    }
                }
                
                CustomLabel {
                    text: "Data Format"
                    font.bold: true
                    visible: currentProcess && currentProcess.isPoseDetector
                }
                
                CustomComboBox {
                    id: dataFormatSelector
                    Layout.fillWidth: true
                    visible: currentProcess && currentProcess.isPoseDetector
                    model: poseDetectorDataFormats
                    currentIndex: 0
                    
                    onCurrentIndexChanged: {
                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.data_Format) {
                            try {
                                var formatValue = poseDetectorDataFormats[currentIndex]
                                Score.setValue(pose_Detector.data_Format, formatValue)
                                appSettings.poseDetectorDataFormat = currentIndex
                            } catch(e) { }
                        }
                    }
                }

                CustomLabel {
                    text: "Classes File (.txt)"
                    font.bold: true
                    visible: currentProcess && currentProcess.isObjectDetector
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: currentProcess && currentProcess.isObjectDetector
                    
                    CustomTextField {
                        id: classesFilePathField
                        Layout.fillWidth: true
                        text: ""
                        
                        property bool hasValidPath: text !== "" && text.indexOf(".txt") >= 0
                        placeholderText: "Select classes file..."
                        
                        property var currentClassesPort: {
                            if (!runView.currentProcess || !runView.currentProcess.isObjectDetector) return null
                            try { if (object_Detector) return object_Detector.classes } catch(e) { }
                            return null
                        }
                        
                        onTextChanged: {
                            showClassesFileError = false
                            if (currentClassesPort) {
                                try { Score.setValue(currentClassesPort, text) } catch(e) { }
                            }
                            appSettings.objectDetectorClassesPath = text
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
                    visible: showClassesFileError && currentProcess && currentProcess.isObjectDetector
                    text: "Please select a classes file"
                    color: appStyle.errorColor
                    font.pixelSize: appStyle.fontSizeSmall
                }
                
                FileDialog {
                    id: classesFileDialog
                    title: "Select Classes File"
                    nameFilters: ["Text Files (*.txt)", "All Files (*)"]
                    onAccepted: {
                        if (!selectedFile) return
                        var filePath = new URL(selectedFile).pathname.substr(Qt.platform.os === "windows" ? 1 : 0);
                        classesFilePathField.text = filePath
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: appStyle.separatorColor
            }

            CustomLabel {
                text: "Select Camera"
                font.bold: true
                font.pixelSize: appStyle.fontSizeSubtitle
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
            }

            CustomComboBox {
                id: cameraSelector
                Layout.fillWidth: true
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
                model: [" ", ...cameraPrettyNamesList]
                
                onCurrentIndexChanged: {
                    showCameraError = false  // Clear error when selection changes
                    if (currentIndex <= 0)
                        return;
                    Score.startMacro()

                    const camera_name = cameraPrettyNamesList[currentIndex - 1]
                    const camera_settings = cameraList[currentIndex - 1].settings
                    appSettings.lastCameraName = camera_name
                    Score.removeDevice("Camera")
                    Score.createDevice("Camera", "d615690b-f2e2-447b-b70e-a800552db69c", camera_settings)
                    if (currentProcess) {
                        const inputPort = getVideoInPortViaMapper(currentProcess.videoMapperLabel)
                        if (inputPort) Score.setAddress(inputPort, "Camera:/")
                    }
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

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: appStyle.separatorColor
            }

            CustomLabel {
                text: "OSC Output Settings"
                font.bold: true
                font.pixelSize: appStyle.fontSizeSubtitle
            }

            CustomTextField {
                id: oscIpAddress
                Layout.fillWidth: true
                Layout.leftMargin: appStyle.padding
                Layout.rightMargin: appStyle.padding
                placeholderText: "IP (e.g. 127.0.0.1)"
                text: "127.0.0.1"
                enabled: !runStopSwitch.checked
                onTextChanged: appSettings.oscIpAddress = text
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
                onTextChanged: appSettings.oscPortValue = text
            }

            // --- Expose model properties ---

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: appStyle.separatorColor
            }

            CustomLabel {
                text: "Video Preview"
                font.bold: true
                font.pixelSize: appStyle.fontSizeSubtitle
            }

            Rectangle {
                id: videoPreviewFrame
                Layout.fillWidth: true
                Layout.preferredHeight: width / aspectRatio
                Layout.minimumWidth: 360
                Layout.minimumHeight: 200
                color: "transparent"
                radius: appStyle.borderRadius
                border.color: appStyle.borderColor
                border.width: 1
                
                readonly property real aspectRatio: 16 / 9
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
                        id: textureSource
                        width: 1280
                        height: 720
                        process: currentProcess ? currentProcess.videoMapperLabel : "" 
                        port: 0
                        visible: isRunning
                    }
                    ShaderEffectSource {
                        anchors.fill: parent
                        sourceItem: textureSource
                        hideSource: true
                    }
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
                        visible: !isRunning
                    }
                }
            }



            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: appStyle.padding

                CustomSwitch {
                    id: runStopSwitch
                    text: runStopSwitch.checked ? "Running" : "Stopped"
                    // Always enabled - validation will show feedback
                    onCheckedChanged: {
                        if (checked) {
                            if (validateBeforeStart()) {
                                startTriggeredScenario()
                            }
                        }
                    }
                }

                CustomLabel {
                    text: {
                        if (!currentProcess) return "Please select a model"
                        if (!modelFilePathField.hasValidPath) return "Please select an ONNX model file"
                        if (cameraSelector.currentIndex <= 0) return "Please select a camera"
                        if (isRunning) return "Running: " + currentProcess.scenarioLabel
                        return "Ready: " + currentProcess.scenarioLabel
                    }
                }
            }
        }
    }
}
