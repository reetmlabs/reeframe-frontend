// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic
import "../components"

Item {
    id: root

    property string runId: ""
    property string pipelineId: ""
    property string runStatus: ""
    property int runTriggeredAt: 0
    property int runCompletedAt: 0
    property string runError: ""

    // Re-read from RunModel whenever it refreshes (RunModel.count changes on
    // every poll tick, even when the row count itself doesn't) instead of
    // staying frozen at whatever this page's push params captured on open.
    readonly property var liveRun: {
        const _ = RunModel.count
        return RunModel.runById(root.runId)
    }
    readonly property string liveStatus: liveRun.runStatus !== undefined ? liveRun.runStatus : root.runStatus
    readonly property int liveCompletedAt: liveRun.runCompletedAt !== undefined ? liveRun.runCompletedAt : root.runCompletedAt
    readonly property string liveError: liveRun.runError !== undefined ? liveRun.runError : root.runError

    readonly property var liveNodeResults: {
        const _ = RunModel.count
        return RunModel.nodeResultsForRun(root.runId)
    }

    function formatDateTime(epochSecs) {
        if (epochSecs <= 0) return "—"
        return Qt.formatDateTime(new Date(epochSecs * 1000), "d MMM yyyy  hh:mm:ss")
    }

    function formatDuration(s, e) {
        if (e <= 0 || s <= 0) return "—"
        const secs = e - s
        if (secs < 60) return secs + "s"
        return Math.floor(secs / 60) + "m " + (secs % 60) + "s"
    }

    /* ----- Header ----- */
    Rectangle {
        id: header
        height: 44; color: "transparent"
        anchors { left: parent.left; right: parent.right; top: parent.top }

        Rectangle {
            id: backBtn
            width: 72; height: 30; radius: Theme.radiusS
            color: backMouse.containsMouse ? Theme.surfaceHover : "transparent"
            anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }

            Text { anchors.centerIn: parent; text: qsTr("← Back"); font.pixelSize: Theme.fontS; color: Theme.textSecondary }

            MouseArea {
                id: backMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                // Qualified with root; see PipelineListView.qml's rowMouse for why a bare
                // "StackView.view" resolves to null from anywhere but the page's root item.
                onClicked: root.StackView.view.pop()
            }

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        Text {
            text: qsTr("Run Detail")
            font.pixelSize: Theme.fontM; font.weight: Font.Medium; color: Theme.textPrimary
            anchors { left: backBtn.right; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
        }

        Rectangle { height: 1; color: Theme.border; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } }
    }

    /* ----- Scrollable content ----- */
    Flickable {
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        contentHeight: pageContent.implicitHeight
        clip: true

        Column {
            id: pageContent
            width: parent.width

            /* Run summary rows */
            Column {
                width: parent.width
                leftPadding: Theme.spaceXl
                rightPadding: Theme.spaceXl
                topPadding: Theme.spaceXl

                Repeater {
                    model: [
                        { label: qsTr("Status"),    special: "status" },
                        { label: qsTr("Triggered"), special: "text",  value: root.formatDateTime(root.runTriggeredAt) },
                        { label: qsTr("Completed"), special: "text",  value: root.formatDateTime(root.liveCompletedAt) },
                        { label: qsTr("Duration"),  special: "text",  value: root.formatDuration(root.runTriggeredAt, root.liveCompletedAt) },
                        { label: qsTr("Error"),     special: "error" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: parent.width - Theme.spaceXl * 2
                        height: modelData.special === "error" ? Math.max(44, errorText.implicitHeight + Theme.spaceM) : 44
                        color: index % 2 === 0 ? "transparent" : Qt.rgba(1, 1, 1, 0.02)
                        visible: modelData.special !== "error" || root.liveError.length > 0

                        Text {
                            text: modelData.label
                            font.pixelSize: Theme.fontS; color: Theme.textSecondary
                            width: 100
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        }

                        /* Status badge */
                        RunStatusBadge {
                            visible: modelData.special === "status"
                            status: root.liveStatus
                            anchors { left: parent.left; leftMargin: 100; verticalCenter: parent.verticalCenter }
                        }

                        /* Plain text */
                        Text {
                            visible: modelData.special === "text"
                            text: modelData.value || "—"
                            font.pixelSize: Theme.fontS; color: Theme.textPrimary
                            anchors { left: parent.left; leftMargin: 100; right: parent.right; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideRight
                        }

                        /* Error, selectable so it can be copied to the clipboard */
                        TextEdit {
                            id: errorText
                            visible: modelData.special === "error"
                            text: root.liveError
                            readOnly: true
                            selectByMouse: true
                            font.pixelSize: Theme.fontS; color: Theme.error
                            wrapMode: TextEdit.Wrap
                            anchors { left: parent.left; leftMargin: 100; right: parent.right; top: parent.top; topMargin: Theme.spaceS }
                        }
                    }
                }
            }

            /* Node results header */
            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Rectangle {
                width: parent.width; height: 40; color: "transparent"
                Text {
                    text: qsTr("Node Results")
                    font.pixelSize: Theme.fontS; font.weight: Font.Medium; color: Theme.textSecondary
                    anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            /* Empty state */
            Rectangle {
                visible: nodeResults.count === 0
                width: parent.width; height: 48; color: "transparent"
                Text {
                    anchors.centerIn: parent
                    text: qsTr("No node results available")
                    font.pixelSize: Theme.fontS; color: Theme.textDisabled
                }
            }

            /* Node result rows */
            Repeater {
                id: nodeResults
                model: root.liveNodeResults

                delegate: Column {
                    width: pageContent.width

                    NodeResultRow {
                        width: parent.width
                        nodeResult: modelData
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: 0.5 }
                }
            }

            Item { width: 1; height: Theme.spaceXl }
        }
    }
}
