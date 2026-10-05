// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Popup {
    id: root
    objectName: "addSourceDialog"

    // Empty sourceId means Add mode. Set both before calling open() to edit
    // an existing source instead.
    property string sourceId: ""
    property bool isEditMode: false

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 0
    closePolicy: Popup.CloseOnEscape

    readonly property var sourceTypes: ["mqtt", "homeassistant", "webhook", "poller", "filewatcher"]

    function clearConfigFields() {
        brokerField.text = ""
        topicField.text = ""
        mqttUserField.text = ""
        mqttPassField.text = ""
        haUrlField.text = ""
        haTokenField.text = ""
        pollerUrlField.text = ""
        pollerIntervalField.text = "60"
        watcherPathField.text = ""
        watcherPatternField.text = "*"
    }

    // Fills in every field the backend does not mask. A masked field (see
    // ApiTypes.h's SourceDto::config) is left blank. The user must retype
    // it to change it, and retyping it is the only way to keep it.
    function prefillConfig(type, config) {
        clearConfigFields()
        if (type === "mqtt") {
            brokerField.text = config.host !== undefined
                ? (config.host + (config.port !== undefined ? ":" + config.port : ""))
                : ""
            topicField.text = config.topic || ""
            mqttUserField.text = config.username || ""
        } else if (type === "homeassistant") {
            haUrlField.text = config.url || ""
        } else if (type === "poller") {
            pollerUrlField.text = config.url || ""
            pollerIntervalField.text = config.interval_secs !== undefined ? String(config.interval_secs) : "60"
        } else if (type === "filewatcher") {
            watcherPathField.text = config.path || ""
            watcherPatternField.text = config.pattern || "*"
        }
        // webhook has no fields at all: the backend generates its URL.
    }

    onOpened: {
        errorText.text = ""
        if (root.isEditMode) {
            const s = SourceModel.sourceById(root.sourceId)
            nameField.text = s.sourceName || ""
            const idx = root.sourceTypes.indexOf(s.sourceType)
            typeCombo.currentIndex = idx >= 0 ? idx : 0
            prefillConfig(s.sourceType || "", s.sourceConfig || {})
        } else {
            nameField.text = ""
            typeCombo.currentIndex = 0
            clearConfigFields()
        }
        nameField.forceActiveFocus()
    }

    Connections {
        target: SourceModel
        function onCreateSourceFailed(message) { errorText.text = message }
        function onCreateSourceSucceeded() { root.close() }
        function onUpdateSourceFailed(message) { errorText.text = message }
        function onUpdateSourceSucceeded() { root.close() }
    }

    readonly property string selectedType: sourceTypes[typeCombo.currentIndex]

    background: Rectangle {
        color: Theme.surfaceCard
        border.color: Theme.border
        radius: Theme.radiusM
    }

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }

    contentItem: Item {
        implicitWidth: 460
        implicitHeight: content.implicitHeight + Theme.spaceXl * 2

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spaceXl }
            spacing: Theme.spaceM

            Row {
                spacing: Theme.spaceS
                TblIcon { source: "qrc:/tb/broadcast.svg"; size: 20; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: root.isEditMode ? qsTr("Edit Source") : qsTr("Add Source")
                    font.pixelSize: Theme.fontL
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { width: 1; height: Theme.spaceXs }

            Text { text: qsTr("Type"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
            ComboBox {
                id: typeCombo
                objectName: "sourceTypeCombo"
                width: parent.width; height: 36
                enabled: !root.isEditMode
                opacity: enabled ? 1.0 : 0.6
                model: ["MQTT", "Home Assistant", "Webhook", "Poller", "File Watcher"]

                background: Rectangle {
                    color: Theme.surface
                    border.color: typeCombo.pressed ? Theme.accent : Theme.border
                    radius: Theme.radiusS
                }
                contentItem: Text {
                    leftPadding: Theme.spaceM
                    text: typeCombo.displayText
                    font.pixelSize: Theme.fontS
                    color: Theme.textPrimary
                    verticalAlignment: Text.AlignVCenter
                }
                indicator: Text {
                    x: typeCombo.width - width - Theme.spaceM
                    text: "▾"; font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Text {
                visible: root.isEditMode
                text: qsTr("Type cannot be changed after creation.")
                font.pixelSize: Theme.fontXs
                color: Theme.textDisabled
            }

            Text { text: qsTr("Name *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
            TextField {
                id: nameField
                objectName: "sourceNameField"
                width: parent.width; height: 36
                placeholderText: qsTr("e.g. Living room sensor")
                color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                background: Rectangle {
                    color: Theme.surface
                    border.color: nameField.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radiusS
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            Column {
                visible: root.selectedType === "mqtt"
                width: parent.width
                spacing: Theme.spaceM

                Text { text: qsTr("Broker URL *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField {
                    id: brokerField
                    objectName: "sourceMqttBrokerField"
                    width: parent.width; height: 36
                    placeholderText: "mqtt://192.168.1.100:1883"
                    color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                    font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                    background: Rectangle { color: Theme.surface; border.color: brokerField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS }
                }

                Text { text: qsTr("Topic *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField {
                    id: topicField
                    objectName: "sourceMqttTopicField"
                    width: parent.width; height: 36
                    placeholderText: "sensors/#"
                    color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                    font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                    background: Rectangle { color: Theme.surface; border.color: topicField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS }
                }

                Row {
                    width: parent.width; spacing: Theme.spaceM
                    Column {
                        width: (parent.width - Theme.spaceM) / 2; spacing: Theme.spaceS
                        Text { text: qsTr("Username"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField {
                            id: mqttUserField
                            objectName: "sourceMqttUserField"
                            width: parent.width; height: 36
                            color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                            font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                            background: Rectangle { color: Theme.surface; border.color: mqttUserField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS }
                        }
                    }
                    Column {
                        width: (parent.width - Theme.spaceM) / 2; spacing: Theme.spaceS
                        Text { text: qsTr("Password"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField {
                            id: mqttPassField
                            objectName: "sourceMqttPassField"
                            width: parent.width; height: 36
                            echoMode: TextInput.Password
                            color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                            font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                            background: Rectangle { color: Theme.surface; border.color: mqttPassField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS }
                        }
                    }
                }
            }

            Column {
                visible: root.selectedType === "homeassistant"
                width: parent.width; spacing: Theme.spaceM

                Text { text: qsTr("HA URL *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField {
                    id: haUrlField
                    width: parent.width; height: 36
                    placeholderText: "http://192.168.1.100:8123"
                    color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                    font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                    background: Rectangle { color: Theme.surface; border.color: haUrlField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS }
                }

                Text { text: qsTr("Long-lived access token *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField {
                    id: haTokenField
                    width: parent.width; height: 36
                    echoMode: TextInput.Password
                    color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                    font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                    background: Rectangle { color: Theme.surface; border.color: haTokenField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS }
                }
            }

            Text {
                visible: root.selectedType === "webhook"
                text: qsTr("The backend will generate a webhook URL after creation.")
                font.pixelSize: Theme.fontXs
                color: Theme.textDisabled
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Column {
                visible: root.selectedType === "poller"
                width: parent.width; spacing: Theme.spaceM

                Text { text: qsTr("URL to poll *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField {
                    id: pollerUrlField
                    width: parent.width; height: 36
                    placeholderText: "https://api.example.com/status"
                    color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                    font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                    background: Rectangle { color: Theme.surface; border.color: pollerUrlField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS }
                }

                Text { text: qsTr("Interval (seconds)"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField {
                    id: pollerIntervalField
                    width: parent.width; height: 36
                    text: "60"
                    inputMethodHints: Qt.ImhDigitsOnly
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                    background: Rectangle { color: Theme.surface; border.color: pollerIntervalField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS }
                }
            }

            Column {
                visible: root.selectedType === "filewatcher"
                width: parent.width; spacing: Theme.spaceM

                Text { text: qsTr("Directory path *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField {
                    id: watcherPathField
                    width: parent.width; height: 36
                    placeholderText: "/var/data/drops"
                    color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                    font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                    background: Rectangle { color: Theme.surface; border.color: watcherPathField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS }
                }

                Text { text: qsTr("File pattern"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField {
                    id: watcherPatternField
                    width: parent.width; height: 36
                    text: "*"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                    background: Rectangle { color: Theme.surface; border.color: watcherPatternField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS }
                }
            }

            Text {
                id: errorText
                objectName: "addSourceErrorText"
                visible: text.length > 0
                width: parent.width
                color: Theme.error
                font.pixelSize: Theme.fontXs
                wrapMode: Text.WordWrap
            }

            Item { width: 1; height: Theme.spaceXs }

            Row {
                layoutDirection: Qt.RightToLeft
                spacing: Theme.spaceS
                width: parent.width

                Rectangle {
                    width: 80; height: 32; radius: Theme.radiusS
                    color: addMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent
                    enabled: nameField.text.trim().length > 0

                    Text {
                        anchors.centerIn: parent
                        text: root.isEditMode ? qsTr("Save") : qsTr("Add")
                        font.pixelSize: Theme.fontS; font.weight: Font.Medium
                        color: parent.enabled ? Theme.textOnAccent : Theme.textDisabled
                    }

                    MouseArea {
                        id: addMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const t = root.selectedType
                            let config = {}
                            if (t === "mqtt") {
                                // Backend's MqttSourceConfig wants separate host and port
                                // fields, not a single broker URL. Split it here so the
                                // single-field UX above can stay as-is.
                                let broker = brokerField.text.trim().replace(/^mqtts?:\/\//, "")
                                let host = broker
                                let port = 1883
                                const colonIdx = broker.lastIndexOf(":")
                                if (colonIdx > 0) {
                                    host = broker.substring(0, colonIdx)
                                    port = parseInt(broker.substring(colonIdx + 1)) || 1883
                                }
                                config = { host: host, port: port, topic: topicField.text.trim() }
                                if (mqttUserField.text) config.username = mqttUserField.text
                                if (mqttPassField.text) config.password = mqttPassField.text
                            } else if (t === "homeassistant") {
                                config = { url: haUrlField.text.trim(), access_token: haTokenField.text }
                            } else if (t === "poller") {
                                config = { url: pollerUrlField.text.trim(),
                                           interval_secs: parseInt(pollerIntervalField.text) || 60 }
                            } else if (t === "filewatcher") {
                                config = { path: watcherPathField.text.trim(),
                                           pattern: watcherPatternField.text.trim() || "*" }
                            }
                            errorText.text = ""
                            if (root.isEditMode)
                                SourceModel.updateSource(root.sourceId, nameField.text.trim(), t, config)
                            else
                                SourceModel.createSource(nameField.text.trim(), t, config)
                        }
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                Rectangle {
                    width: 80; height: 32; radius: Theme.radiusS
                    color: cancelMouse.containsMouse ? Theme.surfaceHover : "transparent"
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Cancel")
                        font.pixelSize: Theme.fontS; color: Theme.textPrimary
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
            }
        }
    }
}
