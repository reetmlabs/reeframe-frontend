// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Shapes

Item {
    id: edgeRoot

    property var edgeData: ({})
    property bool isSelected: false
    // Both supplied by DagCanvas (see portIndexForEdge/outputPortCountFor).
    // A Fork's edges carry no port of their own, so this can't be derived
    // from edgeData alone the way a Condition's true/false port can.
    property int fromPortIndex: 0
    property int outputPortCount: 1

    // Per-node {x, y} overrides while a node is being dragged (see
    // DagNode.dragPositionChanged), keyed by node id. Lets the edge follow
    // the node in real time without waiting for PipelineGraphModel.moveNode()
    // on release.
    property var liveNodePos: ({})

    signal selectRequested()

    readonly property real nodeW: 160
    readonly property real nodeH: 56

    /* Re-evaluate whenever nodes move, not just when edges change. */
    readonly property var fromNode: {
        const _ = PipelineGraphModel.nodes
        return PipelineGraphModel.nodeById(edgeData.fromNodeId || "")
    }
    readonly property var toNode: {
        const _ = PipelineGraphModel.nodes
        return PipelineGraphModel.nodeById(edgeData.toNodeId || "")
    }

    readonly property bool valid: {
        const fn = fromNode
        const tn = toNode
        return fn !== null && fn !== undefined && fn.id !== undefined
            && tn !== null && tn !== undefined && tn.id !== undefined
    }

    visible: valid

    readonly property var fromPos: (valid && liveNodePos[fromNode.id]) ? liveNodePos[fromNode.id] : fromNode
    readonly property var toPos: (valid && liveNodePos[toNode.id]) ? liveNodePos[toNode.id] : toNode

    readonly property real startX: valid ? fromPos.x + nodeW : 0
    readonly property real startY: valid
        ? fromPos.y + nodeH * (fromPortIndex + 1) / (outputPortCount + 1)
        : 0
    readonly property real endX: valid ? toPos.x : 0
    readonly property real endY: valid ? toPos.y + nodeH / 2 : 0

    // Floors the horizontal reach of the control points so near-vertically
    // stacked nodes (small dx) still get a visible curve instead of the
    // bezier collapsing toward a straight, kinked-looking line.
    readonly property real cpOffset: Math.max(60, Math.min(Math.abs(endX - startX) * 0.6, 120))

    readonly property real pad: 130
    readonly property real bboxX: Math.min(startX, endX) - pad
    readonly property real bboxY: Math.min(startY, endY) - pad

    x: bboxX
    y: bboxY
    width: Math.abs(endX - startX) + 2 * pad
    height: Math.abs(endY - startY) + 2 * pad

    readonly property real lStartX: startX - bboxX
    readonly property real lStartY: startY - bboxY
    readonly property real lEndX: endX - bboxX
    readonly property real lEndY: endY - bboxY

    readonly property color edgeColor: {
        if (isSelected) return Theme.accent
        switch (edgeData.edgeType) {
        case "on_success":      return Theme.success
        case "on_failure":      return Theme.error
        case "condition_true":  return Theme.accent
        case "condition_false": return Theme.textSecondary
        default:                return Theme.textSecondary
        }
    }

    Shape {
        x: 0; y: 0
        width: parent.width; height: parent.height
        antialiasing: true

        ShapePath {
            strokeColor: edgeRoot.edgeColor
            strokeWidth: edgeRoot.isSelected ? 3 : 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            startX: edgeRoot.lStartX
            startY: edgeRoot.lStartY

            PathCubic {
                x: edgeRoot.lEndX
                y: edgeRoot.lEndY
                control1X: edgeRoot.lStartX + edgeRoot.cpOffset
                control1Y: edgeRoot.lStartY
                control2X: edgeRoot.lEndX - edgeRoot.cpOffset
                control2Y: edgeRoot.lEndY
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: edgeRoot.selectRequested()
    }
}
