// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: panelRoot

    property var nodeData: ({})

    readonly property string nodeId: nodeData.id !== undefined ? nodeData.id : ""

    // Which fields below are relevant depends on the selected destination's
    // type (see the adapters under vms-transports/src/adapters/ in the
    // backend): file-drop destinations take a path/filename, everything
    // else is message-only.
    readonly property string selectedDestinationType: {
        const id = destinationCombo.destinationId
        if (!id) return ""
        for (const d of destinationCombo.destinationOptions) {
            if (d.id === id) return d.type
        }
        return ""
    }
    readonly property var fileBasedDestinationTypes: ["s3", "sftp", "smb", "local"]
    readonly property bool isFileBasedDestination: fileBasedDestinationTypes.includes(selectedDestinationType)
    // Telegram, Email, and Slack all deliver to a fixed address, chat, or
    // channel that lives on the Destination's own config, not to a per-node
    // contact list, so none of them read this field's value on delivery.
    readonly property bool isContactBasedDestination: selectedDestinationType !== "" && !isFileBasedDestination
                                                       && selectedDestinationType !== "telegram"
                                                       && selectedDestinationType !== "email"
                                                       && selectedDestinationType !== "slack"

    color: Theme.surface

    Rectangle {
        anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
        width: 1
        color: Theme.border
    }

    function resetFromConfig() {
        if (nodeId === "") return
        const cfg = nodeData.config || {}
        labelField.text = nodeData.label || ""
        destinationCombo.destinationId = cfg.destination_id || ""
        contactListField.text = cfg.contact_list_id || ""
        pathTemplateField.text = cfg.path_template || ""
        filenameTemplateField.text = cfg.filename_template || ""
        messageTemplateArea.text = cfg.message_template || ""
    }

    function commitConfig() {
        if (!nodeData.id) return
        let cfg = {}
        if (destinationCombo.destinationId) cfg.destination_id = destinationCombo.destinationId
        if (panelRoot.isContactBasedDestination) {
            const cl = contactListField.text.trim()
            if (cl) cfg.contact_list_id = cl
        }
        if (panelRoot.isFileBasedDestination) {
            const pt = pathTemplateField.text.trim()
            if (pt) cfg.path_template = pt
            const ft = filenameTemplateField.text.trim()
            if (ft) cfg.filename_template = ft
        }
        const mt = messageTemplateArea.text.trim()
        if (mt) cfg.message_template = mt
        PipelineGraphModel.updateNodeConfig(nodeData.id, cfg)
    }

    onNodeIdChanged: resetFromConfig()
    Component.onCompleted: DestinationModel.refresh()

    Column {
        id: headerSection
        anchors { top: parent.top; left: parent.left; right: parent.right }

        Item {
            width: parent.width; height: 44

            Text {
                text: qsTr("Label")
                font.pixelSize: Theme.fontXs
                color: Theme.textDisabled
                width: 48
                anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
            }

            TextField {
                id: labelField
                anchors {
                    left: parent.left; leftMargin: 56
                    right: parent.right; rightMargin: Theme.spaceM
                    verticalCenter: parent.verticalCenter
                }
                height: 28
                font.pixelSize: Theme.fontS
                color: Theme.textPrimary
                leftPadding: Theme.spaceS
                rightPadding: Theme.spaceS

                background: Rectangle {
                    color: "transparent"
                    radius: Theme.radiusS
                    border.color: labelField.activeFocus ? Theme.accent : Theme.border
                    border.width: labelField.activeFocus ? 2 : 1
                }

                onEditingFinished: {
                    const t = text.trim()
                    if (t !== "" && nodeData.id)
                        PipelineGraphModel.updateNodeLabel(nodeData.id, t)
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Item {
            width: parent.width; height: 32

            Row {
                anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                spacing: Theme.spaceS
                Text {
                    text: qsTr("Node type")
                    font.pixelSize: Theme.fontXs; color: Theme.textDisabled
                    width: 72; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: qsTr("Transport")
                    font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }
    }

    ScrollView {
        id: formScroll
        anchors { top: headerSection.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentWidth: width
        clip: true

        Column {
            id: formBody
            width: formScroll.width
            spacing: 0
            topPadding: Theme.spaceS
            bottomPadding: Theme.spaceM

            component FormField: Item {
                property alias label: lbl.text
                property alias text: tf.text
                property alias placeholderText: tf.placeholderText

                width: parent.width
                height: 32

                Text {
                    id: lbl
                    font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                    width: 108
                    anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                }
                TextField {
                    id: tf
                    anchors { left: parent.left; leftMargin: 116; right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                    height: 26
                    font.pixelSize: Theme.fontXs
                    color: Theme.textPrimary
                    leftPadding: Theme.spaceS; rightPadding: Theme.spaceS
                    background: Rectangle {
                        color: "transparent"; radius: Theme.radiusS
                        border.color: tf.activeFocus ? Theme.accent : Theme.border
                        border.width: tf.activeFocus ? 2 : 1
                    }
                    onEditingFinished: panelRoot.commitConfig()
                }
            }

            component FormTextArea: Item {
                property alias label: lbl.text
                property alias text: ta.text

                width: parent.width
                height: 80

                Text {
                    id: lbl
                    font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                    anchors { left: parent.left; leftMargin: Theme.spaceM; top: parent.top; topMargin: 8 }
                }
                ScrollView {
                    anchors { left: parent.left; leftMargin: Theme.spaceM; right: parent.right; rightMargin: Theme.spaceM; bottom: parent.bottom; bottomMargin: 4; top: parent.top; topMargin: 24 }
                    TextArea {
                        id: ta
                        font.pixelSize: Theme.fontXs; color: Theme.textPrimary
                        wrapMode: TextArea.Wrap
                        background: Rectangle {
                            color: "transparent"; radius: Theme.radiusS
                            border.color: ta.activeFocus ? Theme.accent : Theme.border
                            border.width: ta.activeFocus ? 2 : 1
                        }
                        onEditingFinished: panelRoot.commitConfig()
                    }
                }
            }

            // Type-to-filter + click-to-select Destination picker (mirrors
            // NodeConfigPanel's FormCameraCombo / TriggerConfigPanel's
            // eventSourceCombo). A Destination carries its own connection
            // config (bucket/host/credentials); this node only references it.
            component FormDestinationCombo: Item {
                property alias label: lbl.text
                property string destinationId: ""

                signal committed()

                width: parent.width
                height: 32

                // Depends on DestinationModel.count purely to establish a
                // binding: refresh()/create/delete only bump count, not a
                // dedicated signal.
                readonly property var destinationOptions: {
                    const _trackCount = DestinationModel.count
                    return DestinationModel.searchableEntries()
                }

                readonly property var filteredOptions: {
                    const q = searchField.text.trim().toLowerCase()
                    if (q === "" || !searchField.activeFocus) return destinationOptions
                    return destinationOptions.filter((d) =>
                        d.name.toLowerCase().includes(q)
                        || (d.subtitle && d.subtitle.toLowerCase().includes(q)))
                }

                function nameFor(id) {
                    if (id === "") return ""
                    for (const d of destinationOptions) {
                        if (d.id === id) return d.name
                    }
                    return id
                }

                onDestinationOptionsChanged: if (!searchField.activeFocus) searchField.text = nameFor(destinationId)
                onDestinationIdChanged: if (!searchField.activeFocus) searchField.text = nameFor(destinationId)

                Text {
                    id: lbl
                    font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                    width: 108
                    anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                }

                TextField {
                    id: searchField
                    anchors { left: parent.left; leftMargin: 116; right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                    height: 26
                    font.pixelSize: Theme.fontXs
                    color: Theme.textPrimary
                    placeholderText: qsTr("Search destinations…")
                    leftPadding: Theme.spaceS; rightPadding: Theme.spaceS
                    background: Rectangle {
                        color: "transparent"; radius: Theme.radiusS
                        border.color: searchField.activeFocus ? Theme.accent : Theme.border
                        border.width: searchField.activeFocus ? 2 : 1
                    }
                    onActiveFocusChanged: {
                        if (activeFocus) {
                            text = ""
                            resultsPopup.open()
                        } else {
                            resultsPopup.close()
                            text = nameFor(destinationId)
                        }
                    }
                    onTextEdited: resultsPopup.open()
                    Keys.onEscapePressed: focus = false
                }

                Popup {
                    id: resultsPopup
                    y: parent.height
                    x: 116
                    width: parent.width - 116 - Theme.spaceM
                    implicitHeight: Math.min(160, Math.max(1, resultsList.count) * 28)
                    padding: 0

                    contentItem: ListView {
                        id: resultsList
                        model: filteredOptions
                        clip: true
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width; height: 28
                            color: hoverArea.containsMouse ? Theme.surfaceHover : "transparent"
                            Text {
                                anchors { left: parent.left; leftMargin: Theme.spaceS; right: parent.right; rightMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }
                                text: modelData.subtitle ? (modelData.name + "  ·  " + modelData.subtitle) : modelData.name
                                font.pixelSize: Theme.fontXs; color: Theme.textPrimary
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                id: hoverArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    destinationId = modelData.id
                                    searchField.text = modelData.name
                                    resultsPopup.close()
                                    committed()
                                }
                            }
                        }
                    }
                }

                Component.onCompleted: searchField.text = nameFor(destinationId)
            }

            FormDestinationCombo { id: destinationCombo; label: qsTr("Destination"); onCommitted: panelRoot.commitConfig() }
            FormField {
                id: contactListField
                visible: panelRoot.isContactBasedDestination
                label: qsTr("Contact list ID"); placeholderText: qsTr("optional, UUID")
            }

            Text {
                width: parent.width - Theme.spaceM * 2
                anchors.left: parent.left; anchors.leftMargin: Theme.spaceM
                topPadding: Theme.spaceXs; bottomPadding: Theme.spaceXs
                text: qsTr("Optional minijinja templates. Available variables: camera_id, camera_name, fired_at, trigger_type, run_id, artifact_name, artifact_stem, artifact_ext.")
                font.pixelSize: Theme.fontXs; color: Theme.textDisabled
                wrapMode: Text.WordWrap
            }

            FormField {
                id: pathTemplateField
                visible: panelRoot.isFileBasedDestination
                label: qsTr("Path template"); placeholderText: qsTr("e.g. recordings/{{ camera_name }}")
            }
            FormField {
                id: filenameTemplateField
                visible: panelRoot.isFileBasedDestination
                label: qsTr("Filename template"); placeholderText: qsTr("e.g. {{ fired_at }}_{{ camera_name }}.mp4")
            }
            FormTextArea { id: messageTemplateArea; label: qsTr("Message template") }

            Text {
                width: parent.width - Theme.spaceM * 2
                anchors.left: parent.left; anchors.leftMargin: Theme.spaceM
                bottomPadding: Theme.spaceS
                text: qsTr("If left blank, the message template falls back to the previous node's text output (e.g. from a Render notification action).")
                font.pixelSize: Theme.fontXs; color: Theme.textDisabled
                wrapMode: Text.WordWrap
            }
        }
    }
}
