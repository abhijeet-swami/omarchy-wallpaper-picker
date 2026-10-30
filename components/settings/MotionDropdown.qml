import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

Item {
    id: root

    required property var controller
    property var options: []
    property string value: ""
    readonly property bool popupOpen: popup.opened
    readonly property var popupBorderSpec: Border.localOrSurfaceSpec(
        "popups", "border", Commons.Color.popups.border, Commons.Color.popups.border, Style.normalBorderWidth)

    signal changed(string value)

    implicitWidth: Style.space(200)
    implicitHeight: Style.spacing.controlHeight
    activeFocusOnTab: true

    function optionValue(option) {
        return (option && typeof option === "object") ? String(option.value) : String(option)
    }

    function optionLabel(option) {
        return (option && typeof option === "object") ? String(option.label) : String(option)
    }

    function currentLabel() {
        for (var i = 0; i < options.length; i++) {
            if (optionValue(options[i]) === value) return optionLabel(options[i])
        }
        return value
    }

    Ui.BorderSurface {
        id: trigger
        anchors.fill: parent
        radius: Style.cornerRadius
        color: Style.controlFill(activeFocus, false, root.controller.textColor, root.controller.accentColor)
        borderSpec: Border.controlSpec(activeFocus ? "focus" : "normal", root.controller.textColor, root.controller.accentColor)
        activeFocusOnTab: true

        Text {
            anchors.left: parent.left
            anchors.right: chevron.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: trigger.borderLeft + Style.spacing.controlPaddingX
            anchors.rightMargin: Style.spacing.md
            text: root.currentLabel()
            color: root.controller.textColor
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
        }

        Text {
            id: chevron
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: trigger.borderRight + Style.spacing.controlGap
            text: "󰅀"
            color: Qt.darker(root.controller.textColor, 1.2)
            font.family: Style.font.family
            font.pixelSize: Style.font.body
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                trigger.forceActiveFocus()
                popup.opened ? popup.close() : popup.open()
            }
        }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
                popup.opened ? popup.close() : popup.open()
                event.accepted = true
            } else if (event.key === Qt.Key_Escape && popup.opened) {
                popup.close()
                event.accepted = true
            }
        }

        Popup {
            id: popup
            x: 0
            y: -height - Style.spacing.xxs
            width: trigger.width
            implicitHeight: Math.min(
                root.options.length * Style.spacing.popupRowHeight
                    + Math.max(0, root.options.length - 1) * Style.spacing.labelGap + Style.spacing.xxs,
                Style.spacing.popupRowHeight * 5 + 4 * Style.spacing.labelGap + Style.spacing.xxs)
            padding: Style.spacing.hairline
            leftPadding: Border.left(root.popupBorderSpec) + Style.spacing.hairline
            rightPadding: Border.right(root.popupBorderSpec) + Style.spacing.hairline
            topPadding: Border.top(root.popupBorderSpec) + Style.spacing.hairline
            bottomPadding: Border.bottom(root.popupBorderSpec) + Style.spacing.hairline
            focus: true

            background: Ui.BorderSurface {
                color: Commons.Color.popups.background
                borderSpec: root.popupBorderSpec
                radius: Style.cornerRadius
            }

            onOpened: {
                optionList.currentIndex = optionList.indexForValue(root.value)
                optionList.forceActiveFocus()
            }

            contentItem: ListView {
                id: optionList
                spacing: Style.spacing.labelGap
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.options
                currentIndex: -1
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        popup.close()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                        var delta = event.key === Qt.Key_Down ? 1 : -1
                        currentIndex = Math.max(0, Math.min(root.options.length - 1, currentIndex + delta))
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        selectCurrent()
                        event.accepted = true
                    }
                }

                function indexForValue(selectedValue) {
                    for (var i = 0; i < root.options.length; i++) {
                        if (root.optionValue(root.options[i]) === selectedValue) return i
                    }
                    return -1
                }

                function selectCurrent() {
                    if (currentIndex < 0 || currentIndex >= root.options.length) return
                    var selectedValue = root.optionValue(root.options[currentIndex])
                    root.value = selectedValue
                    root.changed(selectedValue)
                    popup.close()
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: optionList.width
                    height: Style.spacing.popupRowHeight
                    color: index === optionList.currentIndex
                        ? Style.hoverFillFor(root.controller.textColor, root.controller.accentColor)
                        : "transparent"

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: Style.spacing.controlPaddingX
                        anchors.rightMargin: Style.spacing.controlPaddingX
                        text: root.optionLabel(modelData)
                        color: root.controller.textColor
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: optionList.currentIndex = parent.index
                        onClicked: optionList.selectCurrent()
                    }
                }
            }
        }
    }
}
