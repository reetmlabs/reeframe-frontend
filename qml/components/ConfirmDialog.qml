// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Popup {
    id: root

    property string title: ""
    property string message: ""
    property string confirmLabel: qsTr("Confirm")

    signal confirmed()

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 0
    closePolicy: Popup.CloseOnEscape

    background: Rectangle {
        color: Theme.surfaceCard
        border.color: Theme.border
        radius: Theme.radiusM
    }

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    contentItem: Item {
        implicitWidth: 360
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
                text: root.title
                font.pixelSize: Theme.fontL
                font.weight: Font.Medium
                color: Theme.textPrimary
            }

            Text {
                text: root.message
                font.pixelSize: Theme.fontS
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Item { width: 1; height: Theme.spaceXs }

            Row {
                layoutDirection: Qt.RightToLeft
                spacing: Theme.spaceS
                width: parent.width

                Rectangle {
                    width: 90
                    height: 32
                    radius: Theme.radiusS
                    color: confirmMouse.containsMouse ? Qt.darker(Theme.error, 1.15) : Theme.error

                    Text {
                        anchors.centerIn: parent
                        text: root.confirmLabel
                        font.pixelSize: Theme.fontS
                        font.weight: Font.Medium
                        color: Theme.textOnAccent
                    }

                    MouseArea {
                        id: confirmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.confirmed(); root.close() }
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
