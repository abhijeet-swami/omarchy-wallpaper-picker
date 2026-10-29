import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

Rectangle {
    id: searchBar
    required property var controller
    property alias searchInput: searchField
    property alias pageInput: pageField
    visible: !controller.settingsMode
    Layout.fillWidth: true
    Layout.preferredHeight: 48
    radius: Math.min(controller.uiCornerRadius, height / 2)
    color: Qt.darker(controller.surfaceColor, 1.08)
    border.color: controller.searchMode || controller.pageMode ? controller.accentColor : controller.borderColor
    border.width: controller.uiBorderWidth

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
                border.color: controller.mutedColor
            }
            Rectangle {
                x: 14; y: 14
                width: 8; height: 2
                radius: 1
                rotation: 45
                color: controller.mutedColor
            }
        }

        TextField {
            id: searchField
            visible: !controller.pageMode
                enabled: !controller.busy
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: controller.query
            placeholderText: controller.localMode ? "Search saved wallpapers…" : "Search Wallhaven…"
            color: controller.textColor
            placeholderTextColor: controller.mutedColor
            selectionColor: Commons.Color.lock.selection
            selectedTextColor: controller.textColor
            background: Item {}
            font.pixelSize: 14
            onActiveFocusChanged: if (activeFocus) {
                controller.searchMode = true
                controller.pageMode = false
                text = controller.query
            }
            onAccepted: {
                controller.query = text.trim()
                controller.page = 1
                controller.lastPage = 1
                controller.selectedIndex = 0
                controller.wallpapers = []
                controller.wallpaperPages = ({})
                controller.wallpaperPageByIndex = []
                controller.pendingBoundaryDirection = 0
                controller.clearStatus()
                controller.searchMode = false
                controller.focusGallery()
                if (controller.localMode)
                    controller.loadLocalWallpapers()
                else {
                    controller.querySortMode = "relevance"
                    controller.loadPage(1)
                }
            }
        }

        TextField {
            id: pageField
            visible: controller.pageMode
                enabled: !controller.busy
            Layout.fillWidth: true
            Layout.fillHeight: true
            placeholderText: "Page number…"
            color: controller.textColor
            placeholderTextColor: controller.mutedColor
            selectionColor: Commons.Color.lock.selection
            selectedTextColor: controller.textColor
            background: Item {}
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: 1; top: 999999 }
            font.pixelSize: 14
            onAccepted: {
                var target = Number(text)
                controller.pageMode = false
                controller.focusGallery()
                controller.changePage(target)
                text = ""
            }
        }

        Text {
            visible: !controller.query.trim() && !controller.localMode
            text: controller.sortLabel(controller.sortMode)
            color: controller.accentColor
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
            MouseArea {
                anchors.fill: parent
                enabled: !controller.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: controller.cycleSortMode()
            }
        }
        Text {
            visible: controller.localMode && !controller.query.trim()
            text: "LOCAL WALLPAPERS"
            color: controller.accentColor
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }
        Text {
            visible: !!controller.query.trim() && !controller.localMode
            text: controller.querySortMode === "relevance" ? "RELEVANCE" : "TOP RESULTS"
            color: controller.querySortMode === "relevance" ? controller.mutedColor : controller.accentColor
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
            MouseArea {
                anchors.fill: parent
                enabled: !controller.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: controller.cycleSortMode()
            }
        }
        Text {
            visible: controller.localMode && !!controller.query.trim()
            text: "LOCAL SEARCH"
            color: controller.mutedColor
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }

        Text {
            visible: !!controller.statusText
            text: controller.statusText
            color: Commons.Color.urgent
            font.pixelSize: 11
            elide: Text.ElideRight
            Layout.maximumWidth: 230
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 20
            color: controller.borderColor
            opacity: 0.6
        }

        Text {
            text: controller.wallpapers.length
                ? String(controller.selectedIndex + 1).padStart(2, "0") + " / " + String(controller.wallpapers.length).padStart(2, "0")
                : (controller.busy ? "…" : "00 / 00")
            color: controller.textColor
            font.pixelSize: 12
            font.family: "monospace"
        }
    }
}
