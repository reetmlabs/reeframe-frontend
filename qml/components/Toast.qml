// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

Item {
    id: root

    property string message: ""
    property string actionText: ""
    property var actionData: null

    signal actionTriggered(var data)

    function show(msg, duration) {
        showWithAction(msg, "", null, duration)
    }

    function showWithAction(msg, actionLabel, data, duration) {
        message = msg
        actionText = actionLabel || ""
        actionData = data !== undefined ? data : null
        opacity = 1.0
        dismissTimer.interval = duration || 3000
        dismissTimer.restart()
    }

    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.spaceXl }
    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight
    visible: opacity > 0
    opacity: 0

    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Timer {
        id: dismissTimer
        interval: 3000
        onTriggered: root.opacity = 0
    }

    Rectangle {
        id: pill
        implicitWidth: content.implicitWidth + Theme.spaceXl * 2
        implicitHeight: content.implicitHeight + Theme.spaceM * 2
        radius: Theme.radiusM
        color: Theme.surfaceCard
        border.color: Theme.border

        Row {
            id: content
            anchors.centerIn: parent
            spacing: Theme.spaceM

            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                text: root.message
                font.pixelSize: Theme.fontS
                color: Theme.textPrimary
            }

            Text {
                objectName: "toastActionButton"
                visible: root.actionText.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.actionText
                font.pixelSize: Theme.fontS
                font.weight: Font.Medium
                color: Theme.accent

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.opacity = 0
                        dismissTimer.stop()
                        root.actionTriggered(root.actionData)
                    }
                }
            }
        }
    }
}
