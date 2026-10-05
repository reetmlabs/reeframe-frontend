// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic
import "../components"

Popup {
    id: root
    objectName: "addDestinationDialog"

    // Empty destinationId means Add mode. Set both before calling open() to
    // edit an existing destination instead.
    property string destinationId: ""
    property bool isEditMode: false

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 0
    closePolicy: Popup.CloseOnEscape

    readonly property var destinationTypes: ["s3", "sftp", "smb", "local", "telegram",
                                              "email", "slack", "sms", "webhook"]

    function clearConfigFields() {
        s3BucketField.text = ""; s3RegionField.text = ""; s3KeyField.text = ""; s3SecretField.text = ""; s3PrefixField.text = ""
        s3EndpointField.text = ""; s3PathStyleToggle.checked = false
        sftpHostField.text = ""; sftpPortField.text = "22"; sftpUserField.text = ""; sftpPassField.text = ""; sftpPathField.text = ""
        smbShareField.text = ""; smbUserField.text = ""; smbPassField.text = ""; smbPathField.text = ""
        localPathField.text = ""
        tgTokenField.text = ""; tgChatField.text = ""
        emailHostField.text = ""; emailPortField.text = "587"; emailUserField.text = ""; emailPassField.text = ""; emailToField.text = ""
        slackUrlField.text = ""
        smsKeyField.text = ""; smsFromField.text = ""; smsToField.text = ""
        webhookUrlField.text = ""; webhookMethodCombo.currentIndex = 0
    }

    // Fills in every field the backend does not mask. A masked field (see
    // ApiTypes.h's DestinationDto::config) is left blank. The user must
    // retype it to change it, and retyping it is the only way to keep it.
    function prefillConfig(type, config) {
        clearConfigFields()
        if (type === "s3") {
            s3BucketField.text = config.bucket || ""
            s3RegionField.text = config.region || ""
            s3KeyField.text = config.access_key_id || ""
            s3PrefixField.text = config.prefix || ""
            s3EndpointField.text = config.endpoint || ""
            s3PathStyleToggle.checked = config.path_style_access || false
        } else if (type === "sftp") {
            sftpHostField.text = config.host || ""
            sftpPortField.text = config.port !== undefined ? String(config.port) : "22"
            sftpUserField.text = config.username || ""
            sftpPathField.text = config.path || ""
        } else if (type === "smb") {
            smbShareField.text = config.share || ""
            smbUserField.text = config.username || ""
            smbPathField.text = config.path || ""
        } else if (type === "local") {
            localPathField.text = config.path || ""
        } else if (type === "telegram") {
            tgChatField.text = config.chat_id || ""
        } else if (type === "email") {
            emailHostField.text = config.smtp_host || ""
            emailPortField.text = config.smtp_port !== undefined ? String(config.smtp_port) : "587"
            emailUserField.text = config.username || ""
            emailToField.text = config.to || ""
        } else if (type === "sms") {
            smsFromField.text = config.from || ""
            smsToField.text = config.to || ""
        } else if (type === "webhook") {
            webhookUrlField.text = config.url || ""
            const midx = ["POST", "PUT"].indexOf(config.method || "POST")
            webhookMethodCombo.currentIndex = midx >= 0 ? midx : 0
        }
        // slack has no unmasked fields to prefill: its only field, the
        // webhook URL, is a credential.
    }

    onOpened: {
        errorText.text = ""
        if (root.isEditMode) {
            const d = DestinationModel.destinationById(root.destinationId)
            nameField.text = d.destName || ""
            const idx = root.destinationTypes.indexOf(d.destType)
            typeCombo.currentIndex = idx >= 0 ? idx : 0
            prefillConfig(d.destType || "", d.destConfig || {})
        } else {
            nameField.text = ""
            typeCombo.currentIndex = 0
            clearConfigFields()
        }
        nameField.forceActiveFocus()
    }

    Connections {
        target: DestinationModel
        function onCreateDestinationFailed(message) { errorText.text = message }
        function onCreateDestinationSucceeded() { root.close() }
        function onUpdateDestinationFailed(message) { errorText.text = message }
        function onUpdateDestinationSucceeded() { root.close() }
    }

    readonly property string selectedType: destinationTypes[typeCombo.currentIndex]

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
                TblIcon { source: "qrc:/tb/send.svg"; size: 20; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: root.isEditMode ? qsTr("Edit Destination") : qsTr("Add Destination")
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
                objectName: "destinationTypeCombo"
                width: parent.width; height: 36
                enabled: !root.isEditMode
                opacity: enabled ? 1.0 : 0.6
                model: ["S3", "SFTP", "SMB", "Local", "Telegram", "Email", "Slack", "SMS", "Webhook"]
                background: Rectangle { color: Theme.surface; border.color: typeCombo.pressed ? Theme.accent : Theme.border; radius: Theme.radiusS }
                contentItem: Text { leftPadding: Theme.spaceM; text: typeCombo.displayText; font.pixelSize: Theme.fontS; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter }
                indicator: Text { x: typeCombo.width - width - Theme.spaceM; text: "▾"; font.pixelSize: Theme.fontXs; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
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
                objectName: "destinationNameField"
                width: parent.width; height: 36
                placeholderText: qsTr("e.g. Archive bucket")
                color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                background: Rectangle { color: Theme.surface; border.color: nameField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS; Behavior on border.color { ColorAnimation { duration: Theme.durationFast } } }
            }

            Column {
                visible: root.selectedType === "s3"
                width: parent.width; spacing: Theme.spaceM

                Row { width: parent.width; spacing: Theme.spaceM
                    Column { width: (parent.width - Theme.spaceM) / 2; spacing: Theme.spaceS
                        Text { text: qsTr("Bucket *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: s3BucketField; objectName: "destS3BucketField"; width: parent.width; height: 36; color: Theme.textPrimary; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: s3BucketField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                    Column { width: (parent.width - Theme.spaceM) / 2; spacing: Theme.spaceS
                        Text { text: qsTr("Region *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: s3RegionField; objectName: "destS3RegionField"; width: parent.width; height: 36; placeholderText: "eu-west-1"; color: Theme.textPrimary; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: s3RegionField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                }
                Row { width: parent.width; spacing: Theme.spaceM
                    Column { width: (parent.width - Theme.spaceM) / 2; spacing: Theme.spaceS
                        Text { text: qsTr("Access key ID *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: s3KeyField; objectName: "destS3KeyField"; width: parent.width; height: 36; color: Theme.textPrimary; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: s3KeyField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                    Column { width: (parent.width - Theme.spaceM) / 2; spacing: Theme.spaceS
                        Text { text: qsTr("Secret access key *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: s3SecretField; objectName: "destS3SecretField"; width: parent.width; height: 36; echoMode: TextInput.Password; color: Theme.textPrimary; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: s3SecretField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                }
                Text { text: qsTr("Key prefix"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField { id: s3PrefixField; width: parent.width; height: 36; placeholderText: qsTr("recordings/ (optional)"); color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: s3PrefixField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                Text { text: qsTr("Endpoint"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField { id: s3EndpointField; objectName: "destS3EndpointField"; width: parent.width; height: 36; placeholderText: qsTr("https://minio.internal:9000 (optional, for S3-compatible services)"); color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: s3EndpointField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                Row {
                    spacing: Theme.spaceS
                    ToggleSwitch { id: s3PathStyleToggle; objectName: "destS3PathStyleToggle"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: qsTr("Use path-style addressing"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Column {
                visible: root.selectedType === "sftp"
                width: parent.width; spacing: Theme.spaceM

                Row { width: parent.width; spacing: Theme.spaceM
                    Column { width: (parent.width - Theme.spaceM) * 0.65; spacing: Theme.spaceS
                        Text { text: qsTr("Host *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: sftpHostField; width: parent.width; height: 36; placeholderText: "files.example.com"; color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: sftpHostField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                    Column { width: (parent.width - Theme.spaceM) * 0.35; spacing: Theme.spaceS
                        Text { text: qsTr("Port"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: sftpPortField; width: parent.width; height: 36; text: "22"; color: Theme.textPrimary; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: sftpPortField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                }
                Row { width: parent.width; spacing: Theme.spaceM
                    Column { width: (parent.width - Theme.spaceM) / 2; spacing: Theme.spaceS
                        Text { text: qsTr("Username *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: sftpUserField; width: parent.width; height: 36; color: Theme.textPrimary; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: sftpUserField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                    Column { width: (parent.width - Theme.spaceM) / 2; spacing: Theme.spaceS
                        Text { text: qsTr("Password"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: sftpPassField; width: parent.width; height: 36; echoMode: TextInput.Password; color: Theme.textPrimary; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: sftpPassField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                }
                Text { text: qsTr("Remote path *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField { id: sftpPathField; width: parent.width; height: 36; placeholderText: "/uploads"; color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: sftpPathField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
            }

            Column {
                visible: root.selectedType === "smb"
                width: parent.width; spacing: Theme.spaceM

                Text { text: qsTr("Share path *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField { id: smbShareField; width: parent.width; height: 36; placeholderText: "\\\\server\\share"; color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: smbShareField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                Row { width: parent.width; spacing: Theme.spaceM
                    Column { width: (parent.width - Theme.spaceM) / 2; spacing: Theme.spaceS
                        Text { text: qsTr("Username"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: smbUserField; width: parent.width; height: 36; color: Theme.textPrimary; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: smbUserField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                    Column { width: (parent.width - Theme.spaceM) / 2; spacing: Theme.spaceS
                        Text { text: qsTr("Password"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: smbPassField; width: parent.width; height: 36; echoMode: TextInput.Password; color: Theme.textPrimary; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: smbPassField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                }
                Text { text: qsTr("Remote path"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField { id: smbPathField; width: parent.width; height: 36; placeholderText: qsTr("/recordings (optional)"); color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: smbPathField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
            }

            Column {
                visible: root.selectedType === "local"
                width: parent.width; spacing: Theme.spaceM

                Text { text: qsTr("Directory path *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField { id: localPathField; width: parent.width; height: 36; placeholderText: "/var/reeframe/output"; color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: localPathField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
            }

            Column {
                visible: root.selectedType === "telegram"
                width: parent.width; spacing: Theme.spaceM

                Text { text: qsTr("Bot token *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField { id: tgTokenField; width: parent.width; height: 36; echoMode: TextInput.Password; color: Theme.textPrimary; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: tgTokenField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                Text { text: qsTr("Chat ID *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField { id: tgChatField; width: parent.width; height: 36; placeholderText: "-100123456789"; color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: tgChatField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
            }

            Column {
                visible: root.selectedType === "email"
                width: parent.width; spacing: Theme.spaceM

                Row { width: parent.width; spacing: Theme.spaceM
                    Column { width: (parent.width - Theme.spaceM) * 0.65; spacing: Theme.spaceS
                        Text { text: qsTr("SMTP host *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: emailHostField; width: parent.width; height: 36; placeholderText: "smtp.example.com"; color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: emailHostField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                    Column { width: (parent.width - Theme.spaceM) * 0.35; spacing: Theme.spaceS
                        Text { text: qsTr("Port"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: emailPortField; width: parent.width; height: 36; text: "587"; color: Theme.textPrimary; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: emailPortField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                }
                Row { width: parent.width; spacing: Theme.spaceM
                    Column { width: (parent.width - Theme.spaceM) / 2; spacing: Theme.spaceS
                        Text { text: qsTr("Username *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: emailUserField; width: parent.width; height: 36; color: Theme.textPrimary; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: emailUserField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                    Column { width: (parent.width - Theme.spaceM) / 2; spacing: Theme.spaceS
                        Text { text: qsTr("Password *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: emailPassField; width: parent.width; height: 36; echoMode: TextInput.Password; color: Theme.textPrimary; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: emailPassField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                }
                Text { text: qsTr("To address(es) *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField { id: emailToField; width: parent.width; height: 36; placeholderText: "ops@example.com, team@example.com"; color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: emailToField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
            }

            Column {
                visible: root.selectedType === "slack"
                width: parent.width; spacing: Theme.spaceM

                Text { text: qsTr("Incoming webhook URL *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField { id: slackUrlField; width: parent.width; height: 36; placeholderText: "https://hooks.slack.com/services/…"; color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: slackUrlField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
            }

            Column {
                visible: root.selectedType === "sms"
                width: parent.width; spacing: Theme.spaceM

                Text { text: qsTr("API key *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField { id: smsKeyField; width: parent.width; height: 36; echoMode: TextInput.Password; color: Theme.textPrimary; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: smsKeyField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                Row { width: parent.width; spacing: Theme.spaceM
                    Column { width: (parent.width - Theme.spaceM) / 2; spacing: Theme.spaceS
                        Text { text: qsTr("From number *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: smsFromField; width: parent.width; height: 36; placeholderText: "+12345678901"; color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: smsFromField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                    Column { width: (parent.width - Theme.spaceM) / 2; spacing: Theme.spaceS
                        Text { text: qsTr("To number *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                        TextField { id: smsToField; width: parent.width; height: 36; placeholderText: "+12345678901"; color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: smsToField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                    }
                }
            }

            Column {
                visible: root.selectedType === "webhook"
                width: parent.width; spacing: Theme.spaceM

                Text { text: qsTr("URL *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                TextField { id: webhookUrlField; width: parent.width; height: 36; placeholderText: "https://example.com/notify"; color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled; font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent; background: Rectangle { color: Theme.surface; border.color: webhookUrlField.activeFocus ? Theme.accent : Theme.border; radius: Theme.radiusS } }
                Text { text: qsTr("Method"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                ComboBox {
                    id: webhookMethodCombo
                    width: 120; height: 36
                    model: ["POST", "PUT"]
                    background: Rectangle { color: Theme.surface; border.color: Theme.border; radius: Theme.radiusS }
                    contentItem: Text { leftPadding: Theme.spaceM; text: webhookMethodCombo.displayText; font.pixelSize: Theme.fontS; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter }
                    indicator: Text { x: webhookMethodCombo.width - width - Theme.spaceS; text: "▾"; font.pixelSize: Theme.fontXs; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Text {
                id: errorText
                objectName: "addDestinationErrorText"
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
                    color: saveMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent
                    enabled: nameField.text.trim().length > 0

                    Text {
                        anchors.centerIn: parent
                        text: root.isEditMode ? qsTr("Save") : qsTr("Add")
                        font.pixelSize: Theme.fontS; font.weight: Font.Medium
                        color: parent.enabled ? Theme.textOnAccent : Theme.textDisabled
                    }

                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const t = root.selectedType
                            let config = {}
                            if (t === "s3") {
                                config = { bucket: s3BucketField.text.trim(), region: s3RegionField.text.trim(),
                                           access_key_id: s3KeyField.text, secret_access_key: s3SecretField.text }
                                if (s3PrefixField.text.trim()) config.prefix = s3PrefixField.text.trim()
                                if (s3EndpointField.text.trim()) config.endpoint = s3EndpointField.text.trim()
                                if (s3PathStyleToggle.checked) config.path_style_access = true
                            } else if (t === "sftp") {
                                config = { host: sftpHostField.text.trim(), port: parseInt(sftpPortField.text) || 22,
                                           username: sftpUserField.text, path: sftpPathField.text.trim() }
                                if (sftpPassField.text) config.password = sftpPassField.text
                            } else if (t === "smb") {
                                config = { share: smbShareField.text.trim() }
                                if (smbUserField.text) config.username = smbUserField.text
                                if (smbPassField.text) config.password = smbPassField.text
                                if (smbPathField.text.trim()) config.path = smbPathField.text.trim()
                            } else if (t === "local") {
                                config = { path: localPathField.text.trim() }
                            } else if (t === "telegram") {
                                config = { token: tgTokenField.text, chat_id: tgChatField.text.trim() }
                            } else if (t === "email") {
                                config = { smtp_host: emailHostField.text.trim(), smtp_port: parseInt(emailPortField.text) || 587,
                                           username: emailUserField.text, password: emailPassField.text,
                                           to: emailToField.text.trim() }
                            } else if (t === "slack") {
                                config = { webhook_url: slackUrlField.text.trim() }
                            } else if (t === "sms") {
                                config = { api_key: smsKeyField.text, from: smsFromField.text.trim(),
                                           to: smsToField.text.trim() }
                            } else if (t === "webhook") {
                                config = { url: webhookUrlField.text.trim(),
                                           method: webhookMethodCombo.currentText }
                            }
                            errorText.text = ""
                            if (root.isEditMode)
                                DestinationModel.updateDestination(root.destinationId, nameField.text.trim(), t, config)
                            else
                                DestinationModel.createDestination(nameField.text.trim(), t, config)
                        }
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                Rectangle {
                    width: 80; height: 32; radius: Theme.radiusS
                    color: cancelMouse.containsMouse ? Theme.surfaceHover : "transparent"
                    border.color: Theme.border

                    Text { anchors.centerIn: parent; text: qsTr("Cancel"); font.pixelSize: Theme.fontS; color: Theme.textPrimary }

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
