// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Mouse handling on the pipeline canvas, driven with real mouse events.
// Nodes and ports handle their own presses. Every other press goes to the
// canvas: a click within a few pixels of an edge's line selects that edge,
// a click anywhere else clears the selection, and a press that moves past
// the drag distance pans instead, wherever it started.
//
// Tests don't assume a clean PipelineGraphModel (see tst_DagCanvasDragDrop.qml),
// so each one removes the nodes it created.
TestCase {
    id: testCase
    name: "DagCanvasPointer"
    width: 1000
    height: 700
    visible: true
    when: windowShown

    DagCanvas {
        id: canvas
        anchors.fill: parent
        // Default zoom/pan (1.0, 0/0) keeps screen and world coordinates
        // identical until a test pans.
    }

    property string aId: ""
    property string bId: ""
    property string edgeId: ""

    // Two nodes far enough apart that the edge between them passes through a
    // large stretch of empty canvas.
    function init() {
        canvas.panX = 0
        canvas.panY = 0
        canvas.selectId("")
        aId = PipelineGraphModel.addNode("action", 100, 100)
        bId = PipelineGraphModel.addNode("action", 600, 400)
        edgeId = PipelineGraphModel.addEdge(aId, bId, "normal")
        wait(50)
    }

    function cleanup() {
        PipelineGraphModel.removeNode(aId)
        PipelineGraphModel.removeNode(bId)
        aId = bId = edgeId = ""
    }

    function edgeItem() {
        const edge = findChild(canvas, "dagEdge_" + edgeId)
        verify(edge !== null, "edge item not found")
        return edge
    }

    // The edge's start and end control points pull out horizontally by the
    // same amount, so the curve passes through the midpoint of its ends.
    function edgeMidpoint() {
        const edge = edgeItem()
        return Qt.point((edge.startX + edge.endX) / 2, (edge.startY + edge.endY) / 2)
    }

    function dragOnCanvas(x, y, dx, dy) {
        mousePress(testCase, x, y)
        const steps = 8
        for (let i = 1; i <= steps; i++) {
            mouseMove(testCase, x + dx * i / steps, y + dy * i / steps)
            wait(10)
        }
        mouseRelease(testCase, x + dx, y + dy)
    }

    function test_clickingEmptySpaceNearAnEdgeSelectsNothing() {
        canvas.selectId(aId)
        // Inside the edge's bounding box, but well away from its line.
        mouseClick(testCase, 550, 130)
        compare(canvas.selectedId, "", "a click on empty space must clear the selection")
    }

    function test_clickingAnEdgeLineSelectsIt() {
        const mid = edgeMidpoint()
        mouseClick(testCase, mid.x, mid.y)
        compare(canvas.selectedId, edgeId)
    }

    function test_clickingJustOutsideTheToleranceMissesTheEdge() {
        const mid = edgeMidpoint()
        mouseClick(testCase, mid.x, mid.y - 30)
        compare(canvas.selectedId, "")
    }

    function test_draggingEmptySpaceInsideTheGraphPans() {
        canvas.selectId(aId)
        dragOnCanvas(550, 130, 80, 40)
        compare(canvas.panX, 80)
        compare(canvas.panY, 40)
        compare(canvas.selectedId, aId, "panning must not change the selection")
    }

    function test_draggingFromAnEdgeLinePans() {
        const mid = edgeMidpoint()
        dragOnCanvas(mid.x, mid.y, -60, 30)
        compare(canvas.panX, -60)
        compare(canvas.panY, 30)
        compare(canvas.selectedId, "", "a press that pans must not select the edge")
    }

    function test_aShakyClickStillCountsAsAClick() {
        const mid = edgeMidpoint()
        mousePress(testCase, mid.x, mid.y)
        mouseMove(testCase, mid.x + 1, mid.y + 1)
        mouseRelease(testCase, mid.x + 1, mid.y + 1)
        compare(canvas.panX, 0, "movement under the drag distance must not pan")
        compare(canvas.selectedId, edgeId)
    }

    function test_clickingANodeSelectsIt() {
        const node = findChild(canvas, "dagNode_" + aId)
        verify(node !== null, "node item not found")
        mouseClick(node, node.width / 2, node.height / 2)
        compare(canvas.selectedId, aId)
    }

    function test_draggingANodeWithEdgesMovesIt() {
        const node = findChild(canvas, "dagNode_" + aId)
        verify(node !== null, "node item not found")
        const start = testCase.mapFromItem(node, node.width / 2, node.height / 2)
        dragOnCanvas(start.x, start.y, 120, 80)
        const moved = PipelineGraphModel.nodeById(aId)
        compare(moved.x, 220)
        compare(moved.y, 180)
        compare(canvas.panX, 0, "dragging a node must not pan the canvas")
    }
}
