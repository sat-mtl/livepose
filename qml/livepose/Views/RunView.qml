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

    ScrollView {
        anchors.fill: parent
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
                        var filePath = new URL(selectedFile).pathname.substr(Qt.platform.os === "windows" ? 1 : 0);
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
                        onClicked: detectionModelFileDialog.open()
                    }

                    Button {
                        text: "Clear"
                        font.family: appStyle.fontFamily
                        font.pixelSize: appStyle.fontSizeBody
                        visible: detectionModelFilePathField.text !== ""
                        onClicked: detectionModelFilePathField.text = ""
                    }
                }

                FileDialog {
                    id: detectionModelFileDialog
                    title: "Select Detection Model (ONNX)"
                    nameFilters: ["ONNX Files (*.onnx)", "All Files (*)"]
                    onAccepted: {
                        if (!selectedFile) return
                        var filePath = new URL(selectedFile).pathname.substr(Qt.platform.os === "windows" ? 1 : 0);
                        if (filePath.startsWith("file://")) filePath = filePath.substring(7)
                        detectionModelFilePathField.text = filePath
                    }
                }
                                
                TabBar {
                    id: poseTabBar
                    Layout.fillWidth: true
                    visible: currentProcess && currentProcess.isPoseDetector
                    TabButton { text: "Output" }
                    TabButton { text: "Tracking" }
                    TabButton { text: "Re-ID" }
                    TabButton { text: "Detection" }
                    TabButton { text: "Smoothing" }
                }

                StackLayout {
                    Layout.fillWidth: true
                    visible: currentProcess && currentProcess.isPoseDetector
                    currentIndex: poseTabBar.currentIndex

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
                                onClicked: reidModelFileDialog.open()
                            }
                            Button {
                                text: "Clear"
                                font.family: appStyle.fontFamily
                                font.pixelSize: appStyle.fontSizeBody
                                visible: reidModelFilePathField.text !== ""
                                onClicked: reidModelFilePathField.text = ""
                            }
                        }
                        FileDialog {
                            id: reidModelFileDialog
                            title: "Select Re-ID Model (ONNX)"
                            nameFilters: ["ONNX Files (*.onnx)", "All Files (*)"]
                            onAccepted: {
                                if (!selectedFile) return
                                var filePath = new URL(selectedFile).pathname.substr(Qt.platform.os === "windows" ? 1 : 0);
                                if (filePath.startsWith("file://")) filePath = filePath.substring(7)
                                reidModelFilePathField.text = filePath
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
                                onClicked: classNamesFileDialog.open()
                            }
                            Button {
                                text: "Clear"
                                font.family: appStyle.fontFamily
                                font.pixelSize: appStyle.fontSizeBody
                                visible: classNamesFilePathField.text !== ""
                                onClicked: classNamesFilePathField.text = ""
                            }
                        }
                        FileDialog {
                            id: classNamesFileDialog
                            title: "Select Class Names File"
                            nameFilters: ["Text Files (*.txt)", "All Files (*)"]
                            onAccepted: {
                                if (!selectedFile) return
                                var filePath = new URL(selectedFile).pathname.substr(Qt.platform.os === "windows" ? 1 : 0);
                                if (filePath.startsWith("file://")) filePath = filePath.substring(7)
                                classNamesFilePathField.text = filePath
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
