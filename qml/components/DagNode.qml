// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Item {
    id: nodeRoot
    objectName: "dagNode_" + (nodeData.id || "")

    property var nodeData: ({})
    property bool isSelected: false
    // How many output ports to draw: fixed at 2 for a Condition (true/false),
    // grown by DagCanvas for a Fork as edges are added to it (see
    // DagCanvas.outputPortCountFor), always 1 for every other node type.
    property int outputPortCount: 1
    // This node's own entries from PipelineValidation.computeProblems() (see
    // DagCanvas.problemsForNode()). Empty when the node has no live problems.
    property var problems: []

    // Keeps nodes hit-testing/painting above edges regardless of which
    // Repeater instantiated its delegate items more recently.
    z: 1

    signal selectRequested()
    signal outputPortClicked(int portIndex)
    signal inputPortClicked()
    signal dragPositionChanged(string nodeId, real x, real y)
    signal dragEnded(string nodeId)

    readonly property bool isTrigger: nodeData.type === "trigger_root"

    x: nodeData.x !== undefined ? nodeData.x : 0
    y: nodeData.y !== undefined ? nodeData.y : 0

    width: 160
    height: 56

    readonly property color typeColor: {
        switch (nodeData.type) {
        case "trigger_root":   return Theme.accent
        case "action":         return "#4a9eed"
        case "device_control": return "#9c6fe4"
        case "transport":      return Theme.success
        case "condition":      return Theme.warning
        case "fork":           return "#e46f9c"
        default:               return Theme.textSecondary
        }
    }

    readonly property string typeLabel: {
        switch (nodeData.type) {
        case "trigger_root":   return "Trigger"
        case "action":         return "Action"
        case "device_control": return "Device control"
        case "transport":      return "Transport"
        case "condition":      return "Condition"
        case "fork":           return "Fork"
        default:               return nodeData.type || ""
        }
    }

    // target: null since we manually compensate activeTranslation for canvas zoom below.
    DragHandler {
        id: dragger
        target: null

        property real startX: 0
        property real startY: 0

        onActiveChanged: {
            if (active) {
                startX = nodeRoot.x
                startY = nodeRoot.y
            } else {
                const id = nodeRoot.nodeData.id
                PipelineGraphModel.moveNode(id, nodeRoot.x, nodeRoot.y)
                nodeRoot.dragEnded(id)
            }
        }

        onActiveTranslationChanged: {
            if (!active)
                return
            const s = (nodeRoot.parent && nodeRoot.parent.scale > 0)
                    ? nodeRoot.parent.scale : 1.0
            nodeRoot.x = startX + activeTranslation.x / s
            nodeRoot.y = startY + activeTranslation.y / s
            // Reporting via a signal (rather than PipelineGraphModel.moveNode())
            // avoids emitting nodesChanged() on every drag frame, which would
            // otherwise reset the whole node Repeater (including this item)
            // mid-drag, since QML treats a reassigned QVariantList as a new model.
            nodeRoot.dragPositionChanged(nodeRoot.nodeData.id, nodeRoot.x, nodeRoot.y)
        }
    }

    TapHandler {
        onTapped: nodeRoot.selectRequested()
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radiusS
        color: Theme.surfaceCard
        border.color: nodeRoot.isSelected ? Theme.accent : Theme.border
        border.width: nodeRoot.isSelected ? 2 : 1

        Rectangle {
            id: headerStrip
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 24
            color: nodeRoot.typeColor
            radius: Theme.radiusS

            /* Square off the bottom corners of the strip */
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: Theme.radiusS
                color: parent.color
            }

            Row {
                anchors {
                    left: parent.left; leftMargin: Theme.spaceS
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.spaceXs

                Rectangle {
                    width: 7; height: 7; radius: 4
                    color: Qt.rgba(1, 1, 1, 0.65)
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: (nodeData.label && nodeData.label.length > 0)
                          ? nodeData.label : nodeRoot.typeLabel
                    font.pixelSize: Theme.fontXs
                    font.weight: Font.Medium
                    color: "white"
                    elide: Text.ElideRight
                    width: headerStrip.width - Theme.spaceS * 2 - 7 - Theme.spaceXs
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Text {
            anchors {
                left: parent.left; leftMargin: Theme.spaceS
                bottom: parent.bottom; bottomMargin: 7
            }
            text: nodeRoot.typeLabel
            font.pixelSize: Theme.fontXs
            color: Theme.textDisabled
        }

        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    }

    // Real-time problem indicator (see DagCanvas.problemsForNode): red for
    // anything that would stop the pipeline running, amber for a node that's
    // not wired up yet.
    Rectangle {
        id: problemBadge
        objectName: "dagNodeProblemBadge_" + (nodeData.id || "")
        visible: nodeRoot.problems.length > 0
        width: 12; height: 12; radius: 6
        anchors { right: card.right; top: card.top; rightMargin: -3; topMargin: -3 }
        color: nodeRoot.problems.some((p) => p.severity === "error") ? Theme.error : Theme.warning
        border.color: Theme.surface
        border.width: 1

        MouseArea {
            id: badgeHover
            anchors.fill: parent
            hoverEnabled: true
        }

        ToolTip {
            visible: badgeHover.containsMouse
            text: nodeRoot.problems.map((p) => p.message).join("\n")
            delay: 300
        }
    }

    Rectangle {
        id: inputPort
        objectName: "dagNodeInputPort_" + (nodeData.id || "")
        visible: !nodeRoot.isTrigger
        width: 10; height: 10; radius: 5
        x: -5
        y: (nodeRoot.height - height) / 2
        color: Theme.surface
        border.color: nodeRoot.typeColor
        border.width: 2

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            onClicked: nodeRoot.inputPortClicked()
        }
    }

    Repeater {
        model: nodeRoot.outputPortCount

        delegate: Rectangle {
            required property int index
            objectName: "dagNodeOutputPort_" + (nodeData.id || "") + "_" + index

            width: 10; height: 10; radius: 5
            x: nodeRoot.width - 5
            y: (nodeRoot.height * (index + 1) / (nodeRoot.outputPortCount + 1)) - 5
            color: Theme.surface
            border.color: nodeRoot.typeColor
            border.width: 2

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                onClicked: nodeRoot.outputPortClicked(index)
            }
        }
    }

    // Port positions in the parent (world) item's coordinate space, for DagCanvas to draw edges.
    function inputPortPos() {
        return mapToItem(nodeRoot.parent, 0, nodeRoot.height / 2)
    }

    function outputPortPos(index) {
        const portCenterY = nodeRoot.height * (index + 1) / (nodeRoot.outputPortCount + 1)
        return mapToItem(nodeRoot.parent, nodeRoot.width, portCenterY)
    }
}
