// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

// Coordinator connections have no display name in CoordinatorManager's data
// model (just a URL), so unlike AddSiteDialog this only asks for one field.
Popup {
    id: root
    objectName: "addCoordinatorDialog"

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 0
    closePolicy: Popup.CloseOnEscape

    onOpened: {
        urlField.text = ""
        urlField.forceActiveFocus()
    }

    background: Rectangle {
        color: Theme.surfaceCard
        border.color: Theme.border
        radius: Theme.radiusM
    }

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    contentItem: Item {
        implicitWidth: 380
        implicitHeight: content.implicitHeight + Theme.spaceXl * 2

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spaceXl }
            spacing: Theme.spaceM

            Row {
                spacing: Theme.spaceS
                TblIcon { source: "qrc:/tb/broadcast.svg"; size: 20; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: qsTr("Add Coordinator")
                    font.pixelSize: Theme.fontL
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { width: 1; height: Theme.spaceXs }

            Text {
                text: qsTr("Coordinator URL")
                font.pixelSize: Theme.fontXs
                color: Theme.textSecondary
            }

            TextField {
                id: urlField
                objectName: "coordinatorUrlField"
                width: parent.width
                height: 36
                placeholderText: "https://coordinator.example.com:8443"
                color: Theme.textPrimary
                placeholderTextColor: Theme.textDisabled
                font.pixelSize: Theme.fontS
                leftPadding: Theme.spaceM
                selectionColor: Theme.accent

                background: Rectangle {
                    color: Theme.surface
                    border.color: urlField.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radiusS
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            Item { width: 1; height: Theme.spaceXs }

            Row {
                layoutDirection: Qt.RightToLeft
                spacing: Theme.spaceS
                width: parent.width

                Rectangle {
                    objectName: "addCoordinatorConfirmButton"
                    width: 80
                    height: 32
                    radius: Theme.radiusS
                    color: addMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent
                    enabled: urlField.text.trim().length > 0

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Add")
                        font.pixelSize: Theme.fontS
                        font.weight: Font.Medium
                        color: Theme.textOnAccent
                    }

                    MouseArea {
                        id: addMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            CoordinatorManager.addConnection(urlField.text.trim())
                            root.close()
                        }
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                Rectangle {
                    width: 80
                    height: 32
                    radius: Theme.radiusS
                    color: cancelMouse.containsMouse ? Theme.surfaceHover : "transparent"
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Cancel")
                        font.pixelSize: Theme.fontS
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
            }
        }
    }
}
