import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

Ui.BorderSurface {
    id: root

    required property var controller
    property string title: ""
    property bool showTitle: true
    property int contentSpacing: Style.spacing.sm
    property int verticalPadding: Style.spacing.panelPadding
    default property alias content: sectionContent.data

    radius: Style.cornerRadius
    color: controller.surfaceColor
    borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, Math.max(1, Style.space(1)))
    implicitWidth: sectionContent.implicitWidth + Style.spacing.panelPadding * 2
    implicitHeight: sectionContent.implicitHeight + root.verticalPadding * 2

    ColumnLayout {
        id: sectionContent
        anchors.fill: parent
        anchors.leftMargin: Style.spacing.panelPadding
        anchors.rightMargin: Style.spacing.panelPadding
        anchors.topMargin: root.verticalPadding
        anchors.bottomMargin: root.verticalPadding
        spacing: root.contentSpacing

        Ui.PanelSectionHeader {
            visible: root.showTitle
            Layout.fillWidth: true
            text: root.title
            foreground: root.controller.textColor
        }
    }
}
