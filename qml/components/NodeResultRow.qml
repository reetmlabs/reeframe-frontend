// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Column {
    id: root

    // nodeResult map: nodeId, status, startedAt, completedAt, output, error
    property var nodeResult: ({})
    property bool expanded: false

    readonly property bool hasError: (nodeResult.error || "").length > 0
    readonly property bool hasDetail: hasError || (nodeResult.output || "").length > 0

    width: parent ? parent.width : 0

    function formatDuration(s, e) {
        if (e <= 0 || s <= 0) return "—"
        const secs = e - s
        if (secs < 60) return secs + "s"
        return Math.floor(secs / 60) + "m " + (secs % 60) + "s"
    }

    function formatTime(epochSecs) {
        if (epochSecs <= 0) return "—"
        return Qt.formatTime(new Date(epochSecs * 1000), "hh:mm:ss")
    }

    Rectangle {
        width: parent.width; height: 44
        color: headerMouse.containsMouse ? Theme.surfaceHover : "transparent"

        Row {
            anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
            spacing: Theme.spaceM

            RunStatusBadge {
                status: root.nodeResult.status || "pending"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: (root.nodeResult.nodeId || "").substring(0, 8)
                font.pixelSize: Theme.fontXs
                font.family: "monospace"
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.formatTime(root.nodeResult.startedAt)
                font.pixelSize: Theme.fontXs
                color: Theme.textDisabled
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.formatDuration(root.nodeResult.startedAt, root.nodeResult.completedAt)
                font.pixelSize: Theme.fontXs
                color: Theme.textDisabled
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            visible: root.hasDetail
            text: root.expanded ? "▾" : "›"
            font.pixelSize: Theme.fontXs
            color: Theme.textSecondary
            anchors { right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
        }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.hasDetail ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (root.hasDetail)
                    root.expanded = !root.expanded
            }
        }

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    Item {
        width: parent.width
        height: root.expanded ? outputArea.implicitHeight + Theme.spaceM * 2 : 0
        clip: true

        Behavior on height { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }

        ScrollView {
            id: outputArea
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spaceM }
            height: Math.min(implicitHeight, 160)

            TextArea {
                text: root.hasError ? root.nodeResult.error : (root.nodeResult.output || "No output")
                readOnly: true
                wrapMode: TextArea.Wrap
                font.pixelSize: Theme.fontXs
                font.family: "monospace"
                color: root.hasError ? Theme.error : Theme.textSecondary
                selectByMouse: true

                background: Rectangle {
                    color: Theme.surface
                    border.color: Theme.border
                    radius: Theme.radiusS
                }
            }
        }
    }
}
