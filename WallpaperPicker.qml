import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

Item {
    id: root

    property string omarchyPath: Quickshell.env("OMARCHY_PATH")
    property var shell: null
    property var manifest: null
    property bool opened: false
    property bool busy: false
    property bool applying: false
    property bool localMode: false
    property bool searchMode: false
    property bool pageMode: false
    property int page: 1
    property int lastPage: 1
    property int selectedIndex: 0
    property string query: ""
    property string querySortMode: "relevance"
    property string sortMode: "month"
    property bool settingsLoaded: false
    property bool sortModeLoaded: false
    property bool pendingInitialLoad: false
    property string pendingSortModeWrite: ""
    property var localThumbnailAttempts: ({})
    property var activeLocalThumbPaths: []
    property int uiCornerRadius: 14
    property int bottomOffset: 0
    property real uiBackgroundOpacity: 1.0
    property bool uiBackgroundBlur: false
    property string statusText: ""
    property var wallpapers: []
    property var wallpaperPages: ({})
    property var wallpaperPageByIndex: []
    property int pendingBoundaryDirection: 0
    property int sessionSerial: 0

    readonly property color scrimColor: Commons.Color.imagePicker.scrim
    readonly property color dockColor: Commons.Color.menu.background
    readonly property color surfaceColor: Qt.rgba(root.dockColor.r, root.dockColor.g, root.dockColor.b, root.dockColor.a * root.uiBackgroundOpacity)
    readonly property color textColor: Commons.Color.menu.text
    readonly property color borderColor: Commons.Color.menu.border
    readonly property color accentColor: Commons.Color.accent
    readonly property color mutedColor: Commons.Color.muted
    readonly property color selectedBorderColor: Commons.Color.imagePicker.selectedBorder
    readonly property color unselectedBorderColor: Commons.Color.imagePicker.unselectedBorder

    onSelectedIndexChanged: {
        if (root.localMode)
            Qt.callLater(function() { root.warmLocalThumbnails() })
        else {
            root.syncCurrentPage()
            Qt.callLater(function() { root.prefetchNearEdge() })
        }
    }

    function open(payloadJson) {
        root.sessionSerial += 1
        root.opened = true
        root.page = 1
        root.lastPage = 1
        root.selectedIndex = 0
        root.query = ""
        root.localMode = true
        root.applying = false
        root.statusText = ""
        root.wallpapers = []
        root.wallpaperPages = ({})
        root.wallpaperPageByIndex = []
        root.pendingBoundaryDirection = 0
        root.searchMode = false
        root.pageMode = false
        searchField.text = ""
        if (!root.settingsLoaded) uiSettings.reload()
        root.sortModeLoaded = false
        root.pendingInitialLoad = true
        stateReader.command = ["python3", Qt.resolvedUrl("wallpaper.py").toString().replace("file://", ""), "load-state"]
        stateReader.running = true
        Qt.callLater(function() { carousel.forceActiveFocus() })
    }

    function close() {
        root.opened = false
        root.cleanupCache()
    }

    function dismiss() {
        root.opened = false
        root.cleanupCache()
        if (root.shell)
            root.shell.hide(root.manifest.id)
    }

    function sortLabel(mode) {
        if (mode === "year") return "TOP OF THE YEAR"
        if (mode === "week") return "TOP OF THE WEEK"
        if (mode === "recent") return "RECENT"
        return "TOP OF THE MONTH"
    }

    function cycleSortMode() {
        if (root.busy || root.localMode) return
        if (root.query.trim()) {
            root.querySortMode = root.querySortMode === "relevance" ? "top" : "relevance"
            root.searchMode = false
            root.page = 1
            root.lastPage = 1
            root.selectedIndex = 0
            root.wallpapers = []
            root.wallpaperPages = ({})
            root.wallpaperPageByIndex = []
            root.statusText = ""
            root.loadPage(1)
            carousel.forceActiveFocus()
            return
        }
        var modes = ["month", "year", "week", "recent"]
        var current = modes.indexOf(root.sortMode)
        root.sortMode = modes[(current + 1 + modes.length) % modes.length]
        root.saveSortMode()
        root.searchMode = false
        root.page = 1
        root.lastPage = 1
        root.selectedIndex = 0
        root.wallpapers = []
        root.wallpaperPages = ({})
        root.wallpaperPageByIndex = []
        root.statusText = ""
        root.loadPage(1)
        carousel.forceActiveFocus()
    }

    function loadUiSettings(raw) {
        try {
            var settings = JSON.parse(raw || "{}")
            if (settings.cornerRadius !== undefined && isFinite(Number(settings.cornerRadius)))
                root.uiCornerRadius = Math.max(0, Number(settings.cornerRadius))
            if (settings.bottomOffset !== undefined && isFinite(Number(settings.bottomOffset)))
                root.bottomOffset = Math.max(0, Number(settings.bottomOffset))
            if (settings.backgroundOpacity !== undefined && isFinite(Number(settings.backgroundOpacity)))
                root.uiBackgroundOpacity = Math.max(0, Math.min(1, Number(settings.backgroundOpacity)))
            if (settings.backgroundBlur !== undefined)
                root.uiBackgroundBlur = settings.backgroundBlur === true
        } catch (error) { console.warn("Invalid Wallhaven UI settings:", error) }
        root.settingsLoaded = true
    }

    function finishInitialLoad() {
        if (root.opened && root.pendingInitialLoad && root.sortModeLoaded) {
            root.pendingInitialLoad = false
            if (root.localMode)
                root.loadLocalWallpapers()
            else
                root.loadPage(1)
        }
    }

    function saveSortMode() {
        if (stateWriter.running) {
            root.pendingSortModeWrite = root.sortMode
            return
        }
        stateWriter.command = ["python3", Qt.resolvedUrl("wallpaper.py").toString().replace("file://", ""), "save-state", root.sortMode]
        stateWriter.running = true
    }

    function runHelper(action, args) {
        helper.command = ["python3", Qt.resolvedUrl("wallpaper.py").toString().replace("file://", ""), action].concat(args)
        helper.running = true
        root.busy = true
    }

    function pageKey(queryText, pageNumber, mode) {
        return String(queryText).trim() + "\u0001" + String(mode) + "\u0001" + String(pageNumber)
    }

    function loadPage(targetPage) {
        if (root.busy || root.localMode) return
        var target = targetPage || root.page
        var mode = root.query.trim() ? root.querySortMode : root.sortMode
        var key = root.pageKey(root.query, target, mode)
        if (wallpaperPages[key] !== undefined) {
            root.page = target
            root.wallpapers = wallpaperPages[key]
            root.wallpaperPageByIndex = root.wallpapers.map(function() { return target })
            root.selectedIndex = 0
            root.pendingBoundaryDirection = 0
            root.statusText = root.wallpapers.length ? "" : "No wallpapers found."
            return
        }
        root.statusText = ""
        root.runHelper("search", [root.query, String(target), mode])
    }

    function currentQueryMode() {
        return root.query.trim() ? root.querySortMode : root.sortMode
    }

    function prefetchPage(target, direction) {
        if (root.localMode || !root.opened || prefetcher.running) return
        if (target < 1 || target > root.lastPage) return
        var key = root.pageKey(root.query, target, root.currentQueryMode())
        if (wallpaperPages[key] !== undefined) {
            root.attachPrefetchedPage(target, wallpaperPages[key], direction)
            return
        }
        prefetcher.command = ["python3", Qt.resolvedUrl("wallpaper.py").toString().replace("file://", ""), "search", root.query, String(target), root.currentQueryMode(), String(root.sessionSerial)]
        prefetcher.running = true
    }

    function attachPrefetchedPage(target, results, direction) {
        if (root.localMode || !results || !results.length) return
        var pageData = results.slice(0)
        var targetKey = root.pageKey(root.query, target, root.currentQueryMode())
        root.wallpaperPages[targetKey] = pageData
        if (direction > 0 && target === root.page + 1) {
            root.wallpapers = root.wallpapers.concat(pageData)
            root.wallpaperPageByIndex = root.wallpaperPageByIndex.concat(pageData.map(function() { return target }))
        } else if (direction < 0 && target === root.page - 1) {
            var oldIndex = root.selectedIndex
            root.wallpapers = pageData.concat(root.wallpapers)
            root.wallpaperPageByIndex = pageData.map(function() { return target }).concat(root.wallpaperPageByIndex)
            root.selectedIndex = oldIndex + pageData.length
            if (root.pendingBoundaryDirection === -1) root.selectedIndex = pageData.length - 1
        } else {
            return
        }
        if (root.pendingBoundaryDirection === direction) root.pendingBoundaryDirection = 0
        root.syncCurrentPage()
    }

    function syncCurrentPage() {
        if (root.localMode || !root.wallpaperPageByIndex.length) return
        var index = Math.max(0, Math.min(root.selectedIndex, root.wallpaperPageByIndex.length - 1))
        root.page = Number(root.wallpaperPageByIndex[index]) || root.page
    }

    function moveSelection(direction) {
        if (!root.wallpapers.length) return
        if (root.localMode) {
            root.selectedIndex = (root.selectedIndex + direction + root.wallpapers.length) % root.wallpapers.length
            return
        }
        var next = root.selectedIndex + direction
        if (next >= 0 && next < root.wallpapers.length) {
            root.selectedIndex = next
            root.clearStatus()
            return
        }
        var adjacent = root.page + direction
        if (adjacent < 1 || adjacent > root.lastPage) return
        root.pendingBoundaryDirection = direction
        root.prefetchPage(adjacent, direction)
    }

    function prefetchNearEdge() {
        if (root.localMode || root.busy || !root.wallpapers.length || prefetcher.running) return
        var remaining = root.wallpapers.length - 1 - root.selectedIndex
        if (remaining <= 4 && root.page < root.lastPage)
            root.prefetchPage(root.page + 1, 1)
        else if (root.selectedIndex <= 4 && root.page > 1)
            root.prefetchPage(root.page - 1, -1)
    }

    function loadLocalWallpapers() {
        if (root.busy || !root.localMode) return
        root.runHelper("local-list", [root.query])
    }

    function warmLocalThumbnails() {
        if (!root.localMode || !root.wallpapers.length || localThumbnailer.running) return
        var paths = []
        var count = root.wallpapers.length
        for (var i = 0; i < count; i++) {
            var item = root.wallpapers[i]
            var forward = ((i - root.selectedIndex) % count + count) % count
            var distance = forward > count / 2 ? forward - count : forward
            if (Math.abs(distance) <= 4 && item.thumb !== item.thumbCache
                    && !root.localThumbnailAttempts[item.sourcePath])
                paths.push(item.sourcePath)
        }
        if (!paths.length) return
        root.activeLocalThumbPaths = paths
        localThumbnailer.command = ["python3", Qt.resolvedUrl("wallpaper.py").toString().replace("file://", ""), "cache-local", JSON.stringify(paths)]
        localThumbnailer.running = true
    }

    function updateLocalThumbnailResults(raw, exitCode) {
        var cachedBySource = ({})
        if (exitCode === 0 && raw) {
            try {
                var response = JSON.parse(raw)
                if (response.ok) {
                    var entries = response.result.data || []
                    for (var resultIndex = 0; resultIndex < entries.length; resultIndex++)
                        cachedBySource[entries[resultIndex].sourcePath] = entries[resultIndex].thumb
                }
            } catch (error) {
                console.warn("Could not read local thumbnail results:", error)
            }
        }

        var refreshed = root.wallpapers.slice()
        for (var index = 0; index < refreshed.length; index++) {
            var item = refreshed[index]
            var cachedPath = cachedBySource[item.sourcePath]
            if (cachedPath) {
                var updated = ({})
                for (var key in item) updated[key] = item[key]
                updated.thumb = cachedPath
                refreshed[index] = updated
            }
        }
        root.wallpapers = refreshed

        for (var requestedIndex = 0; requestedIndex < root.activeLocalThumbPaths.length; requestedIndex++) {
            var requestedPath = root.activeLocalThumbPaths[requestedIndex]
            if (!cachedBySource[requestedPath])
                root.localThumbnailAttempts[requestedPath] = true
        }
        root.activeLocalThumbPaths = []
        Qt.callLater(function() { root.warmLocalThumbnails() })
    }

    function switchMode(useLocal) {
        if (root.busy || root.localMode === useLocal) return
        root.localMode = useLocal
        root.query = ""
        searchField.text = ""
        root.page = 1
        root.lastPage = 1
        root.selectedIndex = 0
        root.wallpapers = []
        root.wallpaperPages = ({})
        root.wallpaperPageByIndex = []
        root.statusText = ""
        if (!root.localMode && !root.sortModeLoaded) {
            root.pendingInitialLoad = true
            carousel.forceActiveFocus()
            return
        }
        if (root.localMode)
            root.loadLocalWallpapers()
        else
            root.loadPage(1)
        carousel.forceActiveFocus()
    }

    function imageSource(path) {
        var value = String(path || "")
        if (value.startsWith("http://") || value.startsWith("https://") || value.startsWith("file://"))
            return value
        return "file://" + encodeURI(value)
    }

    function applySelected() {
        var wallpaper = wallpapers[root.selectedIndex]
        if (!wallpaper || root.busy) return
        if (root.localMode) {
            root.applying = true
            root.runHelper("apply-local", [wallpaper.url])
            return
        }
        var title = root.query.trim()
        if (!title) title = "Wallhaven " + wallpaper.id
        root.applying = true
        root.runHelper("apply", [wallpaper.id, wallpaper.url, title])
    }

    function downloadSelected() {
        var wallpaper = wallpapers[root.selectedIndex]
        if (!wallpaper || root.busy || root.localMode) return
        root.statusText = "Downloading wallpaper…"
        root.runHelper("download", [wallpaper.id, wallpaper.url])
    }

    function clearStatus() {
        statusClearTimer.stop()
        root.statusText = ""
    }

    function cleanupCache() {
        if (helper.running || prefetcher.running) {
            root.cacheCleanupPending = true
            return
        }
        cleanup.command = ["python3", Qt.resolvedUrl("wallpaper.py").toString().replace("file://", ""), "cleanup"]
        cleanup.running = true
        root.cacheCleanupPending = false
    }

    property bool cacheCleanupPending: false

    FileView {
        id: uiSettings
        path: Quickshell.env("HOME") + "/.config/omarchy/plugins/abhijeet.wallpaper-picker/ui-config.json"
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadUiSettings(text())
        onLoadFailed: root.loadUiSettings("")
        onFileChanged: reload()
    }

    Process {
        id: stateReader
        stdout: StdioCollector { id: stateReaderOutput }
        stderr: StdioCollector { id: stateReaderError }
        onExited: function(exitCode) {
            if (exitCode === 0 && stateReaderOutput.text.length) {
                try {
                    var response = JSON.parse(stateReaderOutput.text)
                    if (response.ok && ["month", "year", "week", "recent"].indexOf(response.result.sortMode) >= 0)
                        root.sortMode = response.result.sortMode
                    else if (!response.ok)
                        console.warn("Could not load Wallhaven sort mode:", response.error)
                } catch (error) {
                    console.warn("Could not parse Wallhaven sort mode:", error)
                }
            } else {
                console.warn("Could not load Wallhaven sort mode:", stateReaderError.text)
            }
            root.sortModeLoaded = true
            root.finishInitialLoad()
        }
    }

    Process {
        id: stateWriter
        stdout: StdioCollector { id: stateWriterOutput }
        stderr: StdioCollector { id: stateWriterError }
        onExited: function(exitCode) {
            if (exitCode !== 0)
                console.warn("Could not save Wallhaven sort mode:", stateWriterError.text || stateWriterOutput.text)
            if (root.pendingSortModeWrite) {
                var mode = root.pendingSortModeWrite
                root.pendingSortModeWrite = ""
                stateWriter.command = ["python3", Qt.resolvedUrl("wallpaper.py").toString().replace("file://", ""), "save-state", mode]
                stateWriter.running = true
            }
        }
    }

    Process {
        id: localThumbnailer
        stdout: StdioCollector { id: localThumbnailOutput }
        stderr: StdioCollector { id: localThumbnailError }
        onExited: function(exitCode) {
            if (exitCode !== 0)
                console.warn("Could not cache local wallpaper thumbnails:", localThumbnailError.text)
            root.updateLocalThumbnailResults(localThumbnailOutput.text, exitCode)
        }
    }

    function finishPendingCleanup() {
        if (!root.opened && root.cacheCleanupPending && !helper.running && !prefetcher.running)
            root.cleanupCache()
    }

    function handleHelperResult(raw) {
        var response = JSON.parse(raw)
        if (!response.ok) {
            root.statusText = response.error
            return
        }
        if (helper.command[2] === "search") {
            var resultQuery = String(helper.command[3] || "").trim()
            var resultPage = Number(helper.command[4])
            var resultMode = String(helper.command[5] || "month")
            var results = response.result.data
            root.wallpaperPages[root.pageKey(resultQuery, resultPage, resultMode)] = results
            root.lastPage = Math.max(1, response.result.meta.last_page || 1)
            root.page = resultPage
            root.wallpapers = results
            root.wallpaperPageByIndex = results.map(function() { return resultPage })
            root.pendingBoundaryDirection = 0
            root.selectedIndex = 0
            root.statusText = results.length ? "" : "No wallpapers found."
            Qt.callLater(function() { root.prefetchNearEdge() })
        } else if (helper.command[2] === "local-list") {
            root.localThumbnailAttempts = ({})
            root.wallpapers = response.result.data || []
            root.page = 1
            root.lastPage = 1
            root.selectedIndex = 0
            root.statusText = root.wallpapers.length ? "" : (root.query.trim() ? "No matching saved wallpapers." : "No saved wallpapers in ~/Wallpapers.")
            Qt.callLater(function() { root.warmLocalThumbnails() })
        } else if (helper.command[2] === "download") {
            root.statusText = "Saved to ~/Wallpapers/" + response.result.filename
            statusClearTimer.restart()
        } else if (helper.command[2] === "apply") {
            root.dismiss()
        } else if (helper.command[2] === "apply-local") {
            root.dismiss()
        }
    }

    function changePage(target) {
        if (root.busy) return
        if (root.localMode) return
        if (target < 1 || target > root.lastPage) {
            root.statusText = "Page " + target + " does not exist (1–" + root.lastPage + ")"
            return
        }
        root.loadPage(target)
    }

    Process {
        id: helper
        stdout: StdioCollector { id: helperOutput }
        stderr: StdioCollector { id: helperError }
        onExited: function(exitCode, exitStatus) {
            root.busy = false
            if (helperOutput.text.length > 0) {
                try { root.handleHelperResult(helperOutput.text) }
                catch (error) { root.statusText = String(error) }
            } else if (exitCode !== 0) {
                root.statusText = helperError.text || "Wallpaper request failed."
            }
            root.applying = false
            root.finishPendingCleanup()
        }
    }

    Process {
        id: prefetcher
        stdout: StdioCollector { id: prefetchOutput }
        stderr: StdioCollector { id: prefetchError }
        onExited: function(exitCode) {
            root.finishPendingCleanup()
            if (exitCode !== 0 || !prefetchOutput.text.length) return
            try {
                var response = JSON.parse(prefetchOutput.text)
                var resultQuery = String(prefetcher.command[3] || "").trim()
                var resultPage = Number(prefetcher.command[4])
                var resultMode = String(prefetcher.command[5] || "month")
                var resultSession = Number(prefetcher.command[6])
                if (!root.opened || resultSession !== root.sessionSerial || !response.ok
                        || resultQuery !== root.query.trim() || resultMode !== root.currentQueryMode()) return
                root.lastPage = Math.max(1, response.result.meta.last_page || root.lastPage)
                root.attachPrefetchedPage(resultPage, response.result.data || [], resultPage > root.page ? 1 : -1)
                Qt.callLater(function() { root.prefetchNearEdge() })
            } catch (error) {
                console.warn("Could not preload adjacent Wallhaven page:", error, prefetchError.text)
            }
        }
    }

    Process { id: cleanup }

    Timer {
        id: statusClearTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (root.statusText.startsWith("Saved to ~/Wallpapers/"))
                root.statusText = ""
        }
    }

    PanelWindow {
        id: panel
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "abhijeet-wallhaven"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        BackgroundEffect.blurRegion: root.uiBackgroundBlur ? dockBlurRegion : null
        exclusionMode: ExclusionMode.Ignore
        onVisibleChanged: if (visible) Qt.callLater(function() { carousel.forceActiveFocus() })

        Region {
            id: dockBlurRegion
            item: dock
            radius: root.uiCornerRadius
        }

        Shortcut { sequence: "Escape"; onActivated: root.dismiss() }
        Shortcut { sequence: "Alt+Left"; enabled: !root.pageMode && !root.localMode; onActivated: root.changePage(root.page - 1) }
        Shortcut { sequence: "Alt+Right"; enabled: !root.pageMode && !root.localMode; onActivated: root.changePage(root.page + 1) }
        Shortcut {
            sequence: "Alt+S"
            enabled: !root.busy && !root.pageMode
            onActivated: {
                root.searchMode = true
                searchField.text = root.query
                Qt.callLater(function() { searchField.forceActiveFocus(); searchField.selectAll() })
            }
        }
        Shortcut { sequence: "Alt+D"; enabled: !root.busy && !root.localMode; onActivated: root.downloadSelected() }
        Shortcut { sequence: "Alt+1"; enabled: !root.busy; onActivated: root.switchMode(true) }
        Shortcut { sequence: "Alt+2"; enabled: !root.busy; onActivated: root.switchMode(false) }
        Shortcut { sequence: "Alt+M"; enabled: !root.busy && !root.localMode; onActivated: root.cycleSortMode() }
        Shortcut {
            sequence: "Alt+P"
            enabled: !root.busy && !root.pageMode && !root.localMode
            onActivated: {
                root.pageMode = true
                root.searchMode = false
                pageField.text = ""
                Qt.callLater(function() { pageField.forceActiveFocus() })
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"

            Rectangle {
                id: dock
                width: Math.min(parent.width - 32, 1060)
                height: 246
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.bottomOffset
                radius: Math.min(root.uiCornerRadius, height / 2)
                color: root.surfaceColor
                border.color: root.borderColor
                border.width: 1
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    spacing: 4

                    Item {
                        id: carousel
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        focus: true
                        property real itemStep: 190

                        Keys.priority: Keys.BeforeItem
                        Keys.onPressed: function(event) {
                            if (root.searchMode || root.pageMode || root.busy) return
                            if (event.key === Qt.Key_Left) {
                                root.moveSelection(-1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Right) {
                                root.moveSelection(1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.applySelected()
                                event.accepted = true
                            }
                        }

                        WheelHandler {
                            target: carousel
                            enabled: !root.localMode && !root.searchMode && !root.pageMode && !root.busy
                            onWheel: function(event) {
                                var delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
                                if (delta !== 0) {
                                    root.moveSelection(delta < 0 ? 1 : -1)
                                    event.accepted = true
                                }
                            }
                        }

                        Repeater {
                            model: root.wallpapers

                            delegate: Item {
                                id: wallpaperDelegate
                                required property var modelData
                                required property int index
                                readonly property int distance: {
                                    var count = root.wallpapers.length
                                    if (!count) return 0
                                    if (!root.localMode) return index - root.selectedIndex
                                    var forward = ((index - root.selectedIndex) % count + count) % count
                                    return forward > count / 2 ? forward - count : forward
                                }
                                readonly property bool selected: distance === 0
                                visible: Math.abs(distance) <= 4
                                width: carousel.itemStep
                                height: carousel.height
                                x: carousel.width / 2 - width / 2 + distance * carousel.itemStep
                                z: selected ? 100 : 50 - Math.abs(distance)

                                Behavior on x {
                                    NumberAnimation { duration: 360; easing.type: Easing.OutCubic }
                                }

                                Rectangle {
                                    id: card
                                    width: wallpaperDelegate.selected ? 224 : 176
                                    height: wallpaperDelegate.selected ? 128 : 98
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: wallpaperDelegate.selected ? 1 : 29
                                    radius: Math.min(root.uiCornerRadius, height / 2)
                                    color: root.surfaceColor
                                    clip: true
                                    scale: 1

                                    Behavior on width {
                                        NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.55 }
                                    }
                                    Behavior on height {
                                        NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.55 }
                                    }
                                    Behavior on y {
                                        NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.55 }
                                    }
                                    Behavior on scale {
                                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                    }

                                    Item {
                                        id: imageLayer
                                        anchors.fill: parent
                                        layer.enabled: true
                                        layer.smooth: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: roundedMask
                                            maskThresholdMin: 0.5
                                            maskSpreadAtMin: 0.5
                                        }

                                        Image {
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                            smooth: true
                                            mipmap: true
                                            sourceSize.width: 448
                                            sourceSize.height: 256
                                            source: Math.abs(wallpaperDelegate.distance) <= 4
                                                ? root.imageSource(wallpaperDelegate.modelData.thumb)
                                                : ""
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: card.radius
                                        color: "transparent"
                                        border.color: wallpaperDelegate.selected ? root.selectedBorderColor : root.unselectedBorderColor
                                        border.width: wallpaperDelegate.selected ? 3 : 1
                                    }

                                    Item {
                                        id: roundedMask
                                        width: card.width
                                        height: card.height
                                        visible: false
                                        layer.enabled: true
                                        layer.smooth: true
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: card.radius
                                            color: "white"
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedIndex = wallpaperDelegate.index
                                            root.clearStatus()
                                            carousel.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            id: pageIndicator
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 10
                            anchors.rightMargin: 18
                            z: 1000
                            text: root.localMode
                                ? String(root.wallpapers.length) + " WALLPAPERS"
                                : "PAGE " + root.page + " / " + root.lastPage
                            color: root.mutedColor
                            font.pixelSize: 11
                            font.family: "monospace"
                            font.letterSpacing: 0.4
                        }

                        Item {
                            id: loadingSpinner
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            width: 38
                            height: 38
                            z: 1000
                            visible: prefetcher.running || (root.busy && helper.command.length > 2 && ["search", "local-list", "download", "apply", "apply-local"].indexOf(helper.command[2]) >= 0)

                            NumberAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 850
                                loops: Animation.Infinite
                                running: loadingSpinner.visible
                                easing.type: Easing.Linear
                            }

                            Repeater {
                                model: 8
                                delegate: Rectangle {
                                    required property int index
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: root.accentColor
                                    opacity: 1 - index * 0.09
                                    x: loadingSpinner.width / 2 - width / 2 + Math.cos(index * Math.PI / 4) * 13
                                    y: loadingSpinner.height / 2 - height / 2 + Math.sin(index * Math.PI / 4) * 13
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.busy && root.wallpapers.length === 0
                            text: root.statusText || "No wallpapers found"
                            color: root.textColor
                            font.pixelSize: 14
                        }
                    }

                    Rectangle {
                        id: searchBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: Math.min(root.uiCornerRadius, height / 2)
                        color: Qt.darker(root.surfaceColor, 1.08)
                        border.color: root.searchMode || root.pageMode ? root.accentColor : root.borderColor
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            Item {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                Rectangle {
                                    x: 2; y: 1
                                    width: 13; height: 13
                                    radius: 7
                                    color: "transparent"
                                    border.width: 2
                                    border.color: root.mutedColor
                                }
                                Rectangle {
                                    x: 14; y: 14
                                    width: 8; height: 2
                                    radius: 1
                                    rotation: 45
                                    color: root.mutedColor
                                }
                            }

                            TextField {
                                id: searchField
                                visible: !root.pageMode
                                    enabled: !root.busy
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: root.query
                                placeholderText: root.localMode ? "Search saved wallpapers…" : "Search Wallhaven…"
                                color: root.textColor
                                placeholderTextColor: root.mutedColor
                                selectionColor: Commons.Color.lock.selection
                                selectedTextColor: root.textColor
                                background: Item {}
                                font.pixelSize: 14
                                onActiveFocusChanged: if (activeFocus) {
                                    root.searchMode = true
                                    root.pageMode = false
                                    text = root.query
                                }
                                onAccepted: {
                                    root.query = text.trim()
                                    root.page = 1
                                    root.lastPage = 1
                                    root.selectedIndex = 0
                                    root.wallpapers = []
                                    root.wallpaperPages = ({})
                                    root.wallpaperPageByIndex = []
                                    root.pendingBoundaryDirection = 0
                                    root.clearStatus()
                                    root.searchMode = false
                                    carousel.forceActiveFocus()
                                    if (root.localMode)
                                        root.loadLocalWallpapers()
                                    else {
                                        root.querySortMode = "relevance"
                                        root.loadPage(1)
                                    }
                                }
                            }

                            TextField {
                                id: pageField
                                visible: root.pageMode
                                    enabled: !root.busy
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                placeholderText: "Page number…"
                                color: root.textColor
                                placeholderTextColor: root.mutedColor
                                selectionColor: Commons.Color.lock.selection
                                selectedTextColor: root.textColor
                                background: Item {}
                                inputMethodHints: Qt.ImhDigitsOnly
                                validator: IntValidator { bottom: 1; top: 999999 }
                                font.pixelSize: 14
                                onAccepted: {
                                    var target = Number(text)
                                    root.pageMode = false
                                    carousel.forceActiveFocus()
                                    root.changePage(target)
                                    text = ""
                                }
                            }

                            Text {
                                visible: !root.query.trim() && !root.localMode
                                text: root.sortLabel(root.sortMode)
                                color: root.accentColor
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.6
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !root.busy
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cycleSortMode()
                                }
                            }
                            Text {
                                visible: root.localMode && !root.query.trim()
                                text: "LOCAL WALLPAPERS"
                                color: root.accentColor
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.6
                            }
                            Text {
                                visible: !!root.query.trim() && !root.localMode
                                text: root.querySortMode === "relevance" ? "RELEVANCE" : "TOP RESULTS"
                                color: root.querySortMode === "relevance" ? root.mutedColor : root.accentColor
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.6
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !root.busy
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cycleSortMode()
                                }
                            }
                            Text {
                                visible: root.localMode && !!root.query.trim()
                                text: "LOCAL SEARCH"
                                color: root.mutedColor
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.6
                            }

                            Text {
                                visible: !!root.statusText
                                text: root.statusText
                                color: Commons.Color.urgent
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.maximumWidth: 230
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 20
                                color: root.borderColor
                                opacity: 0.6
                            }

                            Text {
                                text: root.wallpapers.length
                                    ? String(root.selectedIndex + 1).padStart(2, "0") + " / " + String(root.wallpapers.length).padStart(2, "0")
                                    : (root.busy ? "…" : "00 / 00")
                                color: root.textColor
                                font.pixelSize: 12
                                font.family: "monospace"
                            }
                        }
                    }
                }
            }
        }
    }
}
