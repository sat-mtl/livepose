import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import Score.UI as UI
import ca.qc.sat.qmlcomponents

Pane {
    id: runView
    background: Rectangle {
        color: Theme.backgroundColor
    }


    property var logger: mainWindow.logger

    // ---- Input backend state (generalised from the old camera-only path) ----
    // A single live device named "Input" occupies the alpha1 lane and is routed
    // to the current Video Mapper "in" port; the video file keeps the alpha2
    // lane. The InputSourceSelector widget is pure presentation — this view owns
    // every Score.* call (enumeration + device lifecycle + mixer).
    property var deviceEnumerator: null
    property string currentBackend: ""        // "Camera" | "Video file" | "NDI" | "Spout" | "Syphon"
    property bool deviceBackend: true          // false => the file lane (Video file)
    property string currentSourceName: ""
    property var sourceSnapshot: ({})          // source name -> enumerated DeviceSettings (sync backends)
    property var discoveredSources: []         // source names offered to the selector
    property string videoFilePath: ""
    property string inputStatusText: ""

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
    
    // alpha1 = live-device lane (Camera/NDI/Spout/Syphon), alpha2 = file lane.
    function setInputLane(live) {
        var liveAlpha = live ? 1.0 : 0.0
        var fileAlpha = live ? 0.0 : 1.0
        try {
            if (pose_video_Mixer.alpha1) Score.setValue(pose_video_Mixer.alpha1, liveAlpha)
            if (pose_video_Mixer.alpha2) Score.setValue(pose_video_Mixer.alpha2, fileAlpha)
            if (obj_video_Mixer.alpha1) Score.setValue(obj_video_Mixer.alpha1, liveAlpha)
            if (obj_video_Mixer.alpha2) Score.setValue(obj_video_Mixer.alpha2, fileAlpha)
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

    // Descriptor (uuid, kind, enumerate sync/async, typable) for a backend name.
    function backendDescriptor(name) {
        return inputSelector.descriptor(name)
    }

    function _clearEnumerator() {
        if (deviceEnumerator) {
            try { deviceEnumerator.deviceAdded.disconnect(onDeviceAdded) } catch(e) {}
            try { deviceEnumerator.deviceRemoved.disconnect(onDeviceRemoved) } catch(e) {}
            try { deviceEnumerator.enumerate = false } catch(e) {}
            deviceEnumerator = null
        }
    }

    function onDeviceAdded(factory, category, name, settings) {
        if (discoveredSources.indexOf(name) === -1) {
            var arr = discoveredSources.slice()
            arr.push(name)
            discoveredSources = arr
        }
    }

    function onDeviceRemoved(factory, name) {
        var idx = discoveredSources.indexOf(name)
        if (idx !== -1) {
            var arr = discoveredSources.slice()
            arr.splice(idx, 1)
            discoveredSources = arr
        }
    }

    // (Re)enumerate the sources for a device backend. Sync backends
    // (Camera/Syphon) snapshot the full DeviceSettings to recreate verbatim;
    // async backends (NDI/Spout) listen for deviceAdded/Removed (names only).
    function reenumerate(backend) {
        _clearEnumerator()
        discoveredSources = []
        sourceSnapshot = ({})
        inputStatusText = ""
        var desc = backendDescriptor(backend)
        if (!desc || desc.kind !== "device") return
        try {
            deviceEnumerator = Score.enumerateDevices(desc.uuid)
            if (desc.enumerate === "async") {
                deviceEnumerator.deviceAdded.connect(onDeviceAdded)
                deviceEnumerator.deviceRemoved.connect(onDeviceRemoved)
                deviceEnumerator.enumerate = true
                inputStatusText = qsTr("No %1 source found yet — type a source name if needed").arg(backend)
            } else {
                deviceEnumerator.enumerate = true
                var names = []
                var snap = ({})
                for (let dev of deviceEnumerator.devices) {
                    var label = (backend === "Camera") ? (dev.category + ": " + dev.name) : dev.name
                    names.push(label)
                    snap[label] = dev.settings
                }
                sourceSnapshot = snap
                discoveredSources = names
            }
        } catch (error) {
            inputStatusText = qsTr("%1 unavailable in this build").arg(backend)
            logger.log("Error enumerating " + backend + ": " + error)
        }
    }

    // Create/replace the single "Input" device for the current backend and route
    // it to the current Video Mapper "in" port. Assumes it runs inside a macro.
    function _createInputDeviceInMacro(name) {
        var desc = backendDescriptor(currentBackend)
        if (!desc || desc.kind !== "device") return
        var settings = (desc.enumerate === "sync") ? sourceSnapshot[name] : { "Path": name }
        if (desc.enumerate === "sync" && !settings) {
            logger.log("No enumerated settings for source: " + name)
            return
        }
        try {
            Score.removeDevice("Input")
            Score.createDevice("Input", desc.uuid, settings)
            if (currentProcess) {
                const inputPort = getVideoInPortViaMapper(currentProcess.videoMapperLabel)
                if (inputPort) Score.setAddress(inputPort, "Input:/")
            }
        } catch(e) {
            logger.log("Error creating input device: " + e)
        }
    }

    function recreateInputDevice(name) {
        if (name === "") return
        Score.startMacro()
        _createInputDeviceInMacro(name)
        Score.endMacro()
        setInputLane(true)
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
        if (deviceBackend && currentSourceName === "") {
            logger.log("Cannot start: No input source selected")
            showCameraError = true
            return false
        }
        if (!deviceBackend && videoFilePath === "") {
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
        if (deviceBackend && currentSourceName !== "") {
            _createInputDeviceInMacro(currentSourceName)
        }
        if (!deviceBackend && videoFilePath !== "") {
            setVideoPath(videoFilePath)
        }
        setInputLane(deviceBackend)

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
        var inputDesc = deviceBackend ? (currentBackend + ": " + currentSourceName) : videoFilePath
        logger.log("Started: " + currentProcess.scenarioLabel + "\nInput: " + inputDesc + "\nOSC: " + oscIpAddress.text + ":" + oscPort.text);
    }

    function stopCurrentProcess() {
        var modelName = currentProcess ? currentProcess.scenarioLabel : "unknown"
        Score.stop();
        Score.startMacro();
        try { Score.removeDevice("MyOSC"); } catch(e) {}
        try { Score.removeDevice("Input"); } catch(e) {}
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
        currentBackend = inputSelector.currentBackend
        deviceBackend = inputSelector.deviceBackend
        reenumerate(currentBackend)
        findAllScenarios();

        restoreSavedSettings();
    }

    function restoreSavedSettings() {

        modelPaths["pose_detector"] = appSettings.poseDetectorModelPath
        modelPaths["object_detector"] = appSettings.objectDetectorModelPath
        classesPaths["object_detector"] = appSettings.objectDetectorClassesPath

        oscIpAddress.text = appSettings.oscIpAddress
        oscPort.text = appSettings.oscPortValue
        if (appSettings.lastVideoPath !== "") {
            videoFilePath = appSettings.lastVideoPath
            inputSelector.videoFilePath = appSettings.lastVideoPath
        }
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

        // Restore the last input source for a sync device backend (Camera/Syphon):
        // if it is still present we reconnect the "Input" device, as the camera
        // path used to do on launch. Async backends discover sources later, so
        // they are reconnected when the user (re)selects them.
        if (appSettings.lastSourceName !== "" && deviceBackend &&
            discoveredSources.indexOf(appSettings.lastSourceName) !== -1) {
            currentSourceName = appSettings.lastSourceName
            inputSelector.currentSource = appSettings.lastSourceName
            recreateInputDevice(appSettings.lastSourceName)
        }
    }

    Component.onDestruction: {
        saveAllFieldsToScore()
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            x: Theme.padding
            width: parent.width - 2 * Theme.padding
            spacing: Theme.spacing * 0.75

            CustomLabel {
                text: "Model Configuration"
                font.bold: true
                font.pixelSize: Theme.fontSizeTitle
                Layout.topMargin: Theme.padding
            }

            CustomLabel {
                text: "Choose AI Model"
                font.bold: true
                font.pixelSize: Theme.fontSizeSubtitle
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
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: currentProcess !== null
                spacing: Theme.spacing

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
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
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
                    color: Theme.errorColor
                    font.pixelSize: Theme.fontSizeSmall
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
                    spacing: Theme.spacing
                    
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
                        Layout.leftMargin: Theme.spacing
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
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        onClicked: classesFileDialog.open()
                    }
                }
                
                CustomLabel {
                    visible: showClassesFileError && currentProcess && currentProcess.isObjectDetector
                    text: "Please select a classes file"
                    color: Theme.errorColor
                    font.pixelSize: Theme.fontSizeSmall
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
                color: Theme.separatorColor
            }

            // Shared multi-backend picker. It is pure presentation: this view
            // owns every Score.* call via the signal handlers below. The host
            // computes the protocol allow-list — LIVEPOSE_ADVANCED_IO reveals
            // the NDI/Spout/Syphon backends (platform-filtered by the widget).
            InputSourceSelector {
                id: inputSelector
                Layout.fillWidth: true
                allowedBackends: {
                    var adv = !!Util.environmentVariable("LIVEPOSE_ADVANCED_IO")
                    return adv ? ["Camera", "Video file", "NDI", "Spout", "Syphon"]
                               : ["Camera", "Video file"]
                }
                sources: runView.discoveredSources
                statusText: runView.inputStatusText

                onBackendSelected: name => {
                    runView.currentBackend = name
                    runView.deviceBackend = inputSelector.deviceBackend
                    runView.currentSourceName = ""
                    runView.showCameraError = false
                    appSettings.lastBackend = name
                    runView.setInputLane(inputSelector.deviceBackend)
                    if (inputSelector.deviceBackend)
                        runView.reenumerate(name)
                }
                onSourceSelected: name => {
                    runView.showCameraError = false
                    runView.currentSourceName = name
                    appSettings.lastSourceName = name
                    runView.recreateInputDevice(name)   // live swap, as the camera path did
                }
                onVideoFileSelected: path => {
                    runView.videoFilePath = path
                    appSettings.lastVideoPath = path
                    runView.setVideoPath(path)
                    runView.setInputLane(false)
                }
                onRefreshRequested: () => runView.reenumerate(runView.currentBackend)
            }

            CustomLabel {
                visible: showCameraError && deviceBackend
                text: "Please select an input source"
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
            }

            CustomLabel {
                visible: !deviceBackend && videoFilePath === ""
                text: "Please select a video file"
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.separatorColor
            }

            CustomLabel {
                text: "OSC Output Settings"
                font.bold: true
                font.pixelSize: Theme.fontSizeSubtitle
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing
                
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
                color: Theme.separatorColor
            }

            CustomLabel {
                text: "Video Preview"
                font.bold: true
                font.pixelSize: Theme.fontSizeSubtitle
            }

            Rectangle {
                id: videoPreviewFrame
                Layout.fillWidth: true
                Layout.preferredHeight: width / aspectRatio
                Layout.minimumWidth: 360
                Layout.minimumHeight: 200
                color: "transparent"
                radius: Theme.borderRadius
                border.color: Theme.borderColor
                border.width: 1
                
                readonly property real aspectRatio: 16 / 9
                Rectangle {
                    id: videoPreviewClip
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: Theme.borderRadius - 1
                    color: Theme.backgroundColorTertiary
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
                            } else if (deviceBackend && currentSourceName === "") {
                                return "Please select an input source"
                            } else if (!deviceBackend && videoFilePath === "") {
                                return "Please select a video file"
                            } else {
                                return "Ready to start: " + currentProcess.scenarioLabel
                            }
                        }
                        color: Theme.textColorSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        visible: !isRunning
                    }
                }
            }



            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: Theme.padding

                Button {
                    id: startStopButton
                    text: isRunning ? "Stop" : "Start"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
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
                        if (deviceBackend && currentSourceName === "") return "Please select an input source"
                        if (!deviceBackend && videoFilePath === "") return "Please select a video file"
                        if (isRunning) return "Running: " + currentProcess.scenarioLabel
                        return "Ready: " + currentProcess.scenarioLabel
                    }
                }
            }
        }
    }
}
