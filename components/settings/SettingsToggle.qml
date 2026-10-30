import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui

Item {
    id: root

    required property var controller
    property string label: ""
    property string detail: ""
    property bool checked: false
    property bool enabled: true
    property int minimumHeight: Style.space(32)

    signal toggled()

    implicitHeight: Math.max(root.minimumHeight, contentRow.implicitHeight)
    activeFocusOnTab: enabled

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
        if (root.enabled && event.key === Qt.Key_Space) {
            event.accepted = true
            root.toggled()
        }
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        spacing: Style.spacing.md

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(1)
            Text {
                Layout.fillWidth: true
                text: root.label
                color: root.enabled ? root.controller.textColor : root.controller.mutedColor
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
            }
            Text {
                visible: root.detail.length > 0
                Layout.fillWidth: true
                text: root.detail
                color: root.controller.mutedColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
            }
        }

        Ui.ToggleSwitch {
            id: toggle
            checked: root.checked
            enabled: root.enabled
            interactive: true
            cursorRing: false
            trackHeight: Style.space(20)
            onToggled: root.toggled()
        }
    }
}
