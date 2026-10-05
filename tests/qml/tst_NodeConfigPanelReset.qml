// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Regression coverage for resetFromConfig() restoring a node's own
// type-specific fields when it's (re)selected, rather than leaving whatever
// a previously-selected node of the same action type left behind. The
// Compress/Algorithm and Level fields are shared widget instances across
// every node, so nothing resets them without this.
//
// Tests don't assume a clean PipelineGraphModel (see tst_DagCanvasDragDrop.qml).
TestCase {
    id: testCase
    name: "NodeConfigPanelReset"
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

    function test_1_reselectingACompressNodeRestoresItsOwnAlgorithmAndLevel() {
        const nodeAId = PipelineGraphModel.addNode("action", 0, 0);
        const nodeBId = PipelineGraphModel.addNode("action", 0, 0);

        const algoCombo = findChild(panel, "nodeConfigCompressAlgorithmCombo");
        const levelBox = findChild(panel, "nodeConfigCompressLevelBox");
        verify(algoCombo !== null && levelBox !== null, "compress controls not found");

        // Node A: pick Compress, then move its fields away from the
        // defaults commitActionType() just committed.
        testNodeId = nodeAId;
        panel.commitActionType("compress");
        algoCombo.currentIndex = 1; // gzip
        levelBox.value = 17;
        panel.commitConfig();
        compare(PipelineGraphModel.nodeById(nodeAId).config.algorithm, "gzip");
        compare(PipelineGraphModel.nodeById(nodeAId).config.level, 17);

        // Node B: a different, freshly-created Compress node. Selecting it
        // must show its OWN (default) values, not node A's leftover gzip/17.
        testNodeId = nodeBId;
        panel.commitActionType("compress");
        compare(algoCombo.currentIndex, 0,
                "a different node's Compress fields must not inherit the previous node's values");
        compare(levelBox.value, 3);

        // Re-selecting node A must restore its own saved values too.
        testNodeId = nodeAId;
        compare(algoCombo.currentIndex, 1, "reselecting node A must restore its own saved algorithm");
        compare(levelBox.value, 17);

        PipelineGraphModel.removeNode(nodeAId);
        PipelineGraphModel.removeNode(nodeBId);
        testNodeId = "";
    }
}
