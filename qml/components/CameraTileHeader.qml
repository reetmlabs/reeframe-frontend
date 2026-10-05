// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property string cameraName
    required property string connectionState
    required property bool   isRecording
    property bool backendReachable: true
    property bool showClose: true
    property bool showExpand: true

    signal expandClicked()
    signal closeClicked()

    implicitHeight: 28

    readonly property color dotColor: !backendReachable ? Theme.error
        : connectionState === "connected"  ? Theme.success
        : connectionState === "connecting" ? Theme.warning
        : Theme.error

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.surfaceAlt.r, Theme.surfaceAlt.g, Theme.surfaceAlt.b, 0.85)

        RowLayout {
            anchors {
                left: parent.left; leftMargin: 8
                right: rightZone.left; rightMargin: 4
                verticalCenter: parent.verticalCenter
            }
            height: parent.height
            spacing: 6

            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                radius: 4
                color: root.dotColor
            }

            Text {
                Layout.fillWidth: true
                text: root.cameraName
                color: Theme.textPrimary
                font.pixelSize: Theme.fontXs
                elide: Text.ElideRight
                maximumLineCount: 1
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                Layout.preferredWidth: recLabel.contentWidth + 12
                Layout.preferredHeight: 16
                radius: 3
                color: Theme.error
                visible: root.isRecording

                Text {
                    id: recLabel
                    anchors.centerIn: parent
                    text: "● REC"
                    color: "white"
                    font.pixelSize: Theme.fontXs - 1
                    font.weight: Font.Medium
                }
            }
        }

        Row {
            id: rightZone
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            spacing: 2

            TblIcon {
                visible: root.showExpand
                source: "qrc:/tb/arrows-maximize.svg"
                color: Theme.textSecondary
                size: 16

                MouseArea {
                    objectName: "expandButton"
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expandClicked()
                }
            }

            TblIcon {
                objectName: "closeButtonIcon"
                visible: root.showClose
                source: "qrc:/tb/x.svg"
                color: Theme.textSecondary
                size: 16

                MouseArea {
                    objectName: "closeButton"
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeClicked()
                }
            }
        }
    }
}
