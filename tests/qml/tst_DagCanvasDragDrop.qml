// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for DagCanvas.qml's node drag (DagNode.qml's DragHandler) and
// port-click edge drawing. Real pointer-drag interactions like these are
// prone to crashes, silent no-ops, and data loss, so they're driven with
// real mouse events here.
//
// DagCanvas is tested standalone (not through the full PipelineEditorView)
// since that view's Component.onCompleted calls PipelineGraphModel.load(),
// a real network request. PipelineGraphModel's node/edge mutators
// (addNode/moveNode/addEdge) are pure in-memory operations with no backend
// dependency, so seeding state directly through them is sufficient.
//
// Tests don't assume a clean PipelineGraphModel: nodes/edges accumulate
// across test_* functions within one binary run (there's no per-test scope
// like TileLayoutModel's activeSiteId), so each test tracks only the ids it
// itself created and removes them again once done.
TestCase {
    id: testCase
    name: "DagCanvasDragDrop"
    width: 1000
    height: 700
    visible: true
    when: windowShown

    DagCanvas {
        id: canvas
        objectName: "dagCanvasUnderTest"
        anchors.fill: parent
        // Default zoom/pan (1.0, 0/0) keeps screen and world coordinates
        // identical, so node positions can be asserted directly.
    }

    function dragBy(item, dx, dy) {
        const start = testCase.mapFromItem(item, item.width / 2, item.height / 2);
        mousePress(testCase, start.x, start.y);

        const steps = 8;
        for (let i = 1; i <= steps; i++) {
            mouseMove(testCase, start.x + dx * (i / steps), start.y + dy * (i / steps));
            wait(10);
        }

        mouseRelease(testCase, start.x + dx, start.y + dy);
    }

    function test_dragMovesNodePosition() {
        const nodeId = PipelineGraphModel.addNode("action", 100, 100);
        verify(nodeId.length > 0, "addNode did not return an id");

        const node = findChild(canvas, "dagNode_" + nodeId);
        verify(node !== null, "dag node item not found");
        wait(50);

        dragBy(node, 120, 80);

        tryVerify(function() {
            const n = PipelineGraphModel.nodeById(nodeId);
            return Math.abs(n.x - 220) < 2 && Math.abs(n.y - 180) < 2;
        }, 5000, "node did not move to the expected dragged position");

        PipelineGraphModel.removeNode(nodeId);
    }

    function test_clickingOutputThenInputPortDrawsEdge() {
        const fromId = PipelineGraphModel.addNode("action", 50, 50);
        const toId = PipelineGraphModel.addNode("action", 400, 300);
        verify(fromId.length > 0 && toId.length > 0, "addNode did not return ids");

        const outputPort = findChild(canvas, "dagNodeOutputPort_" + fromId + "_0");
        verify(outputPort !== null, "output port not found");
        const inputPort = findChild(canvas, "dagNodeInputPort_" + toId);
        verify(inputPort !== null, "input port not found");
        wait(50);

        mouseClick(outputPort, outputPort.width / 2, outputPort.height / 2);
        verify(canvas.drawingEdge, "canvas should enter edge-drawing mode after an output port click");
        compare(canvas.edgeFromNodeId, fromId);

        mouseClick(inputPort, inputPort.width / 2, inputPort.height / 2);
        verify(!canvas.drawingEdge, "canvas should leave edge-drawing mode once the edge is completed");

        const edges = PipelineGraphModel.edges;
        const newEdge = edges.find(e => e.fromNodeId === fromId && e.toNodeId === toId);
        verify(newEdge !== undefined, "expected a new edge from the output node to the input node");
        compare(newEdge.edgeType, "normal");

        PipelineGraphModel.removeEdge(newEdge.id);
        PipelineGraphModel.removeNode(fromId);
        PipelineGraphModel.removeNode(toId);
    }

    function test_conditionNodeOutputPortsProduceTrueFalseEdgeTypes() {
        const condId = PipelineGraphModel.addNode("condition", 50, 50);
        const trueTargetId = PipelineGraphModel.addNode("action", 400, 20);
        const falseTargetId = PipelineGraphModel.addNode("action", 400, 300);
        verify(condId.length > 0 && trueTargetId.length > 0 && falseTargetId.length > 0,
               "addNode did not return ids");

        const truePort = findChild(canvas, "dagNodeOutputPort_" + condId + "_0");
        const falsePort = findChild(canvas, "dagNodeOutputPort_" + condId + "_1");
        const trueTargetPort = findChild(canvas, "dagNodeInputPort_" + trueTargetId);
        const falseTargetPort = findChild(canvas, "dagNodeInputPort_" + falseTargetId);
        verify(truePort !== null && falsePort !== null, "condition node's two output ports not found");
        verify(trueTargetPort !== null && falseTargetPort !== null, "target input ports not found");
        wait(50);

        mouseClick(truePort, truePort.width / 2, truePort.height / 2);
        mouseClick(trueTargetPort, trueTargetPort.width / 2, trueTargetPort.height / 2);
        let edges = PipelineGraphModel.edges;
        const trueEdge = edges.find(e => e.fromNodeId === condId && e.toNodeId === trueTargetId);
        verify(trueEdge !== undefined, "expected an edge from the condition node's first (true) port");
        compare(trueEdge.edgeType, "condition_true");

        mouseClick(falsePort, falsePort.width / 2, falsePort.height / 2);
        mouseClick(falseTargetPort, falseTargetPort.width / 2, falseTargetPort.height / 2);
        edges = PipelineGraphModel.edges;
        const falseEdge = edges.find(e => e.fromNodeId === condId && e.toNodeId === falseTargetId);
        verify(falseEdge !== undefined, "expected an edge from the condition node's second (false) port");
        compare(falseEdge.edgeType, "condition_false");

        PipelineGraphModel.removeEdge(trueEdge.id);
        PipelineGraphModel.removeEdge(falseEdge.id);
        PipelineGraphModel.removeNode(condId);
        PipelineGraphModel.removeNode(trueTargetId);
        PipelineGraphModel.removeNode(falseTargetId);
    }

    function test_forkNodeBothOutputPortsProduceNormalEdgeType() {
        const forkId = PipelineGraphModel.addNode("fork", 50, 50);
        const targetAId = PipelineGraphModel.addNode("action", 400, 20);
        const targetBId = PipelineGraphModel.addNode("action", 400, 300);
        verify(forkId.length > 0 && targetAId.length > 0 && targetBId.length > 0,
               "addNode did not return ids");

        const portA = findChild(canvas, "dagNodeOutputPort_" + forkId + "_0");
        const portB = findChild(canvas, "dagNodeOutputPort_" + forkId + "_1");
        const targetAPort = findChild(canvas, "dagNodeInputPort_" + targetAId);
        const targetBPort = findChild(canvas, "dagNodeInputPort_" + targetBId);
        verify(portA !== null && portB !== null, "fork node's two output ports not found");
        verify(targetAPort !== null && targetBPort !== null, "target input ports not found");
        wait(50);

        // Unlike condition, DagCanvas.edgeTypeFor only special-cases the
        // "condition" node type. A fork's two branches are structurally
        // symmetric, so both ports produce a plain "normal" edge.
        mouseClick(portA, portA.width / 2, portA.height / 2);
        mouseClick(targetAPort, targetAPort.width / 2, targetAPort.height / 2);
        let edges = PipelineGraphModel.edges;
        const edgeA = edges.find(e => e.fromNodeId === forkId && e.toNodeId === targetAId);
        verify(edgeA !== undefined, "expected an edge from the fork node's first port");
        compare(edgeA.edgeType, "normal");

        mouseClick(portB, portB.width / 2, portB.height / 2);
        mouseClick(targetBPort, targetBPort.width / 2, targetBPort.height / 2);
        edges = PipelineGraphModel.edges;
        const edgeB = edges.find(e => e.fromNodeId === forkId && e.toNodeId === targetBId);
        verify(edgeB !== undefined, "expected an edge from the fork node's second port");
        compare(edgeB.edgeType, "normal");

        PipelineGraphModel.removeEdge(edgeA.id);
        PipelineGraphModel.removeEdge(edgeB.id);
        PipelineGraphModel.removeNode(forkId);
        PipelineGraphModel.removeNode(targetAId);
        PipelineGraphModel.removeNode(targetBId);
    }

    function test_forkNodeGrowsPastTwoOutputsAsEdgesAreAdded() {
        const forkId = PipelineGraphModel.addNode("fork", 50, 50);
        const targetAId = PipelineGraphModel.addNode("action", 400, 20);
        const targetBId = PipelineGraphModel.addNode("action", 400, 200);
        const targetCId = PipelineGraphModel.addNode("action", 400, 380);
        verify(forkId.length > 0 && targetAId.length > 0 && targetBId.length > 0 && targetCId.length > 0,
               "addNode did not return ids");
        wait(50);

        compare(canvas.outputPortCountFor(forkId), 2, "an unconnected fork should start with 2 ports");
        verify(findChild(canvas, "dagNodeOutputPort_" + forkId + "_2") === null,
               "a 3rd port should not exist before it's needed");

        const portA = findChild(canvas, "dagNodeOutputPort_" + forkId + "_0");
        const portB = findChild(canvas, "dagNodeOutputPort_" + forkId + "_1");
        mouseClick(portA, portA.width / 2, portA.height / 2);
        const targetAPort = findChild(canvas, "dagNodeInputPort_" + targetAId);
        mouseClick(targetAPort, targetAPort.width / 2, targetAPort.height / 2);
        mouseClick(portB, portB.width / 2, portB.height / 2);
        const targetBPort = findChild(canvas, "dagNodeInputPort_" + targetBId);
        mouseClick(targetBPort, targetBPort.width / 2, targetBPort.height / 2);

        let edges = PipelineGraphModel.edges;
        const edgeA = edges.find(e => e.fromNodeId === forkId && e.toNodeId === targetAId);
        const edgeB = edges.find(e => e.fromNodeId === forkId && e.toNodeId === targetBId);
        verify(edgeA !== undefined && edgeB !== undefined, "expected edges from the fork's first two ports");

        // Both ports now used, so a 3rd, still-empty port must appear so a 5th
        // (or 6th, ...) branch never requires chaining another Fork node.
        compare(canvas.outputPortCountFor(forkId), 3, "a fully-connected fork must grow a fresh empty port");
        const portC = findChild(canvas, "dagNodeOutputPort_" + forkId + "_2");
        verify(portC !== null, "3rd port must exist once the first two are wired");

        mouseClick(portC, portC.width / 2, portC.height / 2);
        const targetCPort = findChild(canvas, "dagNodeInputPort_" + targetCId);
        mouseClick(targetCPort, targetCPort.width / 2, targetCPort.height / 2);
        edges = PipelineGraphModel.edges;
        const edgeC = edges.find(e => e.fromNodeId === forkId && e.toNodeId === targetCId);
        verify(edgeC !== undefined, "expected an edge from the fork's 3rd port");

        // Each edge's rendered port must match the port it was actually
        // drawn from, in order. DagEdge.qml positions itself off this.
        compare(canvas.portIndexForEdge(edgeA), 0);
        compare(canvas.portIndexForEdge(edgeB), 1);
        compare(canvas.portIndexForEdge(edgeC), 2);

        PipelineGraphModel.removeEdge(edgeA.id);
        PipelineGraphModel.removeEdge(edgeB.id);
        PipelineGraphModel.removeEdge(edgeC.id);
        PipelineGraphModel.removeNode(forkId);
        PipelineGraphModel.removeNode(targetAId);
        PipelineGraphModel.removeNode(targetBId);
        PipelineGraphModel.removeNode(targetCId);
    }

    function test_clickingSameNodeInputCancelsEdgeDraw() {
        const nodeId = PipelineGraphModel.addNode("action", 200, 200);
        verify(nodeId.length > 0, "addNode did not return an id");

        const outputPort = findChild(canvas, "dagNodeOutputPort_" + nodeId + "_0");
        const inputPort = findChild(canvas, "dagNodeInputPort_" + nodeId);
        verify(outputPort !== null && inputPort !== null, "ports not found");
        wait(50);

        const edgeCountBefore = PipelineGraphModel.edges.length;

        mouseClick(outputPort, outputPort.width / 2, outputPort.height / 2);
        verify(canvas.drawingEdge);

        // A node's own input port is not a valid target for its own output.
        // DagCanvas.onInputPortClicked ignores this case rather than creating
        // a self-loop edge, but should leave edge-drawing mode untouched so
        // the user can still complete the connection elsewhere.
        mouseClick(inputPort, inputPort.width / 2, inputPort.height / 2);
        compare(PipelineGraphModel.edges.length, edgeCountBefore,
                "clicking a node's own input port must not create a self-loop edge");

        canvas.drawingEdge = false;
        canvas.edgeFromNodeId = "";
        PipelineGraphModel.removeNode(nodeId);
    }

    function test_canvasClipsItsOwnContent() {
        compare(canvas.clip, true,
                "a node dragged past the canvas edge must not render over neighboring panels");
    }
}
