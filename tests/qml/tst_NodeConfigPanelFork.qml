// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// A Fork node has no config, so NodeConfigPanel shows only its label field.
// The action-type picker must stay hidden: picking an action there would
// overwrite the Fork's label with the action's name.
//
// Tests don't assume a clean PipelineGraphModel (see tst_DagCanvasDragDrop.qml).
TestCase {
    id: testCase
    name: "NodeConfigPanelFork"
    width: 400
    height: 600
    visible: true
    when: windowShown

    property string testNodeId: ""

    readonly property var testNodeData: {
        const _ = PipelineGraphModel.nodes
        return testNodeId === "" ? ({}) : PipelineGraphModel.nodeById(testNodeId)
    }

    NodeConfigPanel {
        id: panel
        width: 400
        height: 600
        nodeData: testCase.testNodeData
    }

    function cleanup() {
        if (testNodeId !== "")
            PipelineGraphModel.removeNode(testNodeId)
        testNodeId = ""
    }

    function test_forkShowsOnlyTheLabelField() {
        testNodeId = PipelineGraphModel.addNode("fork", 0, 0)

        const labelField = findChild(panel, "nodeConfigLabelField")
        const typeSection = findChild(panel, "nodeConfigTypeSection")
        verify(labelField !== null && typeSection !== null, "panel controls not found")

        verify(labelField.visible)
        verify(!typeSection.visible, "a Fork must not show the action-type picker")
    }

    function test_editingTheLabelRenamesTheFork() {
        testNodeId = PipelineGraphModel.addNode("fork", 0, 0)

        const labelField = findChild(panel, "nodeConfigLabelField")
        verify(labelField !== null, "label field not found")

        labelField.forceActiveFocus()
        labelField.selectAll()
        keyClick(Qt.Key_Delete)
        for (const ch of "Split by zone")
            keyClick(ch)
        keyClick(Qt.Key_Return)

        compare(PipelineGraphModel.nodeById(testNodeId).label, "Split by zone")
    }

    function test_actionNodeStillShowsTheActionTypePicker() {
        testNodeId = PipelineGraphModel.addNode("action", 0, 0)

        const typeSection = findChild(panel, "nodeConfigTypeSection")
        verify(typeSection !== null, "type section not found")
        verify(typeSection.visible)
    }
}
