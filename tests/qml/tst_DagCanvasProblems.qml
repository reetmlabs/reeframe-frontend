// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for DagCanvas.problems/.problemsForNode(), the live wiring between
// PipelineValidation.js and the currently-loaded PipelineGraphModel/CameraModel
// state. The rules themselves are covered in tst_PipelineValidation.qml; this
// only checks that DagCanvas feeds them the right data.
TestCase {
    id: testCase
    name: "DagCanvasProblems"
    width: 400
    height: 300
    visible: true
    when: windowShown

    DagCanvas {
        id: canvas
        anchors.fill: parent
    }

    function test_incompleteConditionNodeHasAProblem() {
        const condId = PipelineGraphModel.addNode("condition", 50, 50)

        verify(canvas.problemsForNode(condId).length > 0)

        PipelineGraphModel.removeNode(condId)
    }

    function test_deletedCameraShowsUpAsADanglingReference() {
        CameraModel.clearTestCameras()
        const forkId = PipelineGraphModel.addNode("device_control", 50, 50)
        PipelineGraphModel.updateNodeConfig(forkId, { action_type: "start_recording", camera_id: "gone" })

        verify(canvas.problemsForNode(forkId).some((p) => p.category === "dangling_camera"))

        CameraModel.insertTestCamera("gone", "Recovered Camera", false)
        verify(!canvas.problemsForNode(forkId).some((p) => p.category === "dangling_camera"))

        PipelineGraphModel.removeNode(forkId)
        CameraModel.clearTestCameras()
    }

    function test_problemBadgeShowsAndClearsOnTheNode() {
        const condId = PipelineGraphModel.addNode("condition", 50, 50)
        wait(50)

        const badge = findChild(canvas, "dagNodeProblemBadge_" + condId)
        verify(badge !== null, "problem badge not found")
        compare(badge.visible, true)

        const trueId = PipelineGraphModel.addNode("action", 300, 20)
        const falseId = PipelineGraphModel.addNode("action", 300, 200)
        PipelineGraphModel.updateNodeConfig(trueId, { action_type: "skip" })
        PipelineGraphModel.updateNodeConfig(falseId, { action_type: "skip" })
        PipelineGraphModel.updateNodeConfig(condId, { condition_expr: "score > 0.5" })
        PipelineGraphModel.addEdge(condId, trueId, "condition_true")
        PipelineGraphModel.addEdge(condId, falseId, "condition_false")

        tryCompare(badge, "visible", false)

        PipelineGraphModel.removeNode(condId)
        PipelineGraphModel.removeNode(trueId)
        PipelineGraphModel.removeNode(falseId)
    }
}
