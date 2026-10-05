// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Popup {
    id: root
    objectName: "saveProfileDialog"

    property string mode: "create"
    property string initialName: ""

    signal confirmed(string name)

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 0
    closePolicy: Popup.CloseOnEscape

    onOpened: {
        nameField.text = root.initialName
        nameField.selectAll()
        nameField.forceActiveFocus()
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
        implicitWidth: 340
        implicitHeight: content.implicitHeight + Theme.spaceXl * 2

        Column {
            id: content
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.spaceXl
            }
            spacing: Theme.spaceM

            Text {
                text: root.mode === "create" ? qsTr("New Profile") : qsTr("Rename Profile")
                font.pixelSize: Theme.fontL
                font.weight: Font.Medium
                color: Theme.textPrimary
            }

            Item { width: 1; height: Theme.spaceXs }

            Text {
                text: qsTr("Name")
                font.pixelSize: Theme.fontXs
                color: Theme.textSecondary
            }

            TextField {
                id: nameField
                width: parent.width
                height: 36
                placeholderText: qsTr("e.g. Main Building")
                color: Theme.textPrimary
                placeholderTextColor: Theme.textDisabled
                font.pixelSize: Theme.fontS
                leftPadding: Theme.spaceM
                selectionColor: Theme.accent

                background: Rectangle {
                    color: Theme.surface
                    border.color: nameField.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radiusS
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                }

                Keys.onReturnPressed: {
                    if (nameField.text.trim().length > 0) {
                        root.confirmed(nameField.text.trim())
                        root.close()
                    }
                }
            }

            Item { width: 1; height: Theme.spaceXs }

            Row {
                layoutDirection: Qt.RightToLeft
                spacing: Theme.spaceS
                width: parent.width

                Rectangle {
                    width: 80; height: 32; radius: Theme.radiusS
                    enabled: nameField.text.trim().length > 0
                    opacity: enabled ? 1.0 : 0.5
                    color: okMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: root.mode === "create" ? qsTr("Create") : qsTr("Rename")
                        font.pixelSize: Theme.fontS
                        font.weight: Font.Medium
                        color: Theme.textOnAccent
                    }

                    MouseArea {
                        id: okMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (nameField.text.trim().length > 0) {
                                root.confirmed(nameField.text.trim())
                                root.close()
                            }
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
