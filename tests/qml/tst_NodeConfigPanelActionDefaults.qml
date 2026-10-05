// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Selecting an action type must immediately persist its full default
// config, not just action_type. Some action configs (e.g.
// compress's algorithm, encrypt's algorithm) are required fields on the
// backend with no valid "unset" state, so leaving them out until some other
// field is touched makes the backend 400 the whole pipeline save with
// "missing field algorithm". See NodeConfigPanel.qml's commitActionType().
//
// Tests don't assume a clean PipelineGraphModel (see tst_DagCanvasDragDrop.qml),
// so each test removes the node it created.
TestCase {
    id: testCase
    name: "NodeConfigPanelActionDefaults"
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

    function test_1_selectingCompressCommitsItsDefaultAlgorithm() {
        testNodeId = PipelineGraphModel.addNode("action", 0, 0);

        panel.commitActionType("compress");

        const cfg = PipelineGraphModel.nodeById(testNodeId).config;
        compare(cfg.algorithm, "zstd");
        verify(cfg.level !== undefined, "level must be committed alongside algorithm");

        PipelineGraphModel.removeNode(testNodeId);
        testNodeId = "";
    }

    function test_2_selectingEncryptCommitsItsDefaultAlgorithm() {
        testNodeId = PipelineGraphModel.addNode("action", 0, 0);

        panel.commitActionType("encrypt");

        const cfg = PipelineGraphModel.nodeById(testNodeId).config;
        compare(cfg.algorithm, "aes256_gcm");
        verify(cfg.key_ref !== undefined, "key_ref must be committed alongside algorithm");

        PipelineGraphModel.removeNode(testNodeId);
        testNodeId = "";
    }

    function test_3_clearingTheActionTypeDoesNotCommitAnyTypeDefaults() {
        testNodeId = PipelineGraphModel.addNode("action", 0, 0);

        panel.commitActionType("");

        const cfg = PipelineGraphModel.nodeById(testNodeId).config;
        compare(cfg.action_type, "");
        verify(cfg.algorithm === undefined, "no type means no type-specific defaults");

        PipelineGraphModel.removeNode(testNodeId);
        testNodeId = "";
    }
}
