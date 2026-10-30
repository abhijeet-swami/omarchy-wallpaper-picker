import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

Item {
    id: root

    required property var controller
    property string label: ""
    property string suffix: ""
    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property real step: 0.1
    property bool integer: false
    property bool enabled: true

    signal moved(real value)

    implicitHeight: Style.space(48)
    activeFocusOnTab: enabled

    function clampValue(next) {
        next = Math.max(root.minimum, Math.min(root.maximum, next))
        if (root.integer) next = Math.round(next)
        else if (root.step > 0) next = Math.round(next / root.step) * root.step
        return Number(next.toFixed(3))
    }

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
        if (!root.enabled) return
        var next = root.value
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) next -= root.step
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) next += root.step
        else if (event.key === Qt.Key_Home) next = root.minimum
        else if (event.key === Qt.Key_End) next = root.maximum
        else return
        event.accepted = true
        root.moved(root.clampValue(next))
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(2)

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: root.label
                color: root.enabled ? root.controller.textColor : root.controller.mutedColor
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
            }
            Text {
                text: root.integer ? String(Math.round(root.value)) + root.suffix
                                   : Number(root.value).toFixed(2).replace(/0+$/, "").replace(/\.$/, "") + root.suffix
                color: root.controller.textColor
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.weight: Font.DemiBold
            }
        }

        Ui.PanelSlider {
            Layout.fillWidth: true
            Layout.fillHeight: true
            enabled: root.enabled
            value: root.value
            minimum: root.minimum
            maximum: root.maximum
            step: root.step
            integer: root.integer
            trackColor: Style.normalFillFor(Commons.Color.foreground, Commons.Color.accent)
            fillColor: root.controller.accentColor
            knobColor: root.controller.textColor
            tickColor: root.controller.surfaceColor
            onMoved: function(next) {
                root.forceActiveFocus()
                root.moved(root.clampValue(next))
            }
        }
    }
}
