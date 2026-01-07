.pragma library

/**
 * Updates the model path in Score for the current process
 * @param {Object} Score - The Score API object
 * @param {Object} currentProcess - The currently selected process
 * @param {string} filePath - The file path to the ONNX model
 * @param {Object} modelObjects - Object containing model port references:
 *   - blazePose: BlazePose model object with .model property
 *   - yoloPose: YOLO Pose model object with .model property
 *   - resnetDetector: Resnet detector object with .model property
 */
function updateModelPath(Score, currentProcess, filePath, modelObjects) {
    if (!currentProcess) return
    if (!filePath) return
    
    var modelMap = {
        "blazepose": modelObjects.blazePose ? modelObjects.blazePose.model : null,
        "yolov8_pose": modelObjects.yoloPose ? modelObjects.yoloPose.model : null,
        "resnet": modelObjects.resnetDetector ? modelObjects.resnetDetector.model : null
    }
    
    var modelPort = modelMap[currentProcess.scenarioLabel]
    if (modelPort) {
        Score.setValue(modelPort, filePath)
    }
}

/**
 * Saves the classes file path for Resnet detector
 * @param {Object} Score - The Score API object
 * @param {Object} currentProcess - The currently selected process
 * @param {string} classesFilePath - The file path to the classes file
 * @param {Object} resnetDetector - The resnet detector object with .classes property
 */
function saveClassesFile(Score, currentProcess, classesFilePath, resnetDetector) {
    if (currentProcess && currentProcess.scenarioLabel === "resnet" && resnetDetector && resnetDetector.classes) {
        try {
            Score.setValue(resnetDetector.classes, classesFilePath)
        } catch(e) {
            console.log("Error saving classes file:", e)
        }
    }
}

/**
 * Sets up the OSC device for output
 * @param {Object} Score - The Score API object
 * @param {string} host - The OSC host address
 * @param {string|number} port - The OSC output port
 */
function setupOSCDevice(Score, host, port) {
    try { Score.removeDevice("MyOSC") } catch(e) {}
    
    var outPort = parseInt(port) || 9000
    var inPort = (outPort === 9000 ? 9001 : outPort + 1)
    var hostAddress = (host || "127.0.0.1").trim()
    
    console.log("[OSC] createOSCDevice MyOSC → " + hostAddress + " (in:" + inPort + " out:" + outPort + ")")
    Score.createOSCDevice("MyOSC", hostAddress, inPort, outPort)
    
    try { Score.createAddress("MyOSC:/skeleton", "List") } catch (_) {}
}

/**
 * Sets up the camera device
 * @param {Object} Score - The Score API object
 * @param {Object} cameraSettings - The camera device settings
 * @param {Object} inputPort - The video input port (optional)
 */
function setupCamera(Score, cameraSettings, inputPort) {
    Score.removeDevice("Camera")
    Score.createDevice("Camera", "d615690b-f2e2-447b-b70e-a800552db69c", cameraSettings)
    if (inputPort) {
        Score.setAddress(inputPort, "Camera:/")
    }
}

/**
 * Removes OSC and Camera devices during cleanup
 * @param {Object} Score - The Score API object
 */
function cleanupDevices(Score) {
    try { Score.removeDevice("MyOSC") } catch(e) {}
    try { Score.removeDevice("Camera") } catch(e) {}
}

