import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
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
    property bool isPaused: false
    property bool oscReady: false
    property bool pendingRestart: false
    
    property bool showModelError: false
    property bool showCameraError: false
    property bool showModelFileError: false
    property var modelPaths: ({})
    property string inputSource: "camera"
    property string videoFilePath: ""
    
    property var poseDetectorWorkflows: [
        "Auto",
        "BlazePose",
        "RTMPose_COCO",
        "RTMPose_Whole",
        "ViTPose",
        "YOLOPose",
        "AnimalPose",
        "MediaPipeHands",
        "FaceMesh",
        "BlazeFace",
        "MobileFaceNet",
        "RTMPoseFace",
        "BoxDetection"
    ]
    property var poseDetectorOutputModes: ["SkeletonOnImage", "SkeletonOnly"]
    property var poseDetectorDataFormats: ["Raw", "XYArray", "XYZArray", "LineArray", "WorldXYZArray"]
    property var poseDetectorSkeletonTypes: ["Native", "Coco17", "OpenPoseCoco18", "OpenPoseBody25", "Halpe26", "Mpii16", "H36m17", "Dlib68", "Hand21"]
    property var poseDetectorMotionGates: ["None", "MaxSpeed", "Mahalanobis"]
    property var poseDetectorReidPreprocess: ["Auto", "ImageNetRGB", "RawBGR", "RawRGB", "ZeroOneRGB", "ArcFaceRGB"]

    function updateModelPath() {
        if (!currentProcess) return
        
        var filePath = modelFilePathField.text
        if (!filePath) return
        
        if (pose_Detector.model) {
            Score.setValue(pose_Detector.model, filePath)
        }
    }

    function saveAllFieldsToScore() {
        updateModelPath()
        syncPoseDetectorSettings()
    }
    
    function syncPoseDetectorSettings() {
        if (!pose_Detector.process_object || !currentProcess || !currentProcess.isPoseDetector) return
        try {
            if (pose_Detector.workflow) Score.setValue(pose_Detector.workflow, currentProcess.scenarioLabel)
            if (pose_Detector.det_Model) Score.setValue(pose_Detector.det_Model, detectionModelFilePathField.text)
            if (pose_Detector.output_Mode) Score.setValue(pose_Detector.output_Mode, poseDetectorOutputModes[outputModeSelector.currentIndex])
            if (pose_Detector.min_Confidence) Score.setValue(pose_Detector.min_Confidence, minConfidenceSlider.value)
            if (pose_Detector.draw_Skeleton) Score.setValue(pose_Detector.draw_Skeleton, drawSkeletonSwitch.checked)
            if (pose_Detector.data_Format) Score.setValue(pose_Detector.data_Format, poseDetectorDataFormats[dataFormatSelector.currentIndex])
            if (pose_Detector.track_ROI) Score.setValue(pose_Detector.track_ROI, trackROISwitch.checked)
            if (pose_Detector.smoothing) Score.setValue(pose_Detector.smoothing, smoothingSwitch.checked)
            if (pose_Detector.smoothing_Amount) Score.setValue(pose_Detector.smoothing_Amount, smoothingAmountSlider.value)
            if (pose_Detector.track_IDs) Score.setValue(pose_Detector.track_IDs, trackIDsSwitch.checked)
            if (pose_Detector.max_Instances) Score.setValue(pose_Detector.max_Instances, maxInstancesSpinBox.value)
            if (pose_Detector.detector_Cadence) Score.setValue(pose_Detector.detector_Cadence, detectorCadenceSpinBox.value)
            if (pose_Detector.draw_Landmarks) Score.setValue(pose_Detector.draw_Landmarks, drawLandmarksSwitch.checked)
            if (pose_Detector.draw_Boxes) Score.setValue(pose_Detector.draw_Boxes, drawBoxesSwitch.checked)
            if (pose_Detector.skeleton_Type) Score.setValue(pose_Detector.skeleton_Type, poseDetectorSkeletonTypes[skeletonTypeSelector.currentIndex])
            if (pose_Detector.track_Memory) Score.setValue(pose_Detector.track_Memory, trackMemorySpinBox.value)
            if (pose_Detector.hold_Frames) Score.setValue(pose_Detector.hold_Frames, holdFramesSpinBox.value)
            if (pose_Detector.motion_Gate) Score.setValue(pose_Detector.motion_Gate, poseDetectorMotionGates[motionGateSelector.currentIndex])
            if (pose_Detector.max_Speed) Score.setValue(pose_Detector.max_Speed, maxSpeedSlider.value)
            if (pose_Detector.birth_Gate) Score.setValue(pose_Detector.birth_Gate, birthGateSwitch.checked)
            if (pose_Detector.strict_Confirm) Score.setValue(pose_Detector.strict_Confirm, strictConfirmSwitch.checked)
            if (pose_Detector.reid_Model) Score.setValue(pose_Detector.reid_Model, reidModelFilePathField.text)
            if (pose_Detector.reid) Score.setValue(pose_Detector.reid, reidSwitch.checked)
            if (pose_Detector.reid_Weight) Score.setValue(pose_Detector.reid_Weight, reidWeightSlider.value)
            if (pose_Detector.reid_Preprocess) Score.setValue(pose_Detector.reid_Preprocess, poseDetectorReidPreprocess[reidPreprocessSelector.currentIndex])
            if (pose_Detector.reid_Memory) Score.setValue(pose_Detector.reid_Memory, reidMemorySpinBox.value)
            if (pose_Detector.reid_Margin) Score.setValue(pose_Detector.reid_Margin, reidMarginSlider.value)
            if (pose_Detector.detection_Class) Score.setValue(pose_Detector.detection_Class, detectionClassSpinBox.value)
            if (pose_Detector.class_File) Score.setValue(pose_Detector.class_File, classNamesFilePathField.text)
        } catch(e) { }
    }
    
    function setVideoPath(path) {
        if (path === "") return
        try {
            if (video_in.process_object) video_in.process_object.path = path
        } catch(e) { }
    }

    Item {
        id: objects
        QtObject { id: pose_Detector
            property var process_object : null;
            property var input : Score.inlet(process_object, 0);
            property var model : Score.inlet(process_object, 1);
            property var workflow : Score.inlet(process_object, 2);
            property var output_Mode : Score.inlet(process_object, 3);
            property var min_Confidence : Score.inlet(process_object, 4);
            property var draw_Skeleton : Score.inlet(process_object, 5);
            property var data_Format : Score.inlet(process_object, 6);
            property var det_Model : Score.inlet(process_object, 7);
            property var track_ROI : Score.inlet(process_object, 8);
            property var smoothing : Score.inlet(process_object, 9);
            property var smoothing_Amount : Score.inlet(process_object, 10);
            property var track_IDs : Score.inlet(process_object, 11);
            property var max_Instances : Score.inlet(process_object, 12);
            property var detector_Cadence : Score.inlet(process_object, 13);
            property var reid_Model : Score.inlet(process_object, 14);
            property var reid : Score.inlet(process_object, 15);
            property var reid_Weight : Score.inlet(process_object, 16);
            property var reid_Preprocess : Score.inlet(process_object, 17);
            property var draw_Boxes : Score.inlet(process_object, 18);
            property var detection_Class : Score.inlet(process_object, 19);
            property var draw_Landmarks : Score.inlet(process_object, 20);
            property var motion_Gate : Score.inlet(process_object, 21);
            property var max_Speed : Score.inlet(process_object, 22);
            property var birth_Gate : Score.inlet(process_object, 23);
            property var strict_Confirm : Score.inlet(process_object, 24);
            property var skeleton_Type : Score.inlet(process_object, 25);
            property var class_File : Score.inlet(process_object, 26);
            property var track_Memory : Score.inlet(process_object, 27);
            property var reid_Memory : Score.inlet(process_object, 28);
            property var reid_Margin : Score.inlet(process_object, 29);
            property var hold_Frames : Score.inlet(process_object, 30);
            property var out : Score.outlet(process_object, 0);
            property var detection : Score.outlet(process_object, 1);
            property var geometry : Score.outlet(process_object, 2);
            property var poses : Score.outlet(process_object, 3);
            property var poses_geometry : Score.outlet(process_object, 4);
            property var count : Score.outlet(process_object, 5);
        }
        QtObject { id: video_in
            property var process_object : null;
        }
        QtObject { id: preview_mapper
            property var process_object : null;
        }
    }

    readonly property string previewPassthroughShader: '/*{ "ISFVSN": "2", "DESCRIPTION": "passthrough", "INPUTS": [ { "NAME": "inputImage", "TYPE": "image" } ] }*/\nvoid main() { gl_FragColor = IMG_THIS_PIXEL(inputImage); }'

    function buildBackends() {
        availableProcesses = []
        for (var w = 0; w < poseDetectorWorkflows.length; w++) {
            availableProcesses.push({
                scenarioLabel: poseDetectorWorkflows[w],
                processName: "Pose Detector",
                isPoseDetector: true
            })
        }

        var modelList = [" "]
        for (var j = 0; j < availableProcesses.length; j++) {
            modelList.push(availableProcesses[j].scenarioLabel)
        }
        backendSelector.model = modelList
        backendSelector.currentIndex = 1
        currentProcess = availableProcesses[0]
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

        if (!currentProcess) {
            logger.log("Cannot start: No AI model selected")
            showModelError = true
            return false
        }
        // BoxDetection runs the Detection Model only (no landmark stage), so it
        // requires a Detection Model rather than the Landmark Model.
        var isBoxDetection = currentProcess.isPoseDetector && currentProcess.scenarioLabel === "BoxDetection"
        if (isBoxDetection) {
            if (detectionModelFilePathField.text.indexOf(".onnx") < 0) {
                logger.log("Cannot start: BoxDetection needs a Detection Model (.onnx)")
                showModelFileError = true
                return false
            }
        } else if (!modelFilePathField.hasValidPath) {
            logger.log("Cannot start: No ONNX model file selected")
            showModelFileError = true
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

        Score.startMacro()

        var proc = Score.createProcess(Score.rootInterval(), "Pose Detector", "")
        if (!proc) {
            Score.endMacro()
            isStarting = false
            logger.log("Cannot start: failed to create the Pose Detector process")
            return
        }
        Score.setName(proc, "livepose detector")
        pose_Detector.process_object = proc

        var inPort = Score.inlet(proc, 0)
        if (inputSource === "camera" && cameraSelector.currentIndex > 0) {
            const cameraSettings = cameraList[cameraSelector.currentIndex - 1].settings
            try { Score.removeDevice("Camera") } catch(e) {}
            Score.createDevice("Camera", "d615690b-f2e2-447b-b70e-a800552db69c", cameraSettings)
            if (inPort) Score.setAddress(inPort, "Camera:/")
        } else if (inputSource === "video" && videoFilePath !== "") {
            var vid = Score.createProcess(Score.rootInterval(), "Video", "")
            video_in.process_object = vid
            if (vid) {
                try { vid.path = videoFilePath; vid.scaleMode = 1 } catch(e) {}
                var vidOut = Score.outlet(vid, 0)
                if (vidOut && inPort) Score.createCable(vidOut, inPort)
            }
        }

        var mapper = Score.createProcess(Score.rootInterval(), "ISF Shader", "")
        if (mapper) {
            preview_mapper.process_object = mapper
            Score.loadPreset(mapper, JSON.stringify({
                Key: { Uuid: "74ca45ff-92c9-44a0-8f1a-754dea05ee1b", Effect: "" },
                Name: "ISF Shader",
                Preset: { Fragment: previewPassthroughShader, Vertex: "", Controls: [] }
            }))
            Score.setName(mapper, "livepose preview")
            var detOut = Score.outlet(proc, 0)
            var mapIn = Score.inlet(mapper, 0)
            if (detOut && mapIn) Score.createCable(detOut, mapIn)
        }

        saveAllFieldsToScore()

        try { Score.removeDevice("MyOSC") } catch(e) {}
        const host = (oscIpAddress.text || "127.0.0.1").trim();
        const outPort = parseInt(oscPort.text) || 9000;
        const inOscPort = (outPort === 9000 ? 9001 : outPort + 1);
        Score.createOSCDevice("MyOSC", host, inOscPort, outPort);
        try { Score.createAddress("MyOSC:/skeleton", "List") } catch(e) {}
        var dataOut = Score.outlet(proc, 2)
        if (dataOut) Score.setAddress(dataOut, "MyOSC:/skeleton")
        oscReady = true;

        Score.endMacro();
        Score.play();
        isRunning = true;
        isPaused = false;
        isStarting = false;
        var inputDesc = inputSource === "camera" ? cameraPrettyNamesList[cameraSelector.currentIndex - 1] : videoFilePath
        logger.log("Started: " + currentProcess.scenarioLabel + "\nInput: " + inputDesc + "\nOSC: " + host + ":" + outPort);
    }

    function stopCurrentProcess() {
        var modelName = currentProcess ? currentProcess.scenarioLabel : "unknown"
        Score.stop();
        Score.startMacro();
        try { Score.removeDevice("MyOSC"); } catch(e) {}
        try { Score.removeDevice("Camera"); } catch(e) {}
        try { if (pose_Detector.process_object) Score.remove(pose_Detector.process_object) } catch(e) {}
        try { if (preview_mapper.process_object) Score.remove(preview_mapper.process_object) } catch(e) {}
        try { if (video_in.process_object) Score.remove(video_in.process_object) } catch(e) {}
        pose_Detector.process_object = null
        preview_mapper.process_object = null
        video_in.process_object = null
        Score.endMacro();
        isRunning = false;
        isStarting = false;
        oscReady = false;
        isPaused = false;
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
        buildBackends();

        restoreSavedSettings();
    }

    function restoreSavedSettings() {

        modelPaths["pose_detector"] = appSettings.poseDetectorModelPath

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

        detectionModelFilePathField.text = appSettings.poseDetectorDetectionModelPath
        trackROISwitch.checked = appSettings.poseDetectorTrackROI === true // default to false
        smoothingSwitch.checked = appSettings.poseDetectorSmoothing !== false // default to true
        if (appSettings.poseDetectorSmoothingAmount >= 0 && appSettings.poseDetectorSmoothingAmount <= 1) {
            smoothingAmountSlider.value = appSettings.poseDetectorSmoothingAmount
        }
        trackIDsSwitch.checked = appSettings.poseDetectorTrackIDs === true // default to false
        if (appSettings.poseDetectorMaxInstances >= 1 && appSettings.poseDetectorMaxInstances <= 16) {
            maxInstancesSpinBox.value = appSettings.poseDetectorMaxInstances
        }
        if (appSettings.poseDetectorDetectorCadence >= 1 && appSettings.poseDetectorDetectorCadence <= 30) {
            detectorCadenceSpinBox.value = appSettings.poseDetectorDetectorCadence
        }

        drawLandmarksSwitch.checked = appSettings.poseDetectorDrawLandmarks !== false // default to true
        drawBoxesSwitch.checked = appSettings.poseDetectorDrawBoxes === true // default to false
        if (appSettings.poseDetectorSkeletonType >= 0 && appSettings.poseDetectorSkeletonType < poseDetectorSkeletonTypes.length) {
            skeletonTypeSelector.currentIndex = appSettings.poseDetectorSkeletonType
        }
        if (appSettings.poseDetectorTrackMemory >= 1 && appSettings.poseDetectorTrackMemory <= 300) {
            trackMemorySpinBox.value = appSettings.poseDetectorTrackMemory
        }
        if (appSettings.poseDetectorHoldFrames >= 0 && appSettings.poseDetectorHoldFrames <= 60) {
            holdFramesSpinBox.value = appSettings.poseDetectorHoldFrames
        }
        if (appSettings.poseDetectorMotionGate >= 0 && appSettings.poseDetectorMotionGate < poseDetectorMotionGates.length) {
            motionGateSelector.currentIndex = appSettings.poseDetectorMotionGate
        }
        if (appSettings.poseDetectorMaxSpeed >= 0.25 && appSettings.poseDetectorMaxSpeed <= 6) {
            maxSpeedSlider.value = appSettings.poseDetectorMaxSpeed
        }
        birthGateSwitch.checked = appSettings.poseDetectorBirthGate !== false // default to true
        strictConfirmSwitch.checked = appSettings.poseDetectorStrictConfirm === true // default to false
        reidModelFilePathField.text = appSettings.poseDetectorReidModelPath
        reidSwitch.checked = appSettings.poseDetectorReid === true // default to false
        if (appSettings.poseDetectorReidWeight >= 0 && appSettings.poseDetectorReidWeight <= 1) {
            reidWeightSlider.value = appSettings.poseDetectorReidWeight
        }
        if (appSettings.poseDetectorReidPreprocess >= 0 && appSettings.poseDetectorReidPreprocess < poseDetectorReidPreprocess.length) {
            reidPreprocessSelector.currentIndex = appSettings.poseDetectorReidPreprocess
        }
        if (appSettings.poseDetectorReidMemory >= 0 && appSettings.poseDetectorReidMemory <= 18000) {
            reidMemorySpinBox.value = appSettings.poseDetectorReidMemory
        }
        if (appSettings.poseDetectorReidMargin >= 0 && appSettings.poseDetectorReidMargin <= 0.5) {
            reidMarginSlider.value = appSettings.poseDetectorReidMargin
        }
        if (appSettings.poseDetectorDetectionClass >= -1 && appSettings.poseDetectorDetectionClass <= 90) {
            detectionClassSpinBox.value = appSettings.poseDetectorDetectionClass
        }
        classNamesFilePathField.text = appSettings.poseDetectorClassNamesFile

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

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal
        handle: Rectangle {
            implicitWidth: 3
            color: SplitHandle.pressed ? appStyle.primaryColor
                 : SplitHandle.hovered ? appStyle.borderColor : appStyle.separatorColor
        }

        ScrollView {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 380
            contentWidth: availableWidth

            ColumnLayout {
                x: appStyle.padding
                width: parent.width - 2 * appStyle.padding
                spacing: appStyle.spacing * 0.75

                CustomLabel {
                    text: "Input Source"
                    font.bold: true
                    font.pixelSize: appStyle.fontSizeSubtitle
                    Layout.topMargin: appStyle.padding
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
                            restartIfRunning()
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
                            restartIfRunning()
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
                        appSettings.lastCameraName = cameraPrettyNamesList[currentIndex - 1]
                        if (isRunning && inputSource === "camera") {
                            Score.startMacro()
                            const camera_settings = cameraList[currentIndex - 1].settings
                            Score.removeDevice("Camera")
                            Score.createDevice("Camera", "d615690b-f2e2-447b-b70e-a800552db69c", camera_settings)
                            if (pose_Detector.process_object) {
                                const inputPort = Score.inlet(pose_Detector.process_object, 0)
                                if (inputPort) Score.setAddress(inputPort, "Camera:/")
                            }
                            Score.endMacro()
                        }
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
                        onClicked: Util.openFileDialog("Select Video File", "Video Files (*.mp4 *.avi *.mov *.mkv *.webm);;All Files (*)", videoFilePathField.text, function(path) { if (path) videoFilePathField.text = path })
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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: appStyle.spacing

                    TabBar {
                        id: poseTabBar
                        Layout.fillWidth: true
                        TabButton { text: "Models" }
                        TabButton { text: "Output" }
                        TabButton { text: "Tracking" }
                        TabButton { text: "Re-ID" }
                        TabButton { text: "Detection" }
                        TabButton { text: "Smoothing" }
                        TabButton { text: "Network" }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        currentIndex: poseTabBar.currentIndex

                        // --- Models ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: appStyle.spacing

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
                                        if (modelFilePathField.text) modelPaths["pose_detector"] = modelFilePathField.text
                                    }
                                    if (currentIndex > 0) {
                                        currentProcess = availableProcesses[currentIndex - 1];
                                        var newLabel = currentProcess.scenarioLabel;
                                        appSettings.lastSelectedModel = newLabel;
                                        modelFilePathField.text = modelPaths["pose_detector"] || "";
                                        if (pose_Detector.workflow) {
                                            try { Score.setValue(pose_Detector.workflow, newLabel) } catch(e) { }
                                        }
                                    } else {
                                        currentProcess = null;
                                        modelFilePathField.text = "";
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
                            CustomLabel {
                                text: (currentProcess && currentProcess.isPoseDetector) ? "Landmark Model (ONNX)" : "ONNX Model File"
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
                                        try { return pose_Detector.model } catch(e) { }
                                        return null
                                    }

                                    onTextChanged: {
                                        showModelFileError = false
                                        if (currentModelPort) {
                                            try { Score.setValue(currentModelPort, text) } catch(e) { }
                                        }
                                        appSettings.poseDetectorModelPath = text
                                    }
                                }

                                Button {
                                    text: "Browse"
                                    font.family: appStyle.fontFamily
                                    font.pixelSize: appStyle.fontSizeBody
                                    onClicked: Util.openFileDialog("Select ONNX Model File", "ONNX Files (*.onnx);;All Files (*)", modelFilePathField.text, function(path) { if (path) modelFilePathField.text = path })
                                }
                            }


                            CustomLabel {
                                visible: showModelFileError
                                text: "Please select an ONNX model file"
                                color: appStyle.errorColor
                                font.pixelSize: appStyle.fontSizeSmall
                            }

                            CustomLabel {
                                text: "Detection Model (optional, two-stage)"
                                font.bold: true
                                visible: currentProcess && currentProcess.isPoseDetector
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: currentProcess && currentProcess.isPoseDetector

                                CustomTextField {
                                    id: detectionModelFilePathField
                                    Layout.fillWidth: true
                                    text: ""
                                    placeholderText: "Optional stage-1 detector ONNX (empty = single-stage)..."

                                    onTextChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.det_Model) {
                                            try { Score.setValue(pose_Detector.det_Model, text) } catch(e) { }
                                        }
                                        appSettings.poseDetectorDetectionModelPath = text
                                    }
                                }

                                Button {
                                    text: "Browse"
                                    font.family: appStyle.fontFamily
                                    font.pixelSize: appStyle.fontSizeBody
                                    onClicked: Util.openFileDialog("Select Detection Model (ONNX)", "ONNX Files (*.onnx);;All Files (*)", detectionModelFilePathField.text, function(path) { if (path) detectionModelFilePathField.text = path })
                                }

                                Button {
                                    text: "Clear"
                                    font.family: appStyle.fontFamily
                                    font.pixelSize: appStyle.fontSizeBody
                                    visible: detectionModelFilePathField.text !== ""
                                    onClicked: detectionModelFilePathField.text = ""
                                }
                            }
                        }

                        // --- Output ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: appStyle.spacing

                            CustomLabel { text: "Output Mode"; font.bold: true }
                            CustomComboBox {
                                id: outputModeSelector
                                Layout.fillWidth: true
                                model: poseDetectorOutputModes
                                currentIndex: 0
                                onCurrentIndexChanged: {
                                    if (currentProcess && currentProcess.isPoseDetector && pose_Detector.output_Mode) {
                                        try {
                                            Score.setValue(pose_Detector.output_Mode, poseDetectorOutputModes[currentIndex])
                                            appSettings.poseDetectorOutputMode = currentIndex
                                        } catch(e) { }
                                    }
                                }
                            }

                            CustomLabel { text: "Data Format"; font.bold: true }
                            CustomComboBox {
                                id: dataFormatSelector
                                Layout.fillWidth: true
                                model: poseDetectorDataFormats
                                currentIndex: 0
                                onCurrentIndexChanged: {
                                    if (currentProcess && currentProcess.isPoseDetector && pose_Detector.data_Format) {
                                        try {
                                            Score.setValue(pose_Detector.data_Format, poseDetectorDataFormats[currentIndex])
                                            appSettings.poseDetectorDataFormat = currentIndex
                                        } catch(e) { }
                                    }
                                }
                            }

                            CustomLabel { text: "Skeleton"; font.bold: true }
                            CustomComboBox {
                                id: skeletonTypeSelector
                                Layout.fillWidth: true
                                model: poseDetectorSkeletonTypes
                                currentIndex: 0
                                onCurrentIndexChanged: {
                                    if (currentProcess && currentProcess.isPoseDetector && pose_Detector.skeleton_Type) {
                                        try {
                                            Score.setValue(pose_Detector.skeleton_Type, poseDetectorSkeletonTypes[currentIndex])
                                            appSettings.poseDetectorSkeletonType = currentIndex
                                        } catch(e) { }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CheckBox {
                                    id: drawSkeletonSwitch
                                    text: "Draw Skeleton"
                                    checked: true
                                    onCheckedChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.draw_Skeleton) {
                                            try {
                                                Score.setValue(pose_Detector.draw_Skeleton, checked)
                                                appSettings.poseDetectorDrawSkeleton = checked
                                            } catch(e) { }
                                        }
                                    }
                                }
                                CheckBox {
                                    id: drawLandmarksSwitch
                                    text: "Draw Landmarks"
                                    checked: true
                                    Layout.leftMargin: appStyle.spacing
                                    onCheckedChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.draw_Landmarks) {
                                            try {
                                                Score.setValue(pose_Detector.draw_Landmarks, checked)
                                                appSettings.poseDetectorDrawLandmarks = checked
                                            } catch(e) { }
                                        }
                                    }
                                }
                                CheckBox {
                                    id: drawBoxesSwitch
                                    text: "Draw Boxes"
                                    checked: false
                                    Layout.leftMargin: appStyle.spacing
                                    onCheckedChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.draw_Boxes) {
                                            try {
                                                Score.setValue(pose_Detector.draw_Boxes, checked)
                                                appSettings.poseDetectorDrawBoxes = checked
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }
                        }

                        // --- Tracking ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: appStyle.spacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CustomLabel { text: "Confidence: " + minConfidenceSlider.value.toFixed(2); font.bold: true }
                                Slider {
                                    id: minConfidenceSlider
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 80
                                    from: 0.0; to: 1.0; value: 0.3; stepSize: 0.01
                                    onValueChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.min_Confidence) {
                                            try {
                                                Score.setValue(pose_Detector.min_Confidence, value)
                                                appSettings.poseDetectorMinConfidence = value
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CheckBox {
                                    id: trackIDsSwitch
                                    text: "Track IDs"
                                    checked: false
                                    onCheckedChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.track_IDs) {
                                            try {
                                                Score.setValue(pose_Detector.track_IDs, checked)
                                                appSettings.poseDetectorTrackIDs = checked
                                            } catch(e) { }
                                        }
                                    }
                                }
                                CheckBox {
                                    id: trackROISwitch
                                    text: "Track ROI"
                                    checked: false
                                    Layout.leftMargin: appStyle.spacing
                                    onCheckedChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.track_ROI) {
                                            try {
                                                Score.setValue(pose_Detector.track_ROI, checked)
                                                appSettings.poseDetectorTrackROI = checked
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CustomLabel { text: "Max Instances"; font.bold: true }
                                SpinBox {
                                    id: maxInstancesSpinBox
                                    from: 1; to: 16; value: 5; editable: true
                                    onValueChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.max_Instances) {
                                            try {
                                                Score.setValue(pose_Detector.max_Instances, value)
                                                appSettings.poseDetectorMaxInstances = value
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CustomLabel { text: "Track Memory"; font.bold: true }
                                SpinBox {
                                    id: trackMemorySpinBox
                                    from: 1; to: 300; value: 30; editable: true
                                    onValueChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.track_Memory) {
                                            try {
                                                Score.setValue(pose_Detector.track_Memory, value)
                                                appSettings.poseDetectorTrackMemory = value
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CustomLabel { text: "Detection Hold"; font.bold: true }
                                SpinBox {
                                    id: holdFramesSpinBox
                                    from: 0; to: 60; value: 6; editable: true
                                    onValueChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.hold_Frames) {
                                            try {
                                                Score.setValue(pose_Detector.hold_Frames, value)
                                                appSettings.poseDetectorHoldFrames = value
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CustomLabel { text: "Detector Cadence"; font.bold: true }
                                SpinBox {
                                    id: detectorCadenceSpinBox
                                    from: 1; to: 30; value: 4; editable: true
                                    onValueChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.detector_Cadence) {
                                            try {
                                                Score.setValue(pose_Detector.detector_Cadence, value)
                                                appSettings.poseDetectorDetectorCadence = value
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }

                            CustomLabel { text: "Motion Gate"; font.bold: true }
                            CustomComboBox {
                                id: motionGateSelector
                                Layout.fillWidth: true
                                model: poseDetectorMotionGates
                                currentIndex: 0
                                onCurrentIndexChanged: {
                                    if (currentProcess && currentProcess.isPoseDetector && pose_Detector.motion_Gate) {
                                        try {
                                            Score.setValue(pose_Detector.motion_Gate, poseDetectorMotionGates[currentIndex])
                                            appSettings.poseDetectorMotionGate = currentIndex
                                        } catch(e) { }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CustomLabel { text: "Max Speed: " + maxSpeedSlider.value.toFixed(2); font.bold: true }
                                Slider {
                                    id: maxSpeedSlider
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 80
                                    from: 0.25; to: 6.0; value: 2.0; stepSize: 0.05
                                    onValueChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.max_Speed) {
                                            try {
                                                Score.setValue(pose_Detector.max_Speed, value)
                                                appSettings.poseDetectorMaxSpeed = value
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CheckBox {
                                    id: birthGateSwitch
                                    text: "Birth Gate"
                                    checked: true
                                    onCheckedChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.birth_Gate) {
                                            try {
                                                Score.setValue(pose_Detector.birth_Gate, checked)
                                                appSettings.poseDetectorBirthGate = checked
                                            } catch(e) { }
                                        }
                                    }
                                }
                                CheckBox {
                                    id: strictConfirmSwitch
                                    text: "Strict Confirmation"
                                    checked: false
                                    Layout.leftMargin: appStyle.spacing
                                    onCheckedChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.strict_Confirm) {
                                            try {
                                                Score.setValue(pose_Detector.strict_Confirm, checked)
                                                appSettings.poseDetectorStrictConfirm = checked
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }
                        }

                        // --- Re-ID ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: appStyle.spacing

                            CustomLabel { text: "Re-ID Model (ONNX)"; font.bold: true }
                            RowLayout {
                                Layout.fillWidth: true
                                CustomTextField {
                                    id: reidModelFilePathField
                                    Layout.fillWidth: true
                                    text: ""
                                    placeholderText: "Optional Re-ID embedding ONNX..."
                                    onTextChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.reid_Model) {
                                            try { Score.setValue(pose_Detector.reid_Model, text) } catch(e) { }
                                        }
                                        appSettings.poseDetectorReidModelPath = text
                                    }
                                }
                                Button {
                                    text: "Browse"
                                    font.family: appStyle.fontFamily
                                    font.pixelSize: appStyle.fontSizeBody
                                    onClicked: Util.openFileDialog("Select Re-ID Model (ONNX)", "ONNX Files (*.onnx);;All Files (*)", reidModelFilePathField.text, function(path) { if (path) reidModelFilePathField.text = path })
                                }
                                Button {
                                    text: "Clear"
                                    font.family: appStyle.fontFamily
                                    font.pixelSize: appStyle.fontSizeBody
                                    visible: reidModelFilePathField.text !== ""
                                    onClicked: reidModelFilePathField.text = ""
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CheckBox {
                                    id: reidSwitch
                                    text: "Re-ID"
                                    checked: false
                                    onCheckedChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.reid) {
                                            try {
                                                Score.setValue(pose_Detector.reid, checked)
                                                appSettings.poseDetectorReid = checked
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CustomLabel { text: "Weight: " + reidWeightSlider.value.toFixed(2); font.bold: true }
                                Slider {
                                    id: reidWeightSlider
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 80
                                    from: 0.0; to: 1.0; value: 0.25; stepSize: 0.01
                                    onValueChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.reid_Weight) {
                                            try {
                                                Score.setValue(pose_Detector.reid_Weight, value)
                                                appSettings.poseDetectorReidWeight = value
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }

                            CustomLabel { text: "Re-ID Preprocess"; font.bold: true }
                            CustomComboBox {
                                id: reidPreprocessSelector
                                Layout.fillWidth: true
                                model: poseDetectorReidPreprocess
                                currentIndex: 0
                                onCurrentIndexChanged: {
                                    if (currentProcess && currentProcess.isPoseDetector && pose_Detector.reid_Preprocess) {
                                        try {
                                            Score.setValue(pose_Detector.reid_Preprocess, poseDetectorReidPreprocess[currentIndex])
                                            appSettings.poseDetectorReidPreprocess = currentIndex
                                        } catch(e) { }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CustomLabel { text: "Re-ID Memory"; font.bold: true }
                                SpinBox {
                                    id: reidMemorySpinBox
                                    from: 0; to: 18000; value: 1800; editable: true
                                    onValueChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.reid_Memory) {
                                            try {
                                                Score.setValue(pose_Detector.reid_Memory, value)
                                                appSettings.poseDetectorReidMemory = value
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CustomLabel { text: "Re-ID Margin: " + reidMarginSlider.value.toFixed(2); font.bold: true }
                                Slider {
                                    id: reidMarginSlider
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 80
                                    from: 0.0; to: 0.5; value: 0.1; stepSize: 0.01
                                    onValueChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.reid_Margin) {
                                            try {
                                                Score.setValue(pose_Detector.reid_Margin, value)
                                                appSettings.poseDetectorReidMargin = value
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }
                        }

                        // --- Detection ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: appStyle.spacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CustomLabel { text: "Detection Class"; font.bold: true }
                                SpinBox {
                                    id: detectionClassSpinBox
                                    from: -1; to: 90; value: -1; editable: true
                                    onValueChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.detection_Class) {
                                            try {
                                                Score.setValue(pose_Detector.detection_Class, value)
                                                appSettings.poseDetectorDetectionClass = value
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }

                            CustomLabel { text: "Class Names File (.txt)"; font.bold: true }
                            RowLayout {
                                Layout.fillWidth: true
                                CustomTextField {
                                    id: classNamesFilePathField
                                    Layout.fillWidth: true
                                    text: ""
                                    placeholderText: "Optional class names (empty = COCO-80)..."
                                    onTextChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.class_File) {
                                            try { Score.setValue(pose_Detector.class_File, text) } catch(e) { }
                                        }
                                        appSettings.poseDetectorClassNamesFile = text
                                    }
                                }
                                Button {
                                    text: "Browse"
                                    font.family: appStyle.fontFamily
                                    font.pixelSize: appStyle.fontSizeBody
                                    onClicked: Util.openFileDialog("Select Class Names File", "Text Files (*.txt);;All Files (*)", classNamesFilePathField.text, function(path) { if (path) classNamesFilePathField.text = path })
                                }
                                Button {
                                    text: "Clear"
                                    font.family: appStyle.fontFamily
                                    font.pixelSize: appStyle.fontSizeBody
                                    visible: classNamesFilePathField.text !== ""
                                    onClicked: classNamesFilePathField.text = ""
                                }
                            }
                        }

                        // --- Smoothing ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: appStyle.spacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CheckBox {
                                    id: smoothingSwitch
                                    text: "Smoothing"
                                    checked: true
                                    onCheckedChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.smoothing) {
                                            try {
                                                Score.setValue(pose_Detector.smoothing, checked)
                                                appSettings.poseDetectorSmoothing = checked
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appStyle.spacing
                                CustomLabel { text: "Smoothing: " + smoothingAmountSlider.value.toFixed(2); font.bold: true }
                                Slider {
                                    id: smoothingAmountSlider
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 80
                                    enabled: smoothingSwitch.checked
                                    from: 0.0; to: 1.0; value: 0.5; stepSize: 0.01
                                    onValueChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.smoothing_Amount) {
                                            try {
                                                Score.setValue(pose_Detector.smoothing_Amount, value)
                                                appSettings.poseDetectorSmoothingAmount = value
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }
                        }

                        // --- Network ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: appStyle.spacing

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
                        }
                    }
                }

            }
        }

        Item {
            id: previewPanel
            SplitView.preferredWidth: 480
            SplitView.minimumWidth: 320

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: appStyle.padding
                spacing: appStyle.spacing

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
                            process: isRunning ? "livepose preview" : ""
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

                    Button {
                        text: isPaused ? "Resume" : "Pause"
                        visible: isRunning
                        font.family: appStyle.fontFamily
                        font.pixelSize: appStyle.fontSizeBody
                        onClicked: {
                            if (isPaused) {
                                Score.resume()
                                isPaused = false
                            } else {
                                Score.pause()
                                isPaused = true
                            }
                        }
                    }

                    CustomLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: {
                            if (!currentProcess) return "Please select a model"
                            if (!modelFilePathField.hasValidPath) return "Please select an ONNX model file"
                            if (cameraSelector.currentIndex <= 0) return "Please select a camera"
                            if (isRunning) return (isPaused ? "Paused: " : "Running: ") + currentProcess.scenarioLabel
                            return "Ready: " + currentProcess.scenarioLabel
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
