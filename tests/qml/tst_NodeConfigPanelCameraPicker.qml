// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for Extract Clip's and Snapshot's Camera field being a
// searchable FormCameraCombo (like Start recording/Stop recording/PTZ move)
// rather than a raw UUID text box.
TestCase {
    id: testCase
    name: "NodeConfigPanelCameraPicker"
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

    function initTestCase() {
        CameraModel.clearTestCameras();
        CameraModel.insertTestCamera("cam-1", "Loading Dock");
        CameraModel.insertTestCamera("cam-2", "Front Gate");
    }

    function test_1_extractClipCommitsTheSelectedCameraId() {
        testNodeId = PipelineGraphModel.addNode("action", 0, 0);
        panel.commitActionType("extract_clip");

        const combo = findChild(panel, "nodeConfigExtractClipCameraCombo");
        verify(combo !== null, "extract clip camera combo not found");
        combo.cameraId = "cam-1";
        panel.commitConfig();

        compare(PipelineGraphModel.nodeById(testNodeId).config.camera_id, "cam-1");

        PipelineGraphModel.removeNode(testNodeId);
        testNodeId = "";
    }

    function test_2_snapshotCommitsTheSelectedCameraId() {
        testNodeId = PipelineGraphModel.addNode("action", 0, 0);
        panel.commitActionType("snapshot");

        const combo = findChild(panel, "nodeConfigSnapshotCameraCombo");
        verify(combo !== null, "snapshot camera combo not found");
        combo.cameraId = "cam-2";
        panel.commitConfig();

        compare(PipelineGraphModel.nodeById(testNodeId).config.camera_id, "cam-2");

        PipelineGraphModel.removeNode(testNodeId);
        testNodeId = "";
    }

    function test_3_reselectingAnExtractClipNodeRestoresItsOwnCamera() {
        const nodeAId = PipelineGraphModel.addNode("action", 0, 0);
        const nodeBId = PipelineGraphModel.addNode("action", 0, 0);
        const combo = findChild(panel, "nodeConfigExtractClipCameraCombo");
        verify(combo !== null, "extract clip camera combo not found");

        testNodeId = nodeAId;
        panel.commitActionType("extract_clip");
        combo.cameraId = "cam-1";
        panel.commitConfig();

        testNodeId = nodeBId;
        panel.commitActionType("extract_clip");
        compare(combo.cameraId, "",
                "a different node's camera field must not inherit the previous node's selection");

        testNodeId = nodeAId;
        compare(combo.cameraId, "cam-1", "reselecting node A must restore its own saved camera");

        PipelineGraphModel.removeNode(nodeAId);
        PipelineGraphModel.removeNode(nodeBId);
        testNodeId = "";
    }
}
