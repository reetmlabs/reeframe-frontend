// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Regression coverage for Transcode's Resolution field being a fixed preset
// dropdown (like its sibling Codec/Preset/Output format fields) rather than
// free text a user could mistype.
TestCase {
    id: testCase
    name: "NodeConfigPanelTranscodeResolution"
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

    function test_1_defaultsToAutoWithNoResolutionOverride() {
        testNodeId = PipelineGraphModel.addNode("action", 0, 0);
        panel.commitActionType("transcode");

        const cfg = PipelineGraphModel.nodeById(testNodeId).config;
        verify(cfg.resolution === undefined, "Auto must not send a resolution override");

        PipelineGraphModel.removeNode(testNodeId);
        testNodeId = "";
    }

    function test_2_selectingAPresetCommitsItsWireValue() {
        testNodeId = PipelineGraphModel.addNode("action", 0, 0);
        panel.commitActionType("transcode");

        const combo = findChild(panel, "nodeConfigTranscodeResolutionCombo");
        verify(combo !== null, "resolution combo not found");
        combo.currentIndex = 3; // 1920x1080 (Full HD)
        panel.commitConfig();

        compare(PipelineGraphModel.nodeById(testNodeId).config.resolution, "1920x1080");

        PipelineGraphModel.removeNode(testNodeId);
        testNodeId = "";
    }

    function test_3_reselectingANodeRestoresItsOwnResolution() {
        const nodeAId = PipelineGraphModel.addNode("action", 0, 0);
        const nodeBId = PipelineGraphModel.addNode("action", 0, 0);
        const combo = findChild(panel, "nodeConfigTranscodeResolutionCombo");
        verify(combo !== null, "resolution combo not found");

        testNodeId = nodeAId;
        panel.commitActionType("transcode");
        combo.currentIndex = 4; // 1280x720 (HD)
        panel.commitConfig();

        testNodeId = nodeBId;
        panel.commitActionType("transcode");
        compare(combo.currentIndex, 0,
                "a different node's resolution must not inherit the previous node's selection");

        testNodeId = nodeAId;
        compare(combo.currentIndex, 4, "reselecting node A must restore its own saved resolution");

        PipelineGraphModel.removeNode(nodeAId);
        PipelineGraphModel.removeNode(nodeBId);
        testNodeId = "";
    }
}
