// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for DagCanvas.duplicateSelected(), which the pipeline editor runs
// on Ctrl+D. The copy keeps the node's type, label and config, lands one
// Theme.spaceXl down and to the right, has no edges and becomes the
// selection. The trigger and edges are never copied.
//
// Tests don't assume a clean PipelineGraphModel (see tst_DagCanvasDragDrop.qml),
// so each one removes the nodes it created, copies included.
TestCase {
    id: testCase
    name: "DagCanvasDuplicate"
    width: 800
    height: 600
    visible: true
    when: windowShown

    DagCanvas {
        id: canvas
        anchors.fill: parent
    }

    property var createdIds: []

    function track(id) {
        createdIds.push(id)
        return id
    }

    function nodeIds() {
        return PipelineGraphModel.nodes.map(n => n.id)
    }

    function edgesTouching(nodeId) {
        return PipelineGraphModel.edges.filter(e => e.fromNodeId === nodeId || e.toNodeId === nodeId)
    }

    function cleanup() {
        canvas.selectId("")
        for (const id of createdIds)
            PipelineGraphModel.removeNode(id)
        createdIds = []
    }

    // Duplicates the current selection and returns the new node's id, or ""
    // if no node was added.
    function duplicate() {
        const before = nodeIds()
        canvas.duplicateSelected()
        const added = nodeIds().filter(id => !before.includes(id))
        verify(added.length <= 1, "at most one node may be added per duplicate")
        return added.length === 1 ? track(added[0]) : ""
    }

    function test_copyKeepsTypeLabelAndConfigWithoutEdges() {
        const sourceId = track(PipelineGraphModel.addNode("action", 100, 100))
        const targetId = track(PipelineGraphModel.addNode("action", 400, 100))
        PipelineGraphModel.updateNodeLabel(sourceId, "Make clip")
        PipelineGraphModel.updateNodeConfig(sourceId, { action_type: "delay", seconds: 5 })
        PipelineGraphModel.addEdge(sourceId, targetId, "normal")

        canvas.selectId(sourceId)
        const copyId = duplicate()
        verify(copyId !== "", "duplicating an action node should add a copy")
        verify(copyId !== sourceId)

        const source = PipelineGraphModel.nodeById(sourceId)
        const copy = PipelineGraphModel.nodeById(copyId)
        compare(copy.type, "action")
        compare(copy.label, "Make clip")
        compare(JSON.stringify(copy.config), JSON.stringify(source.config))
        compare(copy.x, source.x + Theme.spaceXl)
        compare(copy.y, source.y + Theme.spaceXl)
        compare(edgesTouching(copyId).length, 0, "the copy must start with no edges")
        compare(edgesTouching(sourceId).length, 1, "the original keeps its edge")
        compare(canvas.selectedId, copyId, "the copy should become the selection")
    }

    function test_repeatedDuplicatesStepDiagonally() {
        const sourceId = track(PipelineGraphModel.addNode("fork", 200, 200))
        canvas.selectId(sourceId)

        const firstId = duplicate()
        const secondId = duplicate()
        verify(firstId !== "" && secondId !== "")

        const first = PipelineGraphModel.nodeById(firstId)
        const second = PipelineGraphModel.nodeById(secondId)
        compare(second.x, first.x + Theme.spaceXl)
        compare(second.y, first.y + Theme.spaceXl)
        compare(canvas.selectedId, secondId)
    }

    function test_triggerIsNotDuplicated() {
        const triggerId = track(PipelineGraphModel.addNode("trigger_root", 0, 0))
        canvas.selectId(triggerId)

        compare(duplicate(), "", "the trigger must not be copied")
        compare(canvas.selectedId, triggerId)
    }

    function test_edgeIsNotDuplicated() {
        const aId = track(PipelineGraphModel.addNode("action", 0, 300))
        const bId = track(PipelineGraphModel.addNode("action", 300, 300))
        const edgeId = PipelineGraphModel.addEdge(aId, bId, "normal")
        canvas.selectId(edgeId)

        compare(duplicate(), "", "an edge must not be copied")
        compare(canvas.selectedId, edgeId)
    }

    function test_nothingSelectedDoesNothing() {
        canvas.selectId("")
        compare(duplicate(), "")
    }
}
