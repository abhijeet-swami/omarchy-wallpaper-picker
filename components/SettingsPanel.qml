import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

ColumnLayout {
    id: settingsPanel
    required property var controller

    visible: controller.settingsMode
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 4
    focus: true

    function applyOnEnter(event) {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                && !controller.settingsApplying) {
            event.accepted = true
            controller.applyThemeSettings()
        }
    }

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "THEME APPEARANCE"
            color: controller.textColor
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.letterSpacing: 0.7
        }
        Item { Layout.fillWidth: true }
        Text {
            text: controller.settingsMessage || "CTRL+S TO RETURN"
            color: controller.settingsMessage ? controller.accentColor : controller.mutedColor
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 18
        CheckBox {
            text: "Blur"
            checked: controller.themeSettings.blurEnabled
            palette.highlight: controller.accentColor
            palette.text: controller.textColor
            onToggled: controller.setThemeSetting("blurEnabled", checked)
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
        }
        CheckBox {
            text: "Shadow"
            checked: controller.themeSettings.shadowEnabled
            palette.highlight: controller.accentColor
            palette.text: controller.textColor
            onToggled: controller.setThemeSetting("shadowEnabled", checked)
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
        }
        CheckBox {
            text: "Terminal active/inactive same"
            checked: controller.themeSettings.terminalSameOpacity
            palette.highlight: controller.accentColor
            palette.text: controller.textColor
            onToggled: controller.setThemeSetting("terminalSameOpacity", checked)
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Text { text: "WINDOW ANIMATION"; color: controller.mutedColor; font.pixelSize: 10 }
        ComboBox {
            id: animationPresetField
            Layout.preferredWidth: 190
            model: controller.animationPresetNames
            currentIndex: Math.max(0, controller.animationPresetIds.indexOf(controller.themeSettings.animationPreset))
            palette.highlight: controller.accentColor
            palette.text: controller.textColor
            onActivated: controller.setThemeSetting("animationPreset", controller.animationPresetIds[index])
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
        }
        Item { Layout.fillWidth: true }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 3
        columnSpacing: 24
        rowSpacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Text { text: "BLUR SIZE"; color: controller.mutedColor; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: String(controller.themeSettings.blurSize); color: controller.textColor; font.pixelSize: 10 }
            }
            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                palette.highlight: controller.accentColor
                from: 1; to: 20; stepSize: 1
                value: controller.themeSettings.blurSize
                enabled: controller.themeSettings.blurEnabled
                onMoved: controller.setThemeSetting("blurSize", Math.round(value))
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Text { text: "BLUR PASSES"; color: controller.mutedColor; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: String(controller.themeSettings.blurPasses); color: controller.textColor; font.pixelSize: 10 }
            }
            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                palette.highlight: controller.accentColor
                from: 1; to: 6; stepSize: 1
                value: controller.themeSettings.blurPasses
                enabled: controller.themeSettings.blurEnabled
                onMoved: controller.setThemeSetting("blurPasses", Math.round(value))
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Text { text: "UI ROUNDING"; color: controller.mutedColor; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: String(controller.themeSettings.rounding) + " px"; color: controller.textColor; font.pixelSize: 10 }
            }
            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                palette.highlight: controller.accentColor
                from: 0; to: 40; stepSize: 1
                value: controller.themeSettings.rounding
                onMoved: controller.setThemeSetting("rounding", Math.round(value))
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Text { text: "BORDER WIDTH"; color: controller.mutedColor; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: String(controller.themeSettings.borderWidth) + " px"; color: controller.textColor; font.pixelSize: 10 }
            }
            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                palette.highlight: controller.accentColor
                from: 0; to: 10; stepSize: 1
                value: controller.themeSettings.borderWidth
                onMoved: controller.setThemeSetting("borderWidth", Math.round(value))
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Text { text: "SHADOW RANGE"; color: controller.mutedColor; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: String(controller.themeSettings.shadowRange) + " px"; color: controller.textColor; font.pixelSize: 10 }
            }
            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                palette.highlight: controller.accentColor
                from: 0; to: 40; stepSize: 1
                value: controller.themeSettings.shadowRange
                enabled: controller.themeSettings.shadowEnabled
                onMoved: controller.setThemeSetting("shadowRange", Math.round(value))
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Text { text: "INACTIVE WINDOW OPACITY"; color: controller.mutedColor; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: Math.round(controller.themeSettings.inactiveOpacity * 100) + "%"; color: controller.textColor; font.pixelSize: 10 }
            }
            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                palette.highlight: controller.accentColor
                from: 0.65; to: 1.0; stepSize: 0.01
                value: controller.themeSettings.inactiveOpacity
                onMoved: controller.setThemeSetting("inactiveOpacity", Number(value.toFixed(2)))
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Text { text: "TERMINAL OPACITY"; color: controller.mutedColor; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: Math.round(controller.themeSettings.terminalOpacity * 100) + "%"; color: controller.textColor; font.pixelSize: 10 }
            }
            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                palette.highlight: controller.accentColor
                from: 0.65; to: 1.0; stepSize: 0.01
                value: controller.themeSettings.terminalOpacity
                onMoved: controller.setThemeSetting("terminalOpacity", Number(value.toFixed(2)))
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Text { text: "OMARCHY SHELL OPACITY"; color: controller.mutedColor; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: Math.round(controller.themeSettings.shellOpacity * 100) + "%"; color: controller.textColor; font.pixelSize: 10 }
            }
            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                palette.highlight: controller.accentColor
                from: 0.1; to: 1.0; stepSize: 0.01
                value: controller.themeSettings.shellOpacity
                onMoved: controller.setThemeSetting("shellOpacity", Number(value.toFixed(2)))
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        Button {
            text: "Reset to defaults"
            enabled: !controller.settingsApplying
            palette.button: Qt.darker(controller.surfaceColor, 1.08)
            palette.buttonText: controller.textColor
            palette.highlight: controller.accentColor
            onClicked: controller.resetThemeSettings()
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
        }
        Button {
            text: controller.settingsApplying ? "Applying…" : "Apply"
            enabled: !controller.settingsApplying
            palette.button: controller.accentColor
            palette.buttonText: controller.dockColor
            palette.highlight: controller.accentColor
            onClicked: controller.applyThemeSettings()
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) { settingsPanel.applyOnEnter(event) }
        }
    }
}
