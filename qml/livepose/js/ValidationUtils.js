.pragma library

/**
 * Validates all required inputs before starting a scenario
 * @param {Object} context - Context object containing:
 *   - currentProcess: The currently selected process
 *   - hasValidModelPath: Whether a valid ONNX model path is set
 *   - hasValidClassesPath: Whether a valid classes file path is set (for resnet)
 *   - cameraIndex: The selected camera index
 *   - logger: Logger object with log() method
 * @returns {Object} Object with valid boolean and errors object
 */
function validateBeforeStart(context) {
    var errors = {
        showModelError: false,
        showCameraError: false,
        showModelFileError: false,
        showClassesFileError: false
    }
    
    if (!context.currentProcess || !context.currentProcess.process) {
        context.logger.log("Error: Please select a model first")
        errors.showModelError = true
        return { valid: false, errors: errors }
    }
    
    if (!context.hasValidModelPath) {
        context.logger.log("Error: Please select an ONNX model file")
        errors.showModelFileError = true
        return { valid: false, errors: errors }
    }
    
    if (context.currentProcess.scenarioLabel === "resnet" && !context.hasValidClassesPath) {
        context.logger.log("Error: Please select a classes file")
        errors.showClassesFileError = true
        return { valid: false, errors: errors }
    }
    
    if (context.cameraIndex <= 0) {
        context.logger.log("Error: Please select a camera first")
        errors.showCameraError = true
        return { valid: false, errors: errors }
    }
    
    return { valid: true, errors: errors }
}

