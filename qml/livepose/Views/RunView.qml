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
    property string inputSource: "camera"
    property string videoFilePath: ""
    
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
    
    function updateInputSourceMixer() {
        var cameraAlpha = inputSource === "camera" ? 1.0 : 0.0
        var videoAlpha = inputSource === "video" ? 1.0 : 0.0
        try {
            if (pose_video_Mixer.alpha1) Score.setValue(pose_video_Mixer.alpha1, cameraAlpha)
            if (pose_video_Mixer.alpha2) Score.setValue(pose_video_Mixer.alpha2, videoAlpha)
            if (obj_video_Mixer.alpha1) Score.setValue(obj_video_Mixer.alpha1, cameraAlpha)
            if (obj_video_Mixer.alpha2) Score.setValue(obj_video_Mixer.alpha2, videoAlpha)
        } catch(e) { }
    }
    
    function setVideoPath(path) {
        if (path === "") return
        try {
            if (pose_video.process_object) pose_video.process_object.path = path
            if (obj_video.process_object) obj_video.process_object.path = path
        } catch(e) { }
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
        QtObject { id: pose_video
            property var process_object : Score.find("pose video");
        }
        QtObject { id: obj_video
            property var process_object : Score.find("obj video");
        }
        QtObject { id: pose_video_Mixer
            property var process_object : Score.find("Pose Video Mixer");
            property var alpha1 : Score.inlet(process_object, 8);
            property var alpha2 : Score.inlet(process_object, 9);
        }
        QtObject { id: obj_video_Mixer
            property var process_object : Score.find("Obj Video Mixer");
            property var alpha1 : Score.inlet(process_object, 8);
            property var alpha2 : Score.inlet(process_object, 9);
        }
    }

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
            logger.log("Cannot start: No AI model selected")
            showModelError = true
            return false
        }
        if (!modelFilePathField.hasValidPath) {
            logger.log("Cannot start: No ONNX model file selected")
            showModelFileError = true
            return false
        }
        if (currentProcess.isObjectDetector && !classesFilePathField.hasValidPath) {
            logger.log("Cannot start: No classes file selected for object detection")
            showClassesFileError = true
            return false
        }
        if (inputSource === "camera" && cameraSelector.currentIndex <= 0) {
            logger.log("Cannot start: No camera selected")
            showCameraError = true
            return false
        }
        if (inputSource === "video" && videoFilePath === "") {
            logger.log("Cannot start: No video file selected")
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
        if (inputSource === "camera" && cameraSelector.currentIndex > 0) {
            const cameraSettings = cameraList[cameraSelector.currentIndex - 1].settings
            Score.removeDevice("Camera")
            Score.createDevice("Camera", "d615690b-f2e2-447b-b70e-a800552db69c", cameraSettings)
            const inputPort = getVideoInPortViaMapper(currentProcess.videoMapperLabel);
            if (inputPort) Score.setAddress(inputPort, "Camera:/")
        }
        if (inputSource === "video" && videoFilePath !== "") {
            setVideoPath(videoFilePath)
        }
        updateInputSourceMixer()

        if (!oscReady) {
            try { Score.removeDevice("MyOSC"); } catch(e) {}
            const host = (oscIpAddress.text || "127.0.0.1").trim();
            const outPort = parseInt(oscPort.text) || 9000;
            const inPort = (outPort === 9000 ? 9001 : outPort + 1);
            Score.createOSCDevice("MyOSC", host, inPort, outPort);
            try { Score.createAddress("MyOSC:/skeleton", "List"); } catch (_) {}
            oscReady = true;
        }

        Score.endMacro();
        Score.play();
        const trigger = Score.find(currentProcess.triggerName);
        if (trigger && typeof trigger.triggeredByGui === 'function')
            trigger.triggeredByGui();
        isRunning = true;
        isStarting = false;
        var inputDesc = inputSource === "camera" ? cameraPrettyNamesList[cameraSelector.currentIndex - 1] : videoFilePath
        logger.log("Started: " + currentProcess.scenarioLabel + "\nInput: " + inputDesc + "\nOSC: " + oscIpAddress.text + ":" + oscPort.text);
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
        if (appSettings.lastInputSource !== "") inputSource = appSettings.lastInputSource
        if (appSettings.lastVideoPath !== "") videoFilePath = appSettings.lastVideoPath
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
                text: "Input Source"
                font.bold: true
                font.pixelSize: appStyle.fontSizeSubtitle
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: appStyle.spacing
                
                Button {
                    text: "Camera"
                    font.family: appStyle.fontFamily
                    font.pixelSize: appStyle.fontSizeBody
                    font.bold: inputSource === "camera"
                    Layout.fillWidth: true
                    onClicked: {
                        inputSource = "camera"
                        appSettings.lastInputSource = "camera"
                        updateInputSourceMixer()
                    }
                }
                
                Button {
                    text: "Video File"
                    font.family: appStyle.fontFamily
                    font.pixelSize: appStyle.fontSizeBody
                    font.bold: inputSource === "video"
                    Layout.fillWidth: true
                    onClicked: {
                        inputSource = "video"
                        appSettings.lastInputSource = "video"
                        updateInputSourceMixer()
                    }
                }
            }

            CustomComboBox {
                id: cameraSelector
                Layout.fillWidth: true
                visible: inputSource === "camera"
                model: [" ", ...cameraPrettyNamesList]
                
                onCurrentIndexChanged: {
                    showCameraError = false
                    if (currentIndex <= 0) return;
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
            
            CustomLabel {
                visible: showCameraError && inputSource === "camera"
                text: "Please select a camera"
                color: appStyle.errorColor
                font.pixelSize: appStyle.fontSizeSmall
            }
            
            RowLayout {
                Layout.fillWidth: true
                visible: inputSource === "video"
                
                CustomTextField {
                    id: videoFilePathField
                    Layout.fillWidth: true
                    placeholderText: "Select video file..."
                    text: videoFilePath
                    onTextChanged: {
                        videoFilePath = text
                        setVideoPath(text)
                        appSettings.lastVideoPath = text
                    }
                }
                
                Button {
                    text: "Browse"
                    font.family: appStyle.fontFamily
                    font.pixelSize: appStyle.fontSizeBody
                    onClicked: videoFileDialog.open()
                }
            }
            
            FileDialog {
                id: videoFileDialog
                title: "Select Video File"
                nameFilters: ["Video Files (*.mp4 *.avi *.mov *.mkv *.webm)", "All Files (*)"]
                onAccepted: {
                    if (!selectedFile) return
                    var filePath = selectedFile.toString()
                    if (filePath.startsWith("file://")) filePath = filePath.substring(7)
                    videoFilePathField.text = filePath
                }
            }
            
            CustomLabel {
                visible: inputSource === "video" && videoFilePath === ""
                text: "Please select a video file"
                color: appStyle.errorColor
                font.pixelSize: appStyle.fontSizeSmall
            }

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

            RowLayout {
                Layout.fillWidth: true
                spacing: appStyle.spacing
                
                CustomTextField {
                    id: oscIpAddress
                    Layout.fillWidth: true
                    placeholderText: "IP (e.g. 127.0.0.1)"
                    text: "127.0.0.1"
                    enabled: !isRunning
                    onTextChanged: appSettings.oscIpAddress = text
                }

                CustomTextField {
                    id: oscPort
                    Layout.fillWidth: true
                    placeholderText: "Port (e.g. 9000)"
                    text: "9000"
                    enabled: !isRunning
                    validator: IntValidator { bottom: 1; top: 65535 }
                    onTextChanged: appSettings.oscPortValue = text
                }
            }

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

                Button {
                    id: startStopButton
                    text: isRunning ? "Stop" : "Start"
                    font.family: appStyle.fontFamily
                    font.pixelSize: appStyle.fontSizeBody
                    onClicked: {
                        if (isRunning) {
                            stopCurrentProcess()
                        } else {
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
