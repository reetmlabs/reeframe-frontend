// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

// Collapsible "Problems" drawer for the pipeline editor. See
// DagCanvas.problems for what feeds it. Collapsed by default, showing just
// the error/warning counts; expand to see (and act on) each one.
Rectangle {
    id: root
    objectName: "problemsPanel"

    property var problems: []
    property bool expanded: false

    signal entryActivated(var problem)

    readonly property int errorCount: problems.filter((p) => p.severity === "error").length
    readonly property int warningCount: problems.filter((p) => p.severity === "warning").length

    readonly property int headerHeight: 32
    readonly property int entryHeight: 28
    readonly property int maxListHeight: 160

    height: headerHeight + (expanded ? Math.min(problems.length * entryHeight, maxListHeight) : 0)
    color: Theme.surface
    clip: true

    Behavior on height { NumberAnimation { duration: Theme.durationFast } }

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        color: Theme.border
    }

    Rectangle {
        id: header
        objectName: "problemsPanelHeader"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.headerHeight
        color: headerMouse.containsMouse ? Theme.surfaceHover : "transparent"

        Row {
            anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
            spacing: Theme.spaceS

            TblIcon {
                source: root.expanded ? "qrc:/tb/chevron-down.svg" : "qrc:/tb/chevron-right.svg"
                color: Theme.textSecondary
                size: 14
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: qsTr("Problems")
                font.pixelSize: Theme.fontS; font.weight: Font.Medium
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                objectName: "problemsPanelSummary"
                text: root.errorCount === 0 && root.warningCount === 0
                    ? qsTr("No problems")
                    : qsTr("%1 error(s) · %2 warning(s)").arg(root.errorCount).arg(root.warningCount)
                font.pixelSize: Theme.fontXs
                color: root.errorCount > 0 ? Theme.error : (root.warningCount > 0 ? Theme.warning : Theme.textDisabled)
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    ListView {
        id: list
        objectName: "problemsPanelList"
        visible: root.expanded
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        model: root.problems

        delegate: Rectangle {
            id: entry
            required property var modelData
            required property int index
            objectName: "problemsPanelEntry_" + index

            // A problem with neither a single node nor a node list has
            // nothing for clicking to do, e.g. "no trigger node found".
            readonly property bool clickable: !!modelData.nodeId || !!(modelData.nodeIds && modelData.nodeIds.length > 0)

            width: list.width
            height: root.entryHeight
            color: entryMouse.containsMouse && clickable ? Theme.surfaceHover : "transparent"

            Rectangle {
                width: 6; height: 6; radius: 3
                color: entry.modelData.severity === "error" ? Theme.error : Theme.warning
                anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
            }

            Text {
                text: entry.modelData.message
                font.pixelSize: Theme.fontXs
                color: Theme.textPrimary
                elide: Text.ElideRight
                anchors {
                    left: parent.left; leftMargin: Theme.spaceM + 6 + Theme.spaceS
                    right: parent.right; rightMargin: Theme.spaceM
                    verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: entryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: entry.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (entry.clickable) root.entryActivated(entry.modelData)
            }
        }
    }
}
