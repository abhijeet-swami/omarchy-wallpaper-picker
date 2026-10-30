import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "components" as PickerComponents
import "components/settings" as PickerSettings

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
    property bool settingsMode: false
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
    readonly property int uiCornerRadius: Style.cornerRadius
    property real uiBorderWidth: 2
    property int bottomOffset: 0
    property bool uiBackgroundBlur: false
    property var themeSettings: ({
        blurEnabled: false,
        blurSize: 8,
        blurPasses: 1,
        noiseEnabled: false,
        noiseStrength: 0.0117,
        rounding: 0,
        borderWidth: 2,
        shadowEnabled: false,
        shadowRange: 4,
        inactiveOpacity: 1.0,
        sameWindowOpacity: false,
        terminalOpacity: 1.0,
        themeMode: "dark",
        shellOpacity: 1.0,
        animationPreset: "fluid",
        useThemeOverrides: false
    })
    readonly property var defaultThemeSettings: ({
        blurEnabled: false,
        blurSize: 8,
        blurPasses: 1,
        noiseEnabled: false,
        noiseStrength: 0.0117,
        rounding: 0,
        borderWidth: 2,
        shadowEnabled: false,
        shadowRange: 4,
        inactiveOpacity: 1.0,
        sameWindowOpacity: false,
        terminalOpacity: 1.0,
        themeMode: "dark",
        shellOpacity: 1.0,
        animationPreset: "fluid",
        useThemeOverrides: false
    })
    readonly property var animationPresetIds: ["fast", "fluid", "smooth", "vertical", "none"]
    readonly property var animationPresetNames: ["Fast", "Fluid", "Smooth", "Vertical", "No animation"]
    property string settingsMessage: ""
    property string statusText: ""
    property var wallpapers: []
    property var wallpaperPages: ({})
    property var wallpaperPageByIndex: []
    property int pendingBoundaryDirection: 0
    property int sessionSerial: 0
    readonly property bool prefetching: prefetcher.running
    readonly property var helperCommand: helper.command
    readonly property bool settingsApplying: settingsApplier.running

    readonly property color scrimColor: Commons.Color.imagePicker.scrim
    readonly property color dockColor: Commons.Color.menu.background
    readonly property color surfaceColor: root.dockColor
    readonly property color textColor: Commons.Color.menu.text
    readonly property color borderColor: Commons.Color.menu.border
    readonly property color accentColor: Commons.Color.accent
    readonly property color mutedColor: Commons.Color.muted
    readonly property color selectedBorderColor: Commons.Color.imagePicker.selectedBorder
    readonly property color unselectedBorderColor: Commons.Color.imagePicker.unselectedBorder

    onThemeSettingsChanged: {
        root.uiBorderWidth = Math.max(0, Number(root.themeSettings.borderWidth !== undefined ? root.themeSettings.borderWidth : 2))
    }

    onSelectedIndexChanged: {
        if (root.localMode)
            Qt.callLater(function() { root.warmLocalThumbnails() })
        else {
            root.syncCurrentPage()
            Qt.callLater(function() { root.prefetchNearEdge() })
        }
    }

    function focusGallery() {
        if (root.localMode) localGallery.forceActiveFocus()
        else wallhavenGallery.forceActiveFocus()
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
        root.settingsMode = false
        pickerSearch.searchInput.text = ""
        if (!root.settingsLoaded) uiSettings.reload()
        root.sortModeLoaded = false
        root.pendingInitialLoad = true
        stateReader.command = ["python3", Qt.resolvedUrl("wallpaper.py").toString().replace("file://", ""), "load-state"]
        stateReader.running = true
        Qt.callLater(function() { root.focusGallery() })
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
            root.focusGallery()
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
        root.focusGallery()
    }

    function loadUiSettings(raw) {
        try {
            var settings = JSON.parse(raw || "{}")
            if (settings.bottomOffset !== undefined && isFinite(Number(settings.bottomOffset)))
                root.bottomOffset = Math.max(0, Number(settings.bottomOffset))
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

    function setThemeSetting(name, value) {
        var updated = ({})
        for (var key in root.themeSettings) updated[key] = root.themeSettings[key]
        updated[name] = value
        if (name === "themeMode" && value === "light") {
            updated.inactiveOpacity = 1.0
            updated.terminalOpacity = 1.0
            updated.shellOpacity = 1.0
        }
        updated.useThemeOverrides = true
        root.themeSettings = updated
        if (name === "blurEnabled") root.uiBackgroundBlur = value
        root.settingsMessage = ""
    }

    function applyThemeSettings() {
        var updated = ({})
        for (var key in root.themeSettings) updated[key] = root.themeSettings[key]
        updated.useThemeOverrides = true
        root.themeSettings = updated
        settingsApplier.command = ["python3", Qt.resolvedUrl("wallpaper.py").toString().replace("file://", ""), "apply-settings", JSON.stringify(updated)]
        settingsApplier.running = true
        root.settingsMessage = "Saving settings…"
    }

    function resetThemeSettings() {
        var reset = ({})
        for (var key in root.defaultThemeSettings) reset[key] = root.defaultThemeSettings[key]
        reset.themeMode = root.themeSettings.themeMode || root.defaultThemeSettings.themeMode
        root.themeSettings = reset
        root.uiBackgroundBlur = reset.blurEnabled
        settingsApplier.command = ["python3", Qt.resolvedUrl("wallpaper.py").toString().replace("file://", ""), "reset-settings"]
        settingsApplier.running = true
        root.settingsMessage = "Restoring Omarchy defaults…"
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
        pickerSearch.searchInput.text = ""
        root.page = 1
        root.lastPage = 1
        root.selectedIndex = 0
        root.wallpapers = []
        root.wallpaperPages = ({})
        root.wallpaperPageByIndex = []
        root.statusText = ""
        if (!root.localMode && !root.sortModeLoaded) {
            root.pendingInitialLoad = true
            root.focusGallery()
            return
        }
        if (root.localMode)
            root.loadLocalWallpapers()
        else
            root.loadPage(1)
        root.focusGallery()
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
                    if (response.ok && response.result.themeSettings)
                        root.themeSettings = response.result.themeSettings
                    if (response.ok && response.result.themeSettings) {
                        root.uiBackgroundBlur = response.result.themeSettings.blurEnabled
                    }
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
        id: settingsApplier
        stdout: StdioCollector { id: settingsApplyOutput }
        stderr: StdioCollector { id: settingsApplyError }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.settingsMessage = settingsApplyError.text || settingsApplyOutput.text || "Could not save settings"
                return
            }
            try {
                var response = JSON.parse(settingsApplyOutput.text)
                if (!response.ok) throw new Error(response.error || "Could not save settings")
                if (response.result.reset)
                    root.settingsMessage = response.result.applied
                        ? "Omarchy defaults restored; theme styling removed"
                        : "Omarchy defaults saved for the next wallpaper"
                else
                    root.settingsMessage = response.result.applied
                        ? "Settings saved and applied to the active theme"
                        : "Settings saved for the next wallpaper"
            } catch (error) {
                root.settingsMessage = String(error)
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
        onVisibleChanged: if (visible) Qt.callLater(function() { root.focusGallery() })

        Region {
            id: dockBlurRegion
            item: dock
            radius: root.uiCornerRadius
        }

        Shortcut { sequence: "Escape"; onActivated: root.dismiss() }
        Shortcut {
            sequence: "Ctrl+S"
            enabled: !root.busy
            onActivated: {
                root.settingsMode = !root.settingsMode
                root.searchMode = false
                root.pageMode = false
                root.settingsMessage = ""
                if (root.settingsMode) Qt.callLater(function() { settingsPanelComponent.forceActiveFocus() })
                else Qt.callLater(function() { root.focusGallery() })
            }
        }
        Shortcut { sequence: "Alt+Left"; enabled: !root.pageMode && !root.localMode; onActivated: root.changePage(root.page - 1) }
        Shortcut { sequence: "Alt+Right"; enabled: !root.pageMode && !root.localMode; onActivated: root.changePage(root.page + 1) }
        Shortcut {
            sequence: "Alt+S"
            enabled: !root.busy && !root.pageMode
            onActivated: {
                root.searchMode = true
                pickerSearch.searchInput.text = root.query
                Qt.callLater(function() { pickerSearch.searchInput.forceActiveFocus(); pickerSearch.searchInput.selectAll() })
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
                pickerSearch.pageInput.text = ""
                Qt.callLater(function() { pickerSearch.pageInput.forceActiveFocus() })
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"

            Ui.BorderSurface {
                id: dock
                width: Math.min(parent.width - Style.gapsOut * 2, Style.space(1280))
                height: root.settingsMode
                    ? Math.min(parent.height - Style.gapsOut * 2, Style.space(600))
                    : Style.space(250)
                Behavior on height {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.bottomOffset
                radius: Math.min(root.uiCornerRadius, height / 2)
                color: root.surfaceColor
                borderSpec: root.uiBorderWidth > 0
                    ? Border.surfaceSpec("menu", "border", root.borderColor, root.uiBorderWidth)
                    : Border.none()
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.spacing.panelPadding
                    anchors.rightMargin: Style.spacing.panelPadding
                    anchors.topMargin: Style.spacing.md
                    anchors.bottomMargin: Style.spacing.md
                    spacing: Style.spacing.sm

                    PickerComponents.LocalWallpaperGallery {
                        id: localGallery
                        visible: root.localMode && !root.settingsMode
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        controller: root
                    }

                    PickerComponents.WallhavenGallery {
                        id: wallhavenGallery
                        visible: !root.localMode && !root.settingsMode
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        controller: root
                    }

                    PickerSettings.SettingsPanel {
                        id: settingsPanelComponent
                        visible: root.settingsMode
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        controller: root
                    }

                    PickerComponents.SearchBar {
                        id: pickerSearch
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        controller: root
                    }
                }
            }
        }
    }
}
