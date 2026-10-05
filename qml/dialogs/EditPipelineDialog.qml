// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic
import "../components"

Popup {
    id: root

    property string pipelineId: ""
    property string pipelineName: ""
    property string pipelineDescription: ""
    property string pipelineType: ""

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 0
    closePolicy: Popup.CloseOnEscape

    onOpened: {
        nameField.text = root.pipelineName
        descField.text = root.pipelineDescription
        errorText.text = ""
        nameField.forceActiveFocus()
    }

    Connections {
        target: PipelineModel
        function onUpdatePipelineFailed(message) { errorText.text = message }
        function onUpdatePipelineSucceeded() { root.close() }
    }

    background: Rectangle {
        color: Theme.surfaceCard
        border.color: Theme.border
        radius: Theme.radiusM
    }

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }

    contentItem: Item {
        implicitWidth: 420
        implicitHeight: content.implicitHeight + Theme.spaceXl * 2

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spaceXl }
            spacing: Theme.spaceM

            Row {
                spacing: Theme.spaceS
                TblIcon { source: "qrc:/tb/git-merge.svg"; size: 20; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: qsTr("Edit Pipeline")
                    font.pixelSize: Theme.fontL
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { width: 1; height: Theme.spaceXs }

            Text { text: qsTr("Name *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
            TextField {
                id: nameField
                width: parent.width; height: 36
                color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                background: Rectangle {
                    color: Theme.surface
                    border.color: nameField.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radiusS
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            Text { text: qsTr("Description"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
            TextField {
                id: descField
                width: parent.width; height: 36
                placeholderText: qsTr("Optional description")
                color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                background: Rectangle {
                    color: Theme.surface
                    border.color: descField.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radiusS
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            Row {
                spacing: Theme.spaceM

                Text {
                    text: qsTr("Type")
                    font.pixelSize: Theme.fontXs
                    color: Theme.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }

                TypeChip {
                    type: root.pipelineType
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: qsTr("— cannot be changed after creation")
                    font.pixelSize: Theme.fontXs
                    color: Theme.textDisabled
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                id: errorText
                objectName: "editPipelineErrorText"
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
                        text: qsTr("Save")
                        font.pixelSize: Theme.fontS; font.weight: Font.Medium
                        color: parent.enabled ? Theme.textOnAccent : Theme.textDisabled
                    }

                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            errorText.text = ""
                            PipelineModel.updatePipeline(
                                root.pipelineId,
                                nameField.text.trim(),
                                descField.text.trim()
                            )
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
                        text: qsTr("Cancel"); font.pixelSize: Theme.fontS; color: Theme.textPrimary
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
