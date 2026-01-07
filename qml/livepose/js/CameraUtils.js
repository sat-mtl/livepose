.pragma library

/**
 * Enumerates available camera devices
 * @param {Object} Score - The Score API object
 * @param {Object} logger - Logger object with log() method
 * @returns {Object} Object containing cameraList and cameraPrettyNamesList
 */
function enumerateCameras(Score, logger) {
    logger.log("Enumerating cameras...")
    console.log("Starting camera enumeration...")

    var result = {
        deviceEnumerator: null,
        cameraList: [],
        cameraPrettyNamesList: []
    }

    try {
        result.deviceEnumerator = Score.enumerateDevices(
            "d615690b-f2e2-447b-b70e-a800552db69c")
        console.log("Score.enumerateDevices returned:", result.deviceEnumerator)

        result.deviceEnumerator.enumerate = true
        console.log("Set enumerate to true")
        console.log("Devices array:", result.deviceEnumerator.devices)

        for (var i = 0; i < result.deviceEnumerator.devices.length; i++) {
            var dev = result.deviceEnumerator.devices[i]
            console.log("Found device:", dev)
            console.log("Device protocol:", dev.protocol)
            console.log("Device name:", dev.name)
            logger.log("Found camera: " + dev.name)

            result.cameraList.push(dev)
            result.cameraPrettyNamesList.push(dev.category + ": " + dev.name)
        }

        console.log("Final camera list:", result.cameraPrettyNamesList)
    } catch (error) {
        console.error("Error during camera enumeration:", error)
        logger.log("Error enumerating cameras: " + error)
    }

    return result
}

