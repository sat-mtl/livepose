import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Score.UI as UI
import livepose

Pane {
    id: runView

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
        
        var modelMap = {
            "blazepose": blaze_Pose.model,
            "yolov8_pose": yOLO_Pose.model,
            "resnet": resnet_detector.model
        }
        
        var modelPort = modelMap[currentProcess.scenarioLabel]
        if (modelPort) {
            Score.setValue(modelPort, filePath)
        }
    }

    function saveAllFieldsToScore() {
        updateModelPath()
        
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

    // get the video in port via the video mapper
    function getVideoInPortViaMapper(videoMapperLabel) {
         if (!videoMapperLabel) return null;
         var videoMapper = Score.find(videoMapperLabel);
         if (!videoMapper) return null 
         return Score.port(videoMapper, "in");
     }

    function findAllScenarios() {
        logger.log("Finding AI Model Scenarios")
        availableProcesses = []
        var label = ["blazepose", "yolov8_pose", "resnet"]
    
        var triggerMap = {
            "blazepose":    "blazeposetrigger",
            "yolov8_pose":  "yolov8_posetrigger",  
            "resnet":       "resnettrigger"
        }
        
        var videoMapperMap = {
            "blazepose":   "blazepose Video Mapper",
            "yolov8_pose": "yolov8_pose Video Mapper",
            "resnet":      "resnet Video Mapper"
        }

        for (var i = 0; i < label.length; i++) {
            var id   = label[i]
            var videoMapperId = videoMapperMap[id]
            var proc = Score.find(videoMapperId)
            if (proc) {
                availableProcesses.push({
                    scenarioLabel: id,
                    videoMapperLabel: videoMapperId, 
                    process:     proc,
                    triggerName: triggerMap[id]
                })
            }
        }
    
        var modelList = [" "]
        for (var j = 0; j < availableProcesses.length; j++) {
            modelList.push(availableProcesses[j].scenarioLabel)
        }

        if (availableProcesses.length > 0) {
            backendSelector.model = modelList
            backendSelector.currentIndex = 1
            currentProcess = availableProcesses[0]
            logger.log("Auto-selected model: " + availableProcesses[0].scenarioLabel)
        } else {
            backendSelector.model = [" "]
            logger.log("No scenarios found")
        }
    }

    function enumerateCameras() {
        logger.log("Enumerating cameras...")
        console.log("Starting camera enumeration...")

        try {
            deviceEnumerator = Score.enumerateDevices(
                        "d615690b-f2e2-447b-b70e-a800552db69c")
            console.log("Score.enumerateDevices returned:", deviceEnumerator)

            deviceEnumerator.enumerate = true
            console.log("Set enumerate to true")

            cameraList = []
            cameraPrettyNamesList = []
            console.log("Devices array:", deviceEnumerator.devices)

            for (let dev of deviceEnumerator.devices) {
                console.log("Found device:", dev)
                console.log("Device protocol:", dev.protocol)
                console.log("Device name:", dev.name)
                logger.log("Found camera: " + dev.name)

                cameraList.push(dev)
                cameraPrettyNamesList.push(dev.category + ": " + dev.name)
            }

            console.log("Final camera list:", cameraPrettyNamesList)

            cameraSelector.model = [" ", ...cameraPrettyNamesList]
        } catch (error) {
            console.error("Error during camera enumeration:", error)
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
        if (!validateBeforeStart()) {
            return
        }
        if (isStarting) return
        isStarting = true;
        saveAllFieldsToScore()
        const scenario = currentProcess.process
        const scenarioName = currentProcess.scenarioLabel
        
        logger.log(`Starting ${scenarioName} scenario`)
        const cameraName = cameraPrettyNamesList[cameraSelector.currentIndex - 1]
        logger.log("Using camera: " + cameraName)

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

        Score.endMacro()
        Score.play()
        const trigger = Score.find(currentProcess.triggerName)
        if (trigger && typeof trigger.triggeredByGui === 'function')
            trigger.triggeredByGui();
        isRunning = true
        isStarting = false
        logger.log("Scenario started successfully")
    }

    function stopCurrentProcess() {
        Score.stop();
        Score.startMacro();
        try { Score.removeDevice("MyOSC"); } catch(e) {}
        try { Score.removeDevice("Camera"); } catch(e) {}
        Score.endMacro();
        isRunning = false;
        isStarting = false;
        oscReady = false;
        logger.log("Scenario stopped")
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
            spacing: AppStyle.spacing * 0.75
            anchors.margins: AppStyle.padding

            Label {
                text: "Model Configuration"
                font.bold: true
                font.pixelSize: AppStyle.fontSizeTitle
                color: AppStyle.textColor
                Layout.topMargin: AppStyle.padding
                Layout.leftMargin: AppStyle.padding
                Layout.rightMargin: AppStyle.padding
            }

            // --- Model Selection ---
            Label {
                text: "Choose AI Model"
                font.bold: true
                font.pixelSize: AppStyle.fontSizeSubtitle
                color: AppStyle.textColor
                Layout.leftMargin: AppStyle.padding
                Layout.rightMargin: AppStyle.padding
            }

            ComboBox {
                id: backendSelector
                Layout.fillWidth: true
                Layout.leftMargin: AppStyle.padding
                Layout.rightMargin: AppStyle.padding
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
            Label {
                visible: showModelError
                text: "Please select a model"
                color: "#FF6B6B"
                font.pixelSize: AppStyle.fontSizeSmall
                Layout.leftMargin: AppStyle.padding
                Layout.rightMargin: AppStyle.padding
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: AppStyle.padding * 2
                Layout.rightMargin: AppStyle.padding
                visible: currentProcess !== null
                spacing: AppStyle.spacing

                Label {
                    text: "ONNX Model File"
                    font.bold: true
                    font.pixelSize: AppStyle.fontSizeBody
                    color: AppStyle.textColor
                }

                RowLayout {
                    Layout.fillWidth: true
                    
                    TextField { 
                        id: modelFilePathField
                        Layout.fillWidth: true;
                        font.pixelSize: AppStyle.fontSizeBody
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
                        font.pixelSize: AppStyle.fontSizeBody
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

                Label {
                    visible: showModelFileError
                    text: "Please select an ONNX model file"
                    color: "#FF6B6B"
                    font.pixelSize: AppStyle.fontSizeSmall
                }

                Label {
                    text: "Classes File (.txt)"
                    font.bold: true
                    font.pixelSize: AppStyle.fontSizeBody
                    color: AppStyle.textColor
                    visible: currentProcess && currentProcess.scenarioLabel === "resnet" // only visible for resnet
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: currentProcess && currentProcess.scenarioLabel === "resnet"
                    
                    TextField {
                        id: classesFilePathField
                        Layout.fillWidth: true
                        font.pixelSize: AppStyle.fontSizeBody
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
                        font.pixelSize: AppStyle.fontSizeBody
                        onClicked: classesFileDialog.open()
                    }
                }
                
                Label {
                    visible: showClassesFileError && currentProcess && currentProcess.scenarioLabel === "resnet"
                    text: "Please select a classes file"
                    color: "#FF6B6B"
                    font.pixelSize: AppStyle.fontSizeSmall
                }
                
                FileDialog {
                    id: classesFileDialog
                    title: "Select Classes File"
                    nameFilters: ["Text Files (*.txt)", "All Files (*)"]
                    onAccepted: {
                        var filePath = classesFileDialog.selectedFile.toString()
                        if (filePath.startsWith("file://")) {
                            filePath = filePath.substring(7)
                        }
                        classesFilePathField.text = filePath
                    }
                }
            }

            // --- Camera Input ---
            Label {
                text: "Select Camera"
                font.bold: true
                font.pixelSize: AppStyle.fontSizeSubtitle
                color: AppStyle.textColor
                Layout.leftMargin: AppStyle.padding
                Layout.rightMargin: AppStyle.padding
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
                Layout.leftMargin: AppStyle.padding
                Layout.rightMargin: AppStyle.padding
                model: [" ", ...cameraPrettyNamesList]
                
                onCurrentIndexChanged: {
                    showCameraError = false  // Clear error when selection changes
                    if (currentIndex <= 0) 
                        return;
                    Score.startMacro()
                    
                    const camera_name = cameraPrettyNamesList[currentIndex - 1]
                    const camera_settings = cameraList[currentIndex - 1].settings
                    logger.log("Selected camera: " + camera_name)
                    
                    Score.removeDevice("Camera")

                    Score.createDevice(
                        "Camera",
                        "d615690b-f2e2-447b-b70e-a800552db69c",
                        camera_settings)
                    
                    if (currentProcess) {
                        const inputPort = getVideoInPortViaMapper(currentProcess.videoMapperLabel)
                        if (inputPort) {
                            Score.setAddress(inputPort, "Camera:/")
                        }
                    }
                    Score.endMacro()
                }
            }
            
            // Validation feedback for camera
            Label {
                visible: showCameraError
                text: "Please select a camera"
                color: "#FF6B6B"
                font.pixelSize: AppStyle.fontSizeSmall
                Layout.leftMargin: AppStyle.padding
                Layout.rightMargin: AppStyle.padding
            }

            // --- Output ---
            Label {
                text: "OSC Output Settings"
                font.bold: true
                font.pixelSize: AppStyle.fontSizeSubtitle
                color: AppStyle.textColor
                Layout.leftMargin: AppStyle.padding
                Layout.rightMargin: AppStyle.padding
            }

            TextField {
                id: oscIpAddress
                Layout.fillWidth: true
                Layout.leftMargin: AppStyle.padding
                Layout.rightMargin: AppStyle.padding
                placeholderText: "IP (e.g. 127.0.0.1)"
                height: AppStyle.inputHeight
                text: "127.0.0.1"
                enabled: !runStopSwitch.checked
                color: enabled ? AppStyle.textColor : "#999999"
            }

            TextField {
                id: oscPort
                Layout.fillWidth: true
                Layout.leftMargin: AppStyle.padding
                Layout.rightMargin: AppStyle.padding
                placeholderText: "Port (e.g. 9000)"
                height: AppStyle.inputHeight
                text: "9000"
                enabled: !runStopSwitch.checked
                color: enabled ? AppStyle.textColor : "#999999"
                validator: IntValidator { bottom: 1; top: 65535 }
            }

            // --- Expose model properties ---
            Label {
                text: "Video Preview"
                font.bold: true
                font.pixelSize: AppStyle.fontSizeSubtitle
                color: AppStyle.textColor
                Layout.leftMargin: AppStyle.padding
                Layout.rightMargin: AppStyle.padding
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 360
                Layout.minimumHeight: 200
                Layout.leftMargin: AppStyle.padding
                Layout.rightMargin: AppStyle.padding
                color: "transparent"
                radius: AppStyle.borderRadius
                border.color: AppStyle.borderColor
                border.width: 1

            UI.TextureSource {
                anchors.fill: parent
                anchors.margins: 2
                process: currentProcess ? currentProcess.videoMapperLabel : "" 
                port: 0
                visible: runStopSwitch.checked
            }
                            
                // Placeholder when no process is selected
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    color: "#F5F5F5"
                    radius: AppStyle.borderRadius
                    visible: !currentProcess || !currentProcess.scenarioLabel
                    
                    Text {
                        anchors.centerIn: parent
                        text: "No model selected"
                        color: AppStyle.textColor
                        font.pixelSize: AppStyle.fontSizeBody
                        opacity: 0.6
                    }
                }
            }

            Item {
                Layout.fillHeight: true
                Layout.minimumHeight: 10
            } // Spacer

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: AppStyle.padding
                Layout.rightMargin: AppStyle.padding
                Layout.bottomMargin: AppStyle.padding

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

                Label {
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
                    color: AppStyle.textColor
                }
            }
        }
    }
}
