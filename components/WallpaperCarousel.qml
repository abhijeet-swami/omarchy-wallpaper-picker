import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons

Item {
    id: carousel
    required property var controller
    property bool localMode: false

    visible: !controller.settingsMode
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    focus: true
    property real itemStep: 190

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
        if (controller.searchMode || controller.pageMode || controller.busy) return
        if (event.key === Qt.Key_Left) {
            controller.moveSelection(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            controller.moveSelection(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            controller.applySelected()
            event.accepted = true
        }
    }

    WheelHandler {
        target: carousel
        enabled: !controller.localMode && !controller.searchMode && !controller.pageMode && !controller.busy
        onWheel: function(event) {
            var delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
            if (delta !== 0) {
                controller.moveSelection(delta < 0 ? 1 : -1)
                event.accepted = true
            }
        }
    }

    Repeater {
        model: controller.wallpapers

        delegate: Item {
            id: wallpaperDelegate
            required property var modelData
            required property int index
            readonly property int distance: {
                var count = controller.wallpapers.length
                if (!count) return 0
                if (!controller.localMode) return index - controller.selectedIndex
                var forward = ((index - controller.selectedIndex) % count + count) % count
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
                radius: Math.min(controller.uiCornerRadius, height / 2)
                color: controller.surfaceColor
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
                            ? controller.imageSource(wallpaperDelegate.modelData.thumb)
                            : ""
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: card.radius
                    color: "transparent"
                    border.color: wallpaperDelegate.selected ? controller.selectedBorderColor : controller.unselectedBorderColor
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
                        controller.selectedIndex = wallpaperDelegate.index
                        controller.clearStatus()
                        controller.focusGallery()
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
        text: controller.localMode
            ? String(controller.wallpapers.length) + " WALLPAPERS"
            : "PAGE " + controller.page + " / " + controller.lastPage
        color: controller.mutedColor
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
        visible: controller.prefetching || (controller.busy && controller.helperCommand.length > 2 && ["search", "local-list", "download", "apply", "apply-local"].indexOf(controller.helperCommand[2]) >= 0)

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
                color: controller.accentColor
                opacity: 1 - index * 0.09
                x: loadingSpinner.width / 2 - width / 2 + Math.cos(index * Math.PI / 4) * 13
                y: loadingSpinner.height / 2 - height / 2 + Math.sin(index * Math.PI / 4) * 13
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !controller.busy && controller.wallpapers.length === 0
        text: controller.statusText || "No wallpapers found"
        color: controller.textColor
        font.pixelSize: 14
    }
}
