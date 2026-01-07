.pragma library

/**
 * Starts the triggered scenario with all necessary device setup
 * @param {Object} context - Context object containing:
 *   - Score: The Score API object
 *   - currentProcess: The currently selected process
 *   - logger: Logger object with log() method
 *   - cameraName: The name of the selected camera
 *   - cameraSettings: The camera device settings
 *   - oscHost: The OSC host address
 *   - oscPort: The OSC output port
 *   - oscReady: Whether OSC is already set up
 *   - getVideoInPort: Function to get video input port
 * @returns {boolean} Whether OSC was set up (for tracking oscReady state)
 */
function startTriggeredScenario(context) {
    var Score = context.Score
    var currentProcess = context.currentProcess
    var logger = context.logger
    
    var scenarioName = currentProcess.scenarioLabel
    logger.log("Starting " + scenarioName + " scenario")
    logger.log("Using camera: " + context.cameraName)

    Score.startMacro()

    // Setup camera
    Score.removeDevice("Camera")
    Score.createDevice("Camera", "d615690b-f2e2-447b-b70e-a800552db69c", context.cameraSettings)
    
    var inputPort = context.getVideoInPort()
    if (inputPort) {
        Score.setAddress(inputPort, "Camera:/")
    }

    // Setup OSC if not ready
    var oscWasSetup = false
    if (!context.oscReady) {
        try { Score.removeDevice("MyOSC") } catch(e) {}
        
        var host = (context.oscHost || "127.0.0.1").trim()
        var outPort = parseInt(context.oscPort) || 9000
        var inPort = (outPort === 9000 ? 9001 : outPort + 1)
        
        console.log("[OSC] createOSCDevice MyOSC → " + host + " (in:" + inPort + " out:" + outPort + ")")
        Score.createOSCDevice("MyOSC", host, inPort, outPort)
        
        try { Score.createAddress("MyOSC:/skeleton", "List") } catch (_) {}
        
        oscWasSetup = true
    }

    Score.endMacro()
    Score.play()
    
    var trigger = Score.find(currentProcess.triggerName)
    if (trigger && typeof trigger.triggeredByGui === 'function') {
        trigger.triggeredByGui()
    }
    
    logger.log("Scenario started successfully")
    return oscWasSetup
}

/**
 * Stops the current running process and cleans up devices
 * @param {Object} Score - The Score API object
 * @param {Object} logger - Logger object with log() method
 */
function stopCurrentProcess(Score, logger) {
    Score.stop()
    Score.startMacro()
    try { Score.removeDevice("MyOSC") } catch(e) {}
    try { Score.removeDevice("Camera") } catch(e) {}
    Score.endMacro()
    logger.log("Scenario stopped")
}

