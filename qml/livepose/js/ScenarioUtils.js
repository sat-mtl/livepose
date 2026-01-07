.pragma library

/**
 * Finds all available AI model scenarios
 * @param {Object} Score - The Score API object
 * @param {Object} logger - Logger object with log() method
 * @returns {Object} Object containing availableProcesses array and modelList
 */
function findAllScenarios(Score, logger) {
    logger.log("Finding AI Model Scenarios")
    var availableProcesses = []
    var labels = ["blazepose", "yolov8_pose", "resnet"]

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

    for (var i = 0; i < labels.length; i++) {
        var id = labels[i]
        var videoMapperId = videoMapperMap[id]
        var proc = Score.find(videoMapperId)
        if (proc) {
            availableProcesses.push({
                scenarioLabel: id,
                videoMapperLabel: videoMapperId, 
                process: proc,
                triggerName: triggerMap[id]
            })
        }
    }

    var modelList = [" "]
    for (var j = 0; j < availableProcesses.length; j++) {
        modelList.push(availableProcesses[j].scenarioLabel)
    }

    return {
        availableProcesses: availableProcesses,
        modelList: modelList
    }
}

/**
 * Gets the video input port via the video mapper
 * @param {Object} Score - The Score API object
 * @param {string} videoMapperLabel - The label of the video mapper
 * @returns {Object|null} The video input port or null
 */
function getVideoInPortViaMapper(Score, videoMapperLabel) {
    if (!videoMapperLabel) return null
    var videoMapper = Score.find(videoMapperLabel)
    if (!videoMapper) return null 
    return Score.port(videoMapper, "in")
}

