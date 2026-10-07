import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtCore
import ca.qc.sat.qmlcomponents
import livepose

Pane {
    id: runView
    background: Rectangle {
        color: Theme.backgroundColor
    }


    property var logger: mainWindow.logger

    // InputSourceSelector is pure presentation, so this view owns the whole
    // Score side: enumeration, the "Input" device lifecycle and the routing.
    property var deviceEnumerator: null
    property string currentBackend: ""       // "Camera" | "Video file" | "NDI" | "Spout" | "Syphon"
    property bool deviceBackend: true        // false => the video-file lane
    property string currentSourceName: ""
    property var sourceLabels: ({})          // enumerator name -> source label
    property var discoveredSources: []       // source labels offered to the selector
    property string inputStatusText: ""
    property string pendingSourceRestore: "" // saved source not discovered yet
    // Muzzles the selector's change signals while restoreSavedSettings() writes to it.
    property bool restoringInput: false
    property var availableProcesses: []
    property var currentProcess: null

    property bool isStarting: false
    property bool isRunning: false
    property bool isPaused: false
    property bool oscReady: false
    property bool pendingRestart: false
    
    property bool showModelError: false
    property bool showInputError: false
    property bool showModelFileError: false
    property var modelPaths: ({})

    property string videoFilePath: ""

    // Pure (side-effect-free) readiness/status, consumed by PreviewPanel so the
    // RUN and PRESETS previews share one source of truth.
    readonly property bool inputReady:
        deviceBackend ? (currentSourceName !== "") : (videoFilePath !== "")
    readonly property bool modelReady: {
        if (!currentProcess) return false
        return modelFilePathField.hasValidPath
            || detectionModelFilePathField.text.indexOf(".onnx") >= 0
    }
    readonly property bool canStart: inputReady && modelReady
    readonly property string statusText: {
        if (!currentProcess) return "Please select a model"
        if (!modelReady) return "Please select a Landmark or Detection model"
        if (!inputReady) return deviceBackend
            ? "Please select an input source" : "Please select a video file"
        if (isRunning) return (isPaused ? "Paused: " : "Running: ") + currentProcess.scenarioLabel
        return "Ready: " + currentProcess.scenarioLabel
    }

    function togglePause() {
        if (isPaused) { Score.resume(); isPaused = false }
        else { Score.pause(); isPaused = true }
    }

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
        "BoxDetection",
        "InstantHMR"
    ]
    property var poseDetectorOutputModes: ["SkeletonOnImage", "SkeletonOnly"]
    // KeypointOutputFormat, in the detector's own order — the value sent is the
    // label, so the order only has to match for presets that store an index.
    // MeshTriangles / MeshVertices need a Body Model file and a model that
    // emits body parameters (InstantHMR); the rest work on any pose model.
    property var poseDetectorDataFormats: [
        "Raw", "XYArray", "XYZArray", "LineArray", "WorldXYZArray",
        "BoxXYWH", "BoxX1Y1X2Y2", "Flattened", "CameraXYZArray", "BodyParams",
        "MeshTriangles", "MeshVertices"
    ]
    property var poseDetectorMeshSpaces: ["OpenGL", "Camera"]
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
            if (pose_Detector.body_Model) Score.setValue(pose_Detector.body_Model, bodyModelFilePathField.text)
            if (pose_Detector.mesh_Keypoints) Score.setValue(pose_Detector.mesh_Keypoints, meshKeypointsSwitch.checked)
            if (pose_Detector.mesh_Space) Score.setValue(pose_Detector.mesh_Space, poseDetectorMeshSpaces[meshSpaceSelector.currentIndex])
            if (pose_Detector.draw_Mesh) Score.setValue(pose_Detector.draw_Mesh, drawMeshSwitch.checked)
        } catch(e) { }
    }
    
    function setVideoPath(path) {
        if (path === "") return
        try {
            if (video_in.process_object) video_in.process_object.path = path
        } catch(e) { }
    }

    // Resolve a preset model path against the pack it came from. Presets
    // reference models with the macro "<LIBRARY>:packages/<pack>/<sub>/<model>.onnx";
    // on disk that pack lives at packDir, so we drop the
    // "<LIBRARY>:packages/<pack>/" prefix and hang the rest off packDir. This is
    // pack-name agnostic, so any installed model pack resolves.
    function resolvePresetPath(p, packDir) {
        if (!p) return ""
        var marker = "<LIBRARY>:packages/"
        if (p.indexOf(marker) === 0) {
            var rest = p.substring(marker.length)      // "<pack>/<sub>/<model>.onnx"
            var slash = rest.indexOf("/")
            return packDir + "/" + (slash >= 0 ? rest.substring(slash + 1) : rest)
        }
        if (p.indexOf("<LIBRARY>:") === 0)
            return packDir + "/" + p.substring("<LIBRARY>:".length)
        return p
    }

    // Apply a preset (the .scp "Preset" array, read from the pack by PresetView)
    // by driving the existing UI widgets. Each widget's handler already pushes to
    // the score process and persists to appSettings, so this is the single source
    // of truth and works whether or not the pipeline is currently running.
    // Score.loadPreset would set the C++ ports but leave these fields stale, so we
    // do NOT use it. packDir is the on-disk pack the preset's models resolve against.
    function applyPreset(values, packDir) {
        if (!values) return

        // Flatten [[id, {Type: value}], ...] into id -> raw value.
        var v = ({})
        for (var i = 0; i < values.length; i++) {
            var id = values[i][0]
            var wrap = values[i][1]
            for (var k in wrap) { v[id] = wrap[k]; break }
        }
        function has(id) { return v[id] !== undefined }

        function setCombo(sel, model, val) {
            // Enum controls are stored either as an integer index (workflow,
            // motion gate, skeleton type) or as the string label (output mode,
            // data format, re-id preprocess). Handle both.
            var idx = (typeof val === "number") ? val : model.indexOf(val)
            if (idx >= 0 && idx < model.length) sel.currentIndex = idx
        }

        // Workflow first: it drives backendSelector, whose handler resets the
        // model path field — so the model paths below must be applied afterwards.
        if (has(2)) {
            var w = (typeof v[2] === "number") ? v[2] : poseDetectorWorkflows.indexOf(v[2])
            if (w >= 0 && w < poseDetectorWorkflows.length) backendSelector.currentIndex = w + 1
        }

        // Model file ports (rewrite <LIBRARY> -> models folder).
        if (has(1)) modelFilePathField.text = resolvePresetPath(String(v[1]), packDir)
        if (has(7)) detectionModelFilePathField.text = resolvePresetPath(String(v[7]), packDir)
        if (has(14)) reidModelFilePathField.text = resolvePresetPath(String(v[14]), packDir)
        if (has(26)) classNamesFilePathField.text = resolvePresetPath(String(v[26]), packDir)
        if (has(31)) bodyModelFilePathField.text = resolvePresetPath(String(v[31]), packDir)

        // Enum combo boxes.
        if (has(3)) setCombo(outputModeSelector, poseDetectorOutputModes, v[3])
        if (has(6)) setCombo(dataFormatSelector, poseDetectorDataFormats, v[6])
        if (has(17)) setCombo(reidPreprocessSelector, poseDetectorReidPreprocess, v[17])
        if (has(21)) setCombo(motionGateSelector, poseDetectorMotionGates, v[21])
        if (has(25)) setCombo(skeletonTypeSelector, poseDetectorSkeletonTypes, v[25])
        if (has(33)) setCombo(meshSpaceSelector, poseDetectorMeshSpaces, v[33])

        // Float sliders.
        if (has(4)) minConfidenceSlider.value = v[4]
        if (has(10)) smoothingAmountSlider.value = v[10]
        if (has(16)) reidWeightSlider.value = v[16]
        if (has(22)) maxSpeedSlider.value = v[22]
        if (has(29)) reidMarginSlider.value = v[29]

        // Int spin boxes.
        if (has(12)) maxInstancesSpinBox.value = v[12]
        if (has(13)) detectorCadenceSpinBox.value = v[13]
        if (has(19)) detectionClassSpinBox.value = v[19]
        if (has(27)) trackMemorySpinBox.value = v[27]
        if (has(28)) reidMemorySpinBox.value = v[28]
        if (has(30)) holdFramesSpinBox.value = v[30]

        // Bool check boxes.
        if (has(5)) drawSkeletonSwitch.checked = v[5]
        if (has(8)) trackROISwitch.checked = v[8]
        if (has(9)) smoothingSwitch.checked = v[9]
        if (has(11)) trackIDsSwitch.checked = v[11]
        if (has(15)) reidSwitch.checked = v[15]
        if (has(18)) drawBoxesSwitch.checked = v[18]
        if (has(20)) drawLandmarksSwitch.checked = v[20]
        if (has(23)) birthGateSwitch.checked = v[23]
        if (has(24)) strictConfirmSwitch.checked = v[24]
        if (has(32)) meshKeypointsSwitch.checked = v[32]
        if (has(34)) drawMeshSwitch.checked = v[34]

        // If a pipeline is already running, restart it so the new models load
        // and the live preview reflects the preset immediately. (A workflow
        // change above already triggers one restart; this covers model-only
        // changes, and restartIfRunning is a no-op once stopped, so we restart
        // exactly once.)
        if (isRunning) restartIfRunning()
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
            property var body_Model : Score.inlet(process_object, 31);
            property var mesh_Keypoints : Score.inlet(process_object, 32);
            property var mesh_Space : Score.inlet(process_object, 33);
            property var draw_Mesh : Score.inlet(process_object, 34);
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

    function backendDescriptor(name) {
        return inputSelector.descriptor(name)
    }

    function _clearEnumerator() {
        discoveryTimeout.stop()
        if (deviceEnumerator) {
            try { deviceEnumerator.deviceAdded.disconnect(onDeviceAdded) } catch(e) {}
            try { deviceEnumerator.deviceRemoved.disconnect(onDeviceRemoved) } catch(e) {}
            try { deviceEnumerator.enumerate = false } catch(e) {}
            deviceEnumerator = null
        }
    }

    // A camera enumerates one category per device and one name per mode, so the
    // label needs both to stay unique; deviceRemoved only carries the name.
    function _sourceLabel(category, name) {
        return (currentBackend === "Camera") ? (category + ": " + name) : name
    }

    function onDeviceAdded(factory, category, name) {
        discoveryTimeout.stop()
        var label = _sourceLabel(category, name)
        if (discoveredSources.indexOf(label) !== -1)
            return
        sourceLabels[name] = label
        var arr = discoveredSources.slice()
        arr.push(label)
        discoveredSources = arr
        if (currentSourceName === "")
            inputStatusText = ""

        if (pendingSourceRestore === label && currentSourceName === "") {
            pendingSourceRestore = ""
            // Deferred: restarting from inside the callback re-enters the
            // device list while score is still walking it.
            Qt.callLater(function() { selectSource(label) })
        }
    }

    function onDeviceRemoved(factory, name) {
        var label = sourceLabels[name] || name
        delete sourceLabels[name]
        var idx = discoveredSources.indexOf(label)
        if (idx !== -1) {
            var arr = discoveredSources.slice()
            arr.splice(idx, 1)
            discoveredSources = arr
        }
    }

    // Discovery is always signal-driven, whatever the descriptor's `enumerate`
    // says -- that field only picks the settings shape below.
    function reenumerate(backend) {
        _clearEnumerator()
        discoveredSources = []
        sourceLabels = ({})
        inputStatusText = currentSourceName !== ""
            ? qsTr("Active source: %1").arg(currentSourceName) : ""
        var desc = backendDescriptor(backend)
        if (!desc || desc.kind !== "device") return
        try {
            deviceEnumerator = Score.enumerateDevices(desc.uuid)
            deviceEnumerator.deviceAdded.connect(onDeviceAdded)
            deviceEnumerator.deviceRemoved.connect(onDeviceRemoved)
            deviceEnumerator.enumerate = true
            if (discoveredSources.length === 0 && currentSourceName === "") {
                inputStatusText = desc.typable
                    ? qsTr("No %1 source found yet — type a source name if needed").arg(backend)
                    : qsTr("Looking for %1 sources…").arg(backend)
                // NDI and Syphon load their runtime from the host, and score does
                // not ship it. When it is absent the enumerator is created
                // normally and simply never reports anything, so the catch below
                // cannot fire and the user waits forever on a message that blames
                // the network. Say both causes once the wait is long enough to
                // mean something.
                discoveryTimeout.backendName = backend
                discoveryTimeout.restart()
            }
        } catch (error) {
            inputStatusText = qsTr("%1 unavailable in this build").arg(backend)
            logger.log("Error enumerating " + backend + ": " + error)
        }
    }

    Timer {
        id: discoveryTimeout
        interval: 12000
        property string backendName: ""
        onTriggered: {
            if (runView.discoveredSources.length > 0 || runView.currentSourceName !== "")
                return
            if (runView.currentBackend !== backendName)
                return
            runView.inputStatusText = qsTr(
                "No %1 source after 12 s. Either nothing is sending, or this machine "
                + "has no %1 runtime installed — it is not bundled with the app.")
                .arg(backendName)
            runView.logger.log("No " + backendName + " source discovered after 12 s. "
                + "If a sender is running, check that the " + backendName
                + " runtime is installed on this machine; it ships separately.")
        }
    }

    function selectSource(name) {
        currentSourceName = name
        inputSelector.currentSource = name
        showInputError = false
        appSettings.lastSourceName = name
        // The selector's source combo does not follow currentSource when it is
        // set programmatically, so name the wired source here.
        inputStatusText = qsTr("Active source: %1").arg(name)
        // An in-place device swap leaves the running gfx graph bound to the
        // destroyed node (black preview), so rebuild the pipeline instead.
        restartIfRunning()
    }

    // Read off the enumerator's device list rather than caching the deviceAdded
    // payload: the list is authoritative and survives a Refresh.
    function _enumeratedSettings(label) {
        if (!deviceEnumerator) return null
        var devs = deviceEnumerator.devices
        for (var i = 0; i < devs.length; i++) {
            if (_sourceLabel(devs[i].category, devs[i].name) === label)
                return devs[i].settings
        }
        return null
    }

    // Assumes it runs inside a macro.
    function _createInputDeviceInMacro(inPort) {
        var desc = backendDescriptor(currentBackend)
        if (!desc || desc.kind !== "device") return
        var settings = (desc.enumerate === "sync")
            ? _enumeratedSettings(currentSourceName) : { "Path": currentSourceName }
        if (!settings) {
            logger.log("No enumerated settings for source: " + currentSourceName)
            return
        }
        try {
            Score.removeDevice("Input")
            // Qt 6.12 dropped QML's QJSValue argument case, so createDevice rejects
            // the enumerated DeviceSettings (Camera); catching keeps the macro balanced.
            Score.createDevice("Input", desc.uuid, settings)
            if (inPort) Score.setAddress(inPort, "Input:/")
        } catch(e) {
            logger.log("Error creating input device: " + e)
        }
    }

    function validateBeforeStart() {
        showModelError = false
        showInputError = false
        showModelFileError = false

        if (!currentProcess) {
            logger.log("Cannot start: No AI model selected")
            showModelError = true
            return false
        }
        // A Landmark model drives single/two-stage pose; a Detection model alone
        // drives box detection. Either one is enough — Auto picks the pipeline,
        // and several box presets ship with only a Detection model set.
        var hasLandmark = modelFilePathField.hasValidPath
        var hasDetection = detectionModelFilePathField.text.indexOf(".onnx") >= 0
        if (!hasLandmark && !hasDetection) {
            logger.log("Cannot start: select a Landmark or Detection model (.onnx)")
            showModelFileError = true
            return false
        }
        if (deviceBackend && currentSourceName === "") {
            logger.log("Cannot start: No input source selected")
            showInputError = true
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
        if (deviceBackend && currentSourceName !== "") {
            _createInputDeviceInMacro(inPort)
        } else if (!deviceBackend && videoFilePath !== "") {
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

        // Outlet 2 "Geometry" is the primary detection, in the current Data
        // Format. It keeps /skeleton in every mode, so a receiver written
        // against the single-pose output is unaffected by any of this.
        //
        // With Track IDs on the detector also fills outlet 4 "Poses Geometry"
        // — one slot per tracked instance, same Data Format, fixed stride,
        // zero-padded to Max Instances — and outlet 5 "Count", the number of
        // live slots. Those become /skeletons and /count: the stride is
        // len(/skeletons) / Max Instances and only the first /count slots are
        // live, so the pair is what a multi-person receiver needs to slice the
        // buffer. Both are bound unconditionally rather than only when
        // tracking is on, because the binding is fixed at pipeline start:
        // gating it would force a restart (and a video/model reload) on every
        // toggle of the switch. With tracking off the detector leaves both
        // outlets empty, so they still tick once per detected frame carrying
        // an empty list and 0 — unambiguous for a receiver, and two small
        // datagrams next to the keypoint payload on the same frame.
        try { Score.createAddress("MyOSC:/skeleton", "List") } catch(e) {}
        try { Score.createAddress("MyOSC:/skeletons", "List") } catch(e) {}
        try { Score.createAddress("MyOSC:/count", "Int") } catch(e) {}
        var dataOut = Score.outlet(proc, 2)
        if (dataOut) Score.setAddress(dataOut, "MyOSC:/skeleton")
        var posesOut = Score.outlet(proc, 4)
        if (posesOut) Score.setAddress(posesOut, "MyOSC:/skeletons")
        var countOut = Score.outlet(proc, 5)
        if (countOut) Score.setAddress(countOut, "MyOSC:/count")
        oscReady = true;

        Score.endMacro();
        Score.play();
        isRunning = true;
        isPaused = false;
        isStarting = false;
        var inputDesc = deviceBackend ? (currentBackend + ": " + currentSourceName) : videoFilePath
        var oscDesc = trackIDsSwitch.checked
            ? "/skeleton, /skeletons (" + maxInstancesSpinBox.value + " slots, "
              + (poseDetectorDataFormats[dataFormatSelector.currentIndex] === "Flattened"
                 ? "track id first in each" : "no track id — use Flattened for that")
              + "), /count"
            : "/skeleton"
        logger.log("Started: " + currentProcess.scenarioLabel + "\nInput: " + inputDesc
                   + "\nOSC: " + host + ":" + outPort + " -> " + oscDesc);
    }

    function stopCurrentProcess() {
        var modelName = currentProcess ? currentProcess.scenarioLabel : "unknown"
        Score.stop();
        Score.startMacro();
        try { Score.removeDevice("MyOSC"); } catch(e) {}
        try { Score.removeDevice("Input"); } catch(e) {}
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
        buildBackends();

        restoreSavedSettings();
    }

    function restoreSavedSettings() {

        modelPaths["pose_detector"] = appSettings.poseDetectorModelPath

        oscIpAddress.text = appSettings.oscIpAddress
        oscPort.text = appSettings.oscPortValue
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
        bodyModelFilePathField.text = appSettings.poseDetectorBodyModelPath
        drawMeshSwitch.checked = appSettings.poseDetectorDrawMesh === true // default to false
        meshKeypointsSwitch.checked = appSettings.poseDetectorMeshKeypoints === true // default to false
        if (appSettings.poseDetectorMeshSpace >= 0 && appSettings.poseDetectorMeshSpace < poseDetectorMeshSpaces.length) {
            meshSpaceSelector.currentIndex = appSettings.poseDetectorMeshSpace
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

        restoreInputSettings()
    }

    // The selector re-emits backendSelected/videoFileSelected on our own writes,
    // hence the restoringInput guard.
    function restoreInputSettings() {
        restoringInput = true
        if (appSettings.lastBackend !== "" && inputSelector.backends.indexOf(appSettings.lastBackend) !== -1)
            inputSelector.currentBackend = appSettings.lastBackend
        if (videoFilePath !== "")
            inputSelector.videoFilePath = videoFilePath
        restoringInput = false

        currentBackend = inputSelector.currentBackend
        deviceBackend = inputSelector.deviceBackend
        if (!deviceBackend)
            return

        reenumerate(currentBackend)
        // Inline backends already reported theirs; the rest arrive later.
        if (appSettings.lastSourceName !== "") {
            if (discoveredSources.indexOf(appSettings.lastSourceName) !== -1)
                selectSource(appSettings.lastSourceName)
            else
                pendingSourceRestore = appSettings.lastSourceName
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
            color: SplitHandle.pressed ? Theme.primaryColor
                 : SplitHandle.hovered ? Theme.borderColor : Theme.separatorColor
        }

        ScrollView {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 380
            contentWidth: availableWidth

            ColumnLayout {
                x: Theme.padding
                width: parent.width - 2 * Theme.padding
                spacing: Theme.spacing * 0.75

                // LIVEPOSE_ADVANCED_IO reveals the NDI/Spout/Syphon backends;
                // the widget then drops the ones invalid on this platform.
                InputSourceSelector {
                    id: inputSelector
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.padding
                    allowedBackends: {
                        var adv = !!Util.environmentVariable("LIVEPOSE_ADVANCED_IO")
                        return adv ? ["Camera", "Video file", "NDI", "Spout", "Syphon"]
                                   : ["Camera", "Video file"]
                    }
                    sources: runView.discoveredSources
                    statusText: runView.inputStatusText

                    onBackendSelected: name => {
                        if (runView.restoringInput || name === runView.currentBackend)
                            return
                        runView.currentBackend = name
                        runView.deviceBackend = inputSelector.deviceBackend
                        runView.currentSourceName = ""
                        runView.showInputError = false
                        appSettings.lastBackend = name
                        if (inputSelector.deviceBackend)
                            runView.reenumerate(name)
                        else
                            runView._clearEnumerator()
                        runView.restartIfRunning()
                    }
                    onSourceSelected: name => {
                        if (runView.restoringInput) return
                        runView.selectSource(name)
                    }
                    onVideoFileSelected: path => {
                        if (runView.restoringInput) return
                        runView.videoFilePath = path
                        appSettings.lastVideoPath = path
                        runView.setVideoPath(path)
                    }
                    onRefreshRequested: () => runView.reenumerate(runView.currentBackend)
                }

                CustomLabel {
                    visible: showInputError && deviceBackend
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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing

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
                            spacing: Theme.spacing

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
                                color: Theme.errorColor
                                font.pixelSize: Theme.fontSizeSmall
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
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    onClicked: Util.openFileDialog("Select ONNX Model File", "ONNX Files (*.onnx);;All Files (*)", modelFilePathField.text, function(path) { if (path) modelFilePathField.text = path })
                                }
                            }


                            CustomLabel {
                                visible: showModelFileError
                                text: "Please select an ONNX model file"
                                color: Theme.errorColor
                                font.pixelSize: Theme.fontSizeSmall
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
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    onClicked: Util.openFileDialog("Select Detection Model (ONNX)", "ONNX Files (*.onnx);;All Files (*)", detectionModelFilePathField.text, function(path) { if (path) detectionModelFilePathField.text = path })
                                }

                                Button {
                                    text: "Clear"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    visible: detectionModelFilePathField.text !== ""
                                    onClicked: detectionModelFilePathField.text = ""
                                }
                            }
                        }

                        // --- Output ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing

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

                            // A body mesh does not fit in a UDP datagram and the
                            // message is then dropped with no error anywhere, so the
                            // outlet simply goes quiet. Measured on mhr-lod5: Mesh
                            // Vertices (2913 floats) arrives, Mesh Triangles does not;
                            // on mhr-lod3 neither does. Body Params carries the same
                            // person in 252 floats, for a receiver that evaluates the
                            // mesh itself.
                            CustomLabel {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                visible: poseDetectorDataFormats[dataFormatSelector.currentIndex] === "MeshTriangles"
                                      || poseDetectorDataFormats[dataFormatSelector.currentIndex] === "MeshVertices"
                                color: Theme.errorColor
                                font.pixelSize: Theme.fontSizeSmall
                                text: "A body mesh is usually too large for one OSC packet and is then "
                                    + "dropped silently. Use Body Params (252 floats per person) to send "
                                    + "the mesh over the network, or keep a mesh format only for the preview."
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

                            // Only the mesh Data Formats and the mesh drawing read this.
                            CustomLabel { text: "Mesh Space"; font.bold: true }
                            CustomComboBox {
                                id: meshSpaceSelector
                                Layout.fillWidth: true
                                model: poseDetectorMeshSpaces
                                currentIndex: 0
                                onCurrentIndexChanged: {
                                    if (currentProcess && currentProcess.isPoseDetector && pose_Detector.mesh_Space) {
                                        try {
                                            Score.setValue(pose_Detector.mesh_Space, poseDetectorMeshSpaces[currentIndex])
                                            appSettings.poseDetectorMeshSpace = currentIndex
                                        } catch(e) { }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacing
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
                                    Layout.leftMargin: Theme.spacing
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
                                    Layout.leftMargin: Theme.spacing
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

                            // --- Body mesh (InstantHMR + a Body Model file) ---
                            CustomLabel { text: "Body Model (.mhrbin)"; font.bold: true }
                            RowLayout {
                                Layout.fillWidth: true
                                CustomTextField {
                                    id: bodyModelFilePathField
                                    Layout.fillWidth: true
                                    text: ""
                                    placeholderText: "Optional body mesh model (empty = no mesh)..."
                                    onTextChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.body_Model) {
                                            try { Score.setValue(pose_Detector.body_Model, text) } catch(e) { }
                                        }
                                        appSettings.poseDetectorBodyModelPath = text
                                    }
                                }
                                Button {
                                    text: "Browse"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    onClicked: Util.openFileDialog("Select Body Model (MHR)", "MHR Body Models (*.mhrbin);;All Files (*)", bodyModelFilePathField.text, function(path) { if (path) bodyModelFilePathField.text = path })
                                }
                                Button {
                                    text: "Clear"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    visible: bodyModelFilePathField.text !== ""
                                    onClicked: bodyModelFilePathField.text = ""
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacing
                                CheckBox {
                                    id: drawMeshSwitch
                                    text: "Draw Mesh"
                                    checked: false
                                    enabled: bodyModelFilePathField.text !== ""
                                    onCheckedChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.draw_Mesh) {
                                            try {
                                                Score.setValue(pose_Detector.draw_Mesh, checked)
                                                appSettings.poseDetectorDrawMesh = checked
                                            } catch(e) { }
                                        }
                                    }
                                }
                                CheckBox {
                                    id: meshKeypointsSwitch
                                    text: "Mesh Keypoints"
                                    checked: false
                                    enabled: bodyModelFilePathField.text !== ""
                                    Layout.leftMargin: Theme.spacing
                                    onCheckedChanged: {
                                        if (currentProcess && currentProcess.isPoseDetector && pose_Detector.mesh_Keypoints) {
                                            try {
                                                Score.setValue(pose_Detector.mesh_Keypoints, checked)
                                                appSettings.poseDetectorMeshKeypoints = checked
                                            } catch(e) { }
                                        }
                                    }
                                }
                            }
                        }

                        // --- Tracking ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacing
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
                                spacing: Theme.spacing
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
                                    Layout.leftMargin: Theme.spacing
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
                                spacing: Theme.spacing
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
                                spacing: Theme.spacing
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
                                spacing: Theme.spacing
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
                                spacing: Theme.spacing
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
                                spacing: Theme.spacing
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
                                spacing: Theme.spacing
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
                                    Layout.leftMargin: Theme.spacing
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
                            spacing: Theme.spacing

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
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    onClicked: Util.openFileDialog("Select Re-ID Model (ONNX)", "ONNX Files (*.onnx);;All Files (*)", reidModelFilePathField.text, function(path) { if (path) reidModelFilePathField.text = path })
                                }
                                Button {
                                    text: "Clear"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    visible: reidModelFilePathField.text !== ""
                                    onClicked: reidModelFilePathField.text = ""
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacing
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
                                spacing: Theme.spacing
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
                                spacing: Theme.spacing
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
                                spacing: Theme.spacing
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
                            spacing: Theme.spacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacing
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
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    onClicked: Util.openFileDialog("Select Class Names File", "Text Files (*.txt);;All Files (*)", classNamesFilePathField.text, function(path) { if (path) classNamesFilePathField.text = path })
                                }
                                Button {
                                    text: "Clear"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    visible: classNamesFilePathField.text !== ""
                                    onClicked: classNamesFilePathField.text = ""
                                }
                            }
                        }

                        // --- Smoothing ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacing
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
                                spacing: Theme.spacing
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
                            spacing: Theme.spacing

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

                            CustomLabel {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                opacity: 0.75
                                font.pixelSize: Theme.fontSizeSmall
                                // A slot is NOT a person. The detector rebuilds its
                                // instance list in detector-score order every frame and
                                // the tracker labels it in place without reordering, so
                                // slot i is "the i-th best detection of this frame".
                                // Measured on a crowd clip: a slot keeps the same track id
                                // into the next frame only 20% of the time.
                                text: trackIDsSwitch.checked
                                    ? "/skeleton — the strongest detection.\n"
                                      + "/skeletons — " + maxInstancesSpinBox.value
                                      + " equal-sized slots holding this frame's detections, "
                                      + "strongest first. A slot is a position in that list, "
                                      + "not a person: who sits in slot 2 changes frame to frame.\n"
                                      + "/count — how many detections this frame."
                                    : "/skeleton — the detected person.\n"
                                      + "Turn Track IDs on to also get /skeletons and /count, "
                                      + "one slot per detection."
                            }

                            // Only Flattened puts the track id on the wire (first float of
                            // each slot, then the class, the box, then the keypoints), so
                            // it is the only way a receiver can follow one person over time.
                            CustomLabel {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                visible: trackIDsSwitch.checked
                                      && poseDetectorDataFormats[dataFormatSelector.currentIndex] !== "Flattened"
                                color: Theme.errorColor
                                font.pixelSize: Theme.fontSizeSmall
                                text: "To follow a person across frames, set Data Format to "
                                    + "Flattened: it is the only layout that sends the track id "
                                    + "(each slot starts with id, class, then the bounding box). "
                                    + "In every other layout the slots carry no identity."
                            }

                            // A large /skeletons packet survives localhost (64 kB MTU)
                            // but not a real link, where every IP fragment has to arrive.
                            // Measured mac -> linux over Ethernet, 133-keypoint skeletons:
                            // 2 slots (532 floats) delivered 1262/1262, 8 slots (2128)
                            // delivered 5/590. Only warn once it is actually large and
                            // actually going off-box.
                            CustomLabel {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                visible: trackIDsSwitch.checked
                                      && maxInstancesSpinBox.value >= 4
                                      && oscIpAddress.text.trim() !== "127.0.0.1"
                                      && oscIpAddress.text.trim() !== "localhost"
                                color: Theme.errorColor
                                font.pixelSize: Theme.fontSizeSmall
                                text: "Over a network, a /skeletons packet this large may be "
                                    + "dropped whole: it is split across IP fragments and all of "
                                    + "them have to arrive. If people go missing, lower Max "
                                    + "Instances or pick a smaller skeleton."
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

            PreviewPanel {
                anchors.fill: parent
                anchors.margins: Theme.padding
                target: runView
                // Owns the preview on every view except PRESETS (which has its
                // own); this keeps inference/OSC alive on the RUN and LOGS views.
                active: mainWindow.currentViewIndex !== mainWindow.presetsViewIndex
            }
        }
    }
}
