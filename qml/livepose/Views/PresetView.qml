import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtCore
import QtQuick.Dialogs
import livepose

Pane {
    id: presetView
    background: Rectangle { color: appStyle.backgroundColor }

    // The RunView instance the presets are applied to (wired up in Main.qml).
    property var runView: null

    // Bumped to re-evaluate "are the models on disk?" checks.
    property int refreshKey: 0

    // Presets discovered from the pack(s) on disk (not bundled with the app, so
    // any model pack — now or later — brings its own presets).
    property var presetsList: []
    property var byCategory: ({})
    property var categoryOrder: []

    // Preferred menu order; categories outside this list are appended after.
    readonly property var preferredOrder: [
        "Body/Single-stage", "Body/Two-stage", "Body/Whole-frame", "Body/3D",
        "Hand", "Face/Landmarks", "Face/Detection", "Animal",
        "Detection (boxes)", "Tracking & Re-ID"
    ]

    readonly property string downloadUrl: "https://github.com/sat-mtl/livepose/releases/tag/model-storage"

    // Where the packs live. Points at the score-style "packages" folder by
    // default; discovery also accepts a single pack folder or a library root.
    readonly property string defaultModelsFolder:
        urlToLocalPath(StandardPaths.writableLocation(StandardPaths.DocumentsLocation))
        + "/SAT/LivePose/packages"

    readonly property string modelsFolder:
        modelsFolderField.text !== "" ? modelsFolderField.text : defaultModelsFolder

    function urlToLocalPath(u) {
        var s = "" + u
        if (s.indexOf("file://") === 0) s = s.substring("file://".length)
        if (Qt.platform.os === "windows" && s.length > 1 && s.charAt(0) === "/")
            s = s.substring(1)
        return decodeURIComponent(s)
    }

    function dirName(p) {
        var i = p.lastIndexOf("/")
        return i > 0 ? p.substring(0, i) : p
    }

    // Util.readFile returns the raw bytes; decode to text for JSON.parse.
    function readText(path) {
        var data = Util.readFile(path)
        if (data === undefined || data === null) return ""
        if (typeof data === "string") return data
        try {
            var u8 = new Uint8Array(data)
            var s = ""
            for (var i = 0; i < u8.length; i++) s += String.fromCharCode(u8[i])
            return s
        } catch (e) {
            return "" + data
        }
    }

    // Every "<pack>/presets/PoseDetector" dir reachable from `root`, whether it
    // points at a single pack, a packages dir, or a library root.
    function presetDirs(root) {
        var dirs = []
        function add(dir) {
            var pd = dir + "/presets/PoseDetector"
            if (Util.isDir(pd) && dirs.indexOf(pd) < 0) dirs.push(pd)
        }
        add(root)
        var subs = Util.listDirectories(root)
        for (var i = 0; i < subs.length; i++) add(subs[i])
        if (Util.isDir(root + "/packages")) {
            var subs2 = Util.listDirectories(root + "/packages")
            for (var j = 0; j < subs2.length; j++) add(subs2[j])
        }
        return dirs
    }

    function discover() {
        var list = []
        var dirs = presetDirs(modelsFolder)
        for (var d = 0; d < dirs.length; d++) {
            var packDir = dirName(dirName(dirs[d]))   // <pack>/presets/PoseDetector -> <pack>
            var files = Util.listFiles(dirs[d], "*.scp")
            for (var f = 0; f < files.length; f++) {
                try {
                    var obj = JSON.parse(readText(files[f]))
                    var pr = obj.Preset || []
                    var models = []
                    for (var v = 0; v < pr.length; v++) {
                        var id = pr[v][0], wrap = pr[v][1]
                        if ((id === 1 || id === 7 || id === 14) && wrap && wrap.String
                                && ("" + wrap.String).indexOf(".onnx") >= 0)
                            models.push(wrap.String)
                    }
                    list.push({
                        name: obj.Name || files[f],
                        category: obj.Category || "Uncategorized",
                        values: pr,
                        models: models,
                        packDir: packDir
                    })
                } catch (e) {
                    mainWindow.logger.log("Preset parse failed: " + files[f])
                }
            }
        }

        list.sort(function(a, b) {
            var ca = preferredOrder.indexOf(a.category); if (ca < 0) ca = 999
            var cb = preferredOrder.indexOf(b.category); if (cb < 0) cb = 999
            if (ca !== cb) return ca - cb
            var na = a.name.toLowerCase(), nb = b.name.toLowerCase()
            return na < nb ? -1 : (na > nb ? 1 : 0)
        })

        var grp = ({}), order = []
        for (var k = 0; k < list.length; k++) {
            var c = list[k].category
            if (!grp[c]) { grp[c] = []; order.push(c) }
            grp[c].push(list[k])
        }
        presetsList = list
        byCategory = grp
        categoryOrder = order
        refreshKey++
    }

    // A preset is "ready" when every model it references exists under its pack.
    function presetReady(preset) {
        if (!preset.models || preset.models.length === 0) return false
        if (!runView) return false
        for (var i = 0; i < preset.models.length; i++) {
            var path = runView.resolvePresetPath(preset.models[i], preset.packDir)
            if (!path || !Util.fileExists(path)) return false
        }
        return true
    }

    function readyCount() {
        var n = 0
        for (var i = 0; i < presetsList.length; i++)
            if (presetReady(presetsList[i])) n++
        return n
    }

    Component.onCompleted: {
        modelsFolderField.text = appSettings.poseDetectorModelsFolder
        if (modelsFolderField.text === "")
            modelsFolderField.text = defaultModelsFolder
        discover()
    }

    onVisibleChanged: if (visible) discover()

    FolderDialog {
        id: modelsFolderDialog
        title: "Select Models / Packs Folder"
        onAccepted: {
            if (!selectedFolder) return
            modelsFolderField.text = urlToLocalPath(selectedFolder)
            discover()
        }
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
                    text: "Presets"
                    font.bold: true
                    font.pixelSize: appStyle.fontSizeSubtitle
                    Layout.topMargin: appStyle.padding
                }

                CustomLabel {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: appStyle.textColorSecondary
                    font.pixelSize: appStyle.fontSizeSmall
                    text: "Presets are read from the model pack(s) on disk. Click one to "
                        + "fill in the Run settings, then press Start — the preview is on "
                        + "the right."
                }

                CustomLabel { text: "Models / Packs Folder"; font.bold: true; Layout.topMargin: appStyle.spacing }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: appStyle.spacing

                    CustomTextField {
                        id: modelsFolderField
                        Layout.fillWidth: true
                        placeholderText: presetView.defaultModelsFolder
                        onTextChanged: {
                            appSettings.poseDetectorModelsFolder = text
                            presetView.refreshKey++
                        }
                        onEditingFinished: presetView.discover()
                    }

                    Button {
                        text: "Browse"
                        font.family: appStyle.fontFamily
                        font.pixelSize: appStyle.fontSizeBody
                        onClicked: modelsFolderDialog.open()
                    }

                    Button {
                        text: "Rescan"
                        font.family: appStyle.fontFamily
                        font.pixelSize: appStyle.fontSizeBody
                        onClicked: presetView.discover()
                    }

                    Button {
                        text: "Get models…"
                        font.family: appStyle.fontFamily
                        font.pixelSize: appStyle.fontSizeBody
                        onClicked: Qt.openUrlExternally(presetView.downloadUrl)
                    }
                }

                CustomLabel {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: appStyle.fontSizeSmall
                    color: presetView.presetsList.length === 0 ? appStyle.errorColor
                                                               : appStyle.textColorSecondary
                    text: {
                        presetView.refreshKey
                        if (presetView.presetsList.length === 0)
                            return "No presets found under this folder. Download a model pack "
                                + "via “Get models…”, extract it here, then press Rescan."
                        return presetView.readyCount() + " / " + presetView.presetsList.length
                            + " presets have their models on disk."
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: appStyle.spacing * 0.5
                    Layout.preferredHeight: 1
                    color: appStyle.separatorColor
                }

                Repeater {
                    model: presetView.categoryOrder

                    ColumnLayout {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.topMargin: appStyle.spacing
                        spacing: appStyle.spacing * 0.5

                        CustomLabel {
                            text: modelData
                            font.bold: true
                            color: appStyle.textColorSecondary
                        }

                        Repeater {
                            model: presetView.byCategory[modelData] || []

                            Rectangle {
                                id: card
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 36
                                radius: appStyle.borderRadius
                                color: cardMouse.containsMouse ? appStyle.backgroundColorTertiary
                                                               : appStyle.backgroundColorSecondary
                                border.width: 1
                                border.color: cardMouse.containsMouse ? appStyle.primaryColor
                                                                      : appStyle.borderColor

                                readonly property bool ready: {
                                    presetView.refreshKey
                                    return presetView.presetReady(modelData)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: appStyle.spacing
                                    anchors.rightMargin: appStyle.spacing
                                    spacing: appStyle.spacing

                                    Rectangle {
                                        Layout.preferredWidth: 9
                                        Layout.preferredHeight: 9
                                        radius: 4.5
                                        Layout.alignment: Qt.AlignVCenter
                                        color: card.ready ? appStyle.buttonBgActive : appStyle.borderColor
                                    }

                                    CustomLabel {
                                        Layout.fillWidth: true
                                        text: card.modelData.name
                                        elide: Text.ElideRight
                                        color: card.ready ? appStyle.textColor : appStyle.textColorSecondary
                                    }

                                    CustomLabel {
                                        text: "models missing"
                                        visible: !card.ready
                                        font.pixelSize: appStyle.fontSizeSmall
                                        color: appStyle.textColorSecondary
                                    }
                                }

                                MouseArea {
                                    id: cardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (presetView.runView) {
                                            presetView.runView.applyPreset(card.modelData.values,
                                                                           card.modelData.packDir)
                                            mainWindow.logger.log("Loaded preset: " + card.modelData.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: appStyle.padding }
            }
        }

        Item {
            SplitView.preferredWidth: 480
            SplitView.minimumWidth: 320

            PreviewPanel {
                anchors.fill: parent
                anchors.margins: appStyle.padding
                target: presetView.runView
                // Owns the preview only while the PRESETS view is showing.
                active: mainWindow.currentViewIndex === mainWindow.presetsViewIndex
            }
        }
    }
}
