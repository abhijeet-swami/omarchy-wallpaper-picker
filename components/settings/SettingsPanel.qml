import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "." as SettingComponents

Item {
    id: settingsPanel
    required property var controller

    visible: controller.settingsMode
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true

    function applyOnEnter(event) {
        if (motionDropdown.activeFocus) return
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !controller.settingsApplying) {
            event.accepted = true
            controller.applyThemeSettings()
        }
    }

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.spacing.md

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.md

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(1)
            Text {
                text: "APPEARANCE"
                color: controller.accentColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1
            }
            Text {
                text: "Shape the desktop around this wallpaper"
                color: controller.textColor
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.weight: Font.DemiBold
            }
        }

    }

    Flickable {
        id: settingsScroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: settingsGrid.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        GridLayout {
            id: settingsGrid
            width: settingsScroll.width
            columns: width >= Style.space(760) ? 2 : 1
            columnSpacing: Style.spacing.md
            rowSpacing: Style.spacing.md

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                Layout.minimumWidth: 0
                Layout.preferredWidth: settingsGrid.columns === 2
                    ? (settingsGrid.width - settingsGrid.columnSpacing) / 3 : settingsGrid.width
                Layout.maximumWidth: Layout.preferredWidth
                spacing: Style.spacing.md

                        SettingComponents.SettingsCard {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            controller: settingsPanel.controller
                            title: "WINDOWS"

                            SettingComponents.SettingsSlider {
                                Layout.fillWidth: true
                                controller: settingsPanel.controller
                                label: "Corner radius"
                                suffix: " px"
                                value: controller.themeSettings.rounding
                                minimum: 0; maximum: 40; step: 1; integer: true
                                onMoved: controller.setThemeSetting("rounding", value)
                            }
                            SettingComponents.SettingsSlider {
                                Layout.fillWidth: true
                                controller: settingsPanel.controller
                                label: "Border width"
                                suffix: " px"
                                value: controller.themeSettings.borderWidth
                                minimum: 0; maximum: 10; step: 1; integer: true
                                onMoved: controller.setThemeSetting("borderWidth", value)
                            }
                        }

                        SettingComponents.SettingsCard {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            controller: settingsPanel.controller
                            title: "OPACITY"

                            Ui.PanelSectionHeader {
                                Layout.fillWidth: true
                                text: "WINDOWS"
                                foreground: controller.mutedColor
                            }
                            SettingComponents.SettingsSlider {
                                Layout.fillWidth: true
                                controller: settingsPanel.controller
                                label: "Inactive windows"
                                suffix: "%"
                                value: Math.round(controller.themeSettings.inactiveOpacity * 100)
                                minimum: 65; maximum: 100; step: 1; integer: true
                                onMoved: controller.setThemeSetting("inactiveOpacity", value / 100)
                            }
                            SettingComponents.SettingsToggle {
                                Layout.fillWidth: true
                                controller: settingsPanel.controller
                                label: "Match active and inactive windows"
                                                            checked: controller.themeSettings.sameWindowOpacity
                                onToggled: controller.setThemeSetting("sameWindowOpacity", !checked)
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Style.spacing.hairline
                                color: controller.borderColor
                                opacity: 0.6
                            }

                            Ui.PanelSectionHeader {
                                Layout.fillWidth: true
                                text: "TERMINALS"
                                foreground: controller.mutedColor
                            }
                            SettingComponents.SettingsSlider {
                                Layout.fillWidth: true
                                controller: settingsPanel.controller
                                label: "Terminal background opacity"
                                suffix: "%"
                                value: Math.round(controller.themeSettings.terminalOpacity * 100)
                                minimum: 65; maximum: 100; step: 1; integer: true
                                onMoved: controller.setThemeSetting("terminalOpacity", value / 100)
                            }
                        }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                Layout.minimumWidth: 0
                Layout.preferredWidth: settingsGrid.columns === 2
                    ? 2 * (settingsGrid.width - settingsGrid.columnSpacing) / 3 : settingsGrid.width
                Layout.maximumWidth: Layout.preferredWidth
                spacing: Style.spacing.md

                        SettingComponents.SettingsCard {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            controller: settingsPanel.controller
                            title: "SURFACE"
                            contentSpacing: Style.spacing.xs

                            SettingComponents.SettingsToggle {
                                Layout.fillWidth: true
                                controller: settingsPanel.controller
                                label: "Backdrop blur"
                                checked: controller.themeSettings.blurEnabled
                                onToggled: controller.setThemeSetting("blurEnabled", !checked)
                                minimumHeight: Style.space(24)
                            }
                            SettingComponents.SettingsSlider {
                                Layout.fillWidth: true
                                controller: settingsPanel.controller
                                label: "Blur strength"
                                value: controller.themeSettings.blurSize
                                minimum: 1; maximum: 20; step: 1; integer: true
                                enabled: controller.themeSettings.blurEnabled
                                onMoved: controller.setThemeSetting("blurSize", value)
                            }
                            SettingComponents.SettingsSlider {
                                Layout.fillWidth: true
                                controller: settingsPanel.controller
                                label: "Blur quality"
                                value: controller.themeSettings.blurPasses
                                minimum: 1; maximum: 6; step: 1; integer: true
                                enabled: controller.themeSettings.blurEnabled
                                onMoved: controller.setThemeSetting("blurPasses", value)
                            }
                        SettingComponents.SettingsToggle {
                            Layout.fillWidth: true
                            controller: settingsPanel.controller
                            label: "Blur noise"
                            checked: controller.themeSettings.noiseEnabled
                            enabled: controller.themeSettings.blurEnabled
                            onToggled: controller.setThemeSetting("noiseEnabled", !checked)
                            minimumHeight: Style.space(24)
                        }
                        SettingComponents.SettingsSlider {
                            Layout.fillWidth: true
                            controller: settingsPanel.controller
                            label: "Noise strength"
                            suffix: "%"
                            value: Math.round(controller.themeSettings.noiseStrength * 1000) / 10
                            minimum: 0; maximum: 100; step: 0.1; integer: false
                            enabled: controller.themeSettings.blurEnabled && controller.themeSettings.noiseEnabled
                            onMoved: controller.setThemeSetting("noiseStrength", value / 100)
                        }
                            SettingComponents.SettingsToggle {
                                Layout.fillWidth: true
                                controller: settingsPanel.controller
                                label: "Window shadow"
                                checked: controller.themeSettings.shadowEnabled
                                onToggled: controller.setThemeSetting("shadowEnabled", !checked)
                                minimumHeight: Style.space(24)
                            }
                            SettingComponents.SettingsSlider {
                                Layout.fillWidth: true
                                controller: settingsPanel.controller
                                label: "Shadow size"
                                suffix: " px"
                                value: controller.themeSettings.shadowRange
                                minimum: 0; maximum: 40; step: 1; integer: true
                                enabled: controller.themeSettings.shadowEnabled
                                onMoved: controller.setThemeSetting("shadowRange", value)
                            }
                        }

                        SettingComponents.SettingsCard {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            controller: settingsPanel.controller
                            showTitle: false
                            verticalPadding: Style.space(14)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.spacing.md

                                Ui.PanelSectionHeader {
                                    Layout.fillWidth: true
                                    text: "MOTION"
                                    foreground: controller.textColor
                                }

                                SettingComponents.MotionDropdown {
                                    id: motionDropdown
                                    Layout.preferredWidth: Style.space(200)
                                    Layout.minimumWidth: Style.space(160)
                                    Layout.maximumWidth: Style.space(240)
                                    controller: settingsPanel.controller
                                    value: controller.themeSettings.animationPreset
                                    options: [
                                        { value: "fast", label: "Fast" },
                                        { value: "fluid", label: "Fluid" },
                                        { value: "smooth", label: "Smooth" },
                                        { value: "vertical", label: "Vertical" },
                                        { value: "none", label: "No animation" }
                                    ]
                                    onChanged: controller.setThemeSetting("animationPreset", value)
                                }
                            }
                        }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Style.spacing.sm
        spacing: Style.spacing.sm
        Text {
            Layout.fillWidth: true
            text: "Changes apply to your active Omarchy theme."
            color: controller.mutedColor
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
        }
        Ui.Button {
            text: "Reset"
            enabled: !controller.settingsApplying
            bordered: true
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
            onClicked: controller.resetThemeSettings()
        }
        Ui.Button {
            text: controller.settingsApplying ? "Applying…" : "Apply"
            enabled: !controller.settingsApplying
            background: controller.accentColor
            foreground: controller.dockColor
            accent: controller.dockColor
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
            onClicked: controller.applyThemeSettings()
        }
    }
    }

    Text {
        anchors.top: parent.top
        anchors.topMargin: Style.spacing.md
        anchors.right: parent.right
        anchors.rightMargin: Style.spacing.panelPadding
        width: Style.space(240)
        text: controller.settingsMessage || "ENTER APPLY  ·  CTRL+S BACK"
        color: controller.settingsMessage ? controller.accentColor : controller.mutedColor
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
        wrapMode: Text.WordWrap
    }
}
