// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Popup {
    id: root

    property string pipelineId: ""

    signal accepted(var params)

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 0
    closePolicy: Popup.CloseOnEscape

    onOpened: {
        paramsArea.text = ""
        parseError.visible = false
        paramsArea.forceActiveFocus()
    }

    background: Rectangle {
        color: Theme.surfaceCard
        border.color: Theme.border
        radius: Theme.radiusM
    }

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }

    contentItem: Item {
        implicitWidth: 440
        implicitHeight: content.implicitHeight + Theme.spaceXl * 2

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spaceXl }
            spacing: Theme.spaceM

            Row {
                spacing: Theme.spaceS
                TblIcon { source: "qrc:/tb/player-play.svg"; size: 20; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: qsTr("Trigger Pipeline")
                    font.pixelSize: Theme.fontL
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { width: 1; height: Theme.spaceXs }

            Text {
                text: qsTr("Parameters (optional JSON)")
                font.pixelSize: Theme.fontXs
                color: Theme.textSecondary
            }

            ScrollView {
                width: parent.width
                height: 90
                clip: true

                TextArea {
                    id: paramsArea
                    placeholderText: '{"key": "value"}'
                    color: Theme.textPrimary
                    placeholderTextColor: Theme.textDisabled
                    font.pixelSize: Theme.fontS
                    font.family: "monospace"
                    wrapMode: TextArea.Wrap
                    selectionColor: Theme.accent

                    onTextChanged: parseError.visible = false

                    background: Rectangle {
                        color: Theme.surface
                        border.color: paramsArea.activeFocus ? Theme.accent : Theme.border
                        radius: Theme.radiusS
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                    }
                }
            }

            Text {
                id: parseError
                visible: false
                text: qsTr("Invalid JSON — please check your input")
                font.pixelSize: Theme.fontXs
                color: Theme.error
            }

            Item { width: 1; height: Theme.spaceXs }

            Row {
                layoutDirection: Qt.RightToLeft
                spacing: Theme.spaceS
                width: parent.width

                Rectangle {
                    width: 90; height: 32; radius: Theme.radiusS
                    color: triggerMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Trigger")
                        font.pixelSize: Theme.fontS; font.weight: Font.Medium
                        color: Theme.textOnAccent
                    }

                    MouseArea {
                        id: triggerMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const text = paramsArea.text.trim()
                            let params = {}
                            if (text.length > 0) {
                                try {
                                    params = JSON.parse(text)
                                } catch (e) {
                                    parseError.visible = true
                                    return
                                }
                            }
                            root.accepted(params)
                            root.close()
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
