// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// A Fork gains an output port per edge. DagNode grows taller so adjacent
// ports stay at least 16px apart instead of overlapping, and DagEdge must
// start each edge at the port DagNode actually draws.
//
// Tests don't assume a clean PipelineGraphModel (see tst_DagCanvasDragDrop.qml).
TestCase {
    id: testCase
    name: "DagNodePortSpacing"
    width: 1000
    height: 700
    visible: true
    when: windowShown

    readonly property real minPortPitch: 16

    DagNode {
        id: standaloneNode
        nodeData: ({ id: "portSpacingNode", type: "fork", x: 0, y: 0 })
        outputPortCount: 10
    }

    DagCanvas {
        id: canvas
        anchors.fill: parent
        // Default zoom/pan keeps screen and world coordinates identical.
    }

    function portCenterY(node, index) {
        const port = findChild(node, "dagNodeOutputPort_" + node.nodeData.id + "_" + index)
        verify(port !== null, "output port " + index + " not found")
        return port.y + port.height / 2
    }

    function test_nodesWithFewPortsKeepTheirHeight() {
        standaloneNode.outputPortCount = 1
        compare(standaloneNode.height, 56)
        standaloneNode.outputPortCount = 2
        compare(standaloneNode.height, 56)
    }

    function test_manyPortsKeepTheMinimumGap() {
        standaloneNode.outputPortCount = 10
        compare(standaloneNode.height, minPortPitch * 11, "the node should be just tall enough for its ports")

        for (let i = 1; i < 10; i++) {
            const gap = portCenterY(standaloneNode, i) - portCenterY(standaloneNode, i - 1)
            verify(gap >= minPortPitch - 0.001,
                   "ports " + (i - 1) + " and " + i + " are " + gap + "px apart")
        }
        verify(portCenterY(standaloneNode, 9) < standaloneNode.height, "the last port must sit on the node")
    }

    function test_edgesStartAtTheirForkPort() {
        const forkId = PipelineGraphModel.addNode("fork", 50, 50)
        const targetIds = []
        const edgeIds = []
        for (let i = 0; i < 6; i++) {
            const targetId = PipelineGraphModel.addNode("action", 400, 20 + i * 80)
            targetIds.push(targetId)
            PipelineGraphModel.addEdge(forkId, targetId, "normal")
        }
        for (const e of PipelineGraphModel.edges)
            if (e.fromNodeId === forkId)
                edgeIds.push(e.id)
        compare(edgeIds.length, 6)
        wait(50)

        const forkNode = findChild(canvas, "dagNode_" + forkId)
        verify(forkNode !== null, "fork node item not found")
        compare(canvas.outputPortCountFor(forkId), 7)
        verify(forkNode.height > 56, "a fork with 7 ports must be taller than the default")

        for (const edgeId of edgeIds) {
            const edgeItem = findChild(canvas, "dagEdge_" + edgeId)
            verify(edgeItem !== null, "edge item not found")
            const portIndex = canvas.portIndexForEdge(PipelineGraphModel.edges.find(e => e.id === edgeId))
            const port = forkNode.outputPortPos(portIndex)
            fuzzyCompare(edgeItem.startY, port.y, 0.001,
                         "edge from port " + portIndex + " must start at that port")
        }

        for (const edgeId of edgeIds)
            PipelineGraphModel.removeEdge(edgeId)
        for (const targetId of targetIds)
            PipelineGraphModel.removeNode(targetId)
        PipelineGraphModel.removeNode(forkId)
    }
}
