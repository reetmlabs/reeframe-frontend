// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for DagCanvas.revealNode()/revealNodes(), the "jump to and
// highlight a node (or several)" plumbing a problems list entry uses, kept
// separate from tst_DagCanvasProblems.qml since it's about navigation/
// highlight, not the problem rules themselves.
TestCase {
    id: testCase
    name: "DagCanvasReveal"
    width: 400
    height: 300
    visible: true
    when: windowShown

    DagCanvas {
        id: canvas
        anchors.fill: parent
    }

    function test_revealNodeSelectsAndCentersOnIt() {
        const nodeId = PipelineGraphModel.addNode("action", 500, 500)

        canvas.revealNode(nodeId)

        compare(canvas.selectedId, nodeId)
        const centre = canvas.screenToWorld(canvas.width / 2, canvas.height / 2)
        verify(Math.abs(centre.x - 580) < 1) // node.x (500) + half its 160 width
        verify(Math.abs(centre.y - 528) < 1) // node.y (500) + half its 56 height

        PipelineGraphModel.removeNode(nodeId)
    }

    function test_revealNodesHighlightsAllWithNoSingleSelection() {
        const aId = PipelineGraphModel.addNode("action", 0, 0)
        const bId = PipelineGraphModel.addNode("action", 200, 0)

        canvas.revealNodes([aId, bId])

        compare(canvas.selectedId, "")
        compare(canvas.highlightedIds, [aId, bId])

        const nodeA = findChild(canvas, "dagNode_" + aId)
        const nodeB = findChild(canvas, "dagNode_" + bId)
        compare(nodeA.isSelected, true)
        compare(nodeB.isSelected, true)

        PipelineGraphModel.removeNode(aId)
        PipelineGraphModel.removeNode(bId)
    }

    function test_selectingAfterRevealNodesClearsTheHighlight() {
        const aId = PipelineGraphModel.addNode("action", 0, 0)
        const bId = PipelineGraphModel.addNode("action", 200, 0)
        canvas.revealNodes([aId, bId])

        canvas.selectId(aId)

        compare(canvas.highlightedIds, [])
        const nodeB = findChild(canvas, "dagNode_" + bId)
        compare(nodeB.isSelected, false)

        PipelineGraphModel.removeNode(aId)
        PipelineGraphModel.removeNode(bId)
    }
}
