// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import "../../qml/PipelineValidation.js" as PipelineValidation

// Coverage for the pure-JS pipeline validation rules (see PipelineValidation.js
// for why this has no Qt/QML dependency): plain node/edge arrays in, a
// problems array out, no PipelineGraphModel or DagCanvas involved.
TestCase {
    name: "PipelineValidation"

    function node(id, type) {
        return { id: id, type: type, label: "", config: {}, x: 0, y: 0 }
    }

    function edge(id, fromNodeId, toNodeId, edgeType) {
        return { id: id, fromNodeId: fromNodeId, toNodeId: toNodeId, edgeType: edgeType || "normal" }
    }

    function test_noTriggerNodeIsAnError() {
        const problems = PipelineValidation.computeProblems([node("a", "action")], [], [])
        verify(problems.some((p) => p.category === "structural" && p.message.includes("No trigger")))
    }

    function test_twoTriggerNodesIsAnError() {
        const nodes = [node("t1", "trigger_root"), node("t2", "trigger_root")]
        const problems = PipelineValidation.computeProblems(nodes, [], [])
        const p = problems.find((p) => p.message.includes("More than one trigger"))
        verify(p !== undefined)
        compare(p.nodeIds.length, 2)
    }

    function test_singleTriggerNodeIsNotAnError() {
        const problems = PipelineValidation.computeProblems([node("t1", "trigger_root")], [], [])
        verify(!problems.some((p) => p.message.includes("trigger")))
    }

    function test_cycleIsDetected() {
        const nodes = [node("t1", "trigger_root"), node("a", "action"), node("b", "action")]
        const edges = [edge("e1", "a", "b"), edge("e2", "b", "a")]
        const problems = PipelineValidation.computeProblems(nodes, edges, [])
        const p = problems.find((p) => p.category === "structural" && p.message.includes("Cycle"))
        verify(p !== undefined)
        compare(p.nodeIds.sort(), ["a", "b"])
    }

    function test_acyclicChainHasNoCycleProblem() {
        const nodes = [node("t1", "trigger_root"), node("a", "action"), node("b", "action")]
        const edges = [edge("e1", "t1", "a"), edge("e2", "a", "b")]
        const problems = PipelineValidation.computeProblems(nodes, edges, [])
        verify(!problems.some((p) => p.message.includes("Cycle")))
    }

    function test_conditionWithBothBranchesIsFine() {
        const nodes = [node("t1", "trigger_root"), node("c", "condition"), node("a", "action"), node("b", "action")]
        nodes[1].config = { condition_expr: "score > 0.5" }
        const edges = [
            edge("e1", "t1", "c"),
            edge("e2", "c", "a", "condition_true"),
            edge("e3", "c", "b", "condition_false"),
        ]
        const problems = PipelineValidation.computeProblems(nodes, edges, [])
        verify(!problems.some((p) => p.nodeId === "c"))
    }

    function test_conditionWithOnlyOneBranchIsAnError() {
        const nodes = [node("t1", "trigger_root"), node("c", "condition"), node("a", "action")]
        const edges = [edge("e1", "t1", "c"), edge("e2", "c", "a", "condition_true")]
        const problems = PipelineValidation.computeProblems(nodes, edges, [])
        verify(problems.some((p) => p.nodeId === "c" && p.severity === "error"))
    }

    function test_transportWithOutgoingEdgeIsAnError() {
        const nodes = [node("t1", "trigger_root"), node("tr", "transport"), node("a", "action")]
        const edges = [edge("e1", "t1", "tr"), edge("e2", "tr", "a")]
        const problems = PipelineValidation.computeProblems(nodes, edges, [])
        verify(problems.some((p) => p.nodeId === "tr" && p.message.includes("outgoing edge")))
    }

    function test_transportWithNoOutgoingEdgeIsFine() {
        const nodes = [node("t1", "trigger_root"), node("tr", "transport")]
        nodes[1].config = { destination_id: "dest-1" }
        const edges = [edge("e1", "t1", "tr")]
        const problems = PipelineValidation.computeProblems(nodes, edges, [])
        verify(!problems.some((p) => p.nodeId === "tr"))
    }

    function test_triggerWithNoTypeSelectedIsAnError() {
        const t1 = node("t1", "trigger_root")
        const problems = PipelineValidation.computeProblems([t1], [], [])
        verify(problems.some((p) => p.nodeId === "t1" && p.category === "config_incomplete"))
    }

    function test_scheduleTriggerWithNoCronIsAnError() {
        const t1 = node("t1", "trigger_root")
        t1.config = { trigger_type: "schedule" }
        const problems = PipelineValidation.computeProblems([t1], [], [])
        verify(problems.some((p) => p.nodeId === "t1" && p.message.includes("cron")))
    }

    function test_scheduleTriggerWithCronIsFine() {
        const t1 = node("t1", "trigger_root")
        t1.config = { trigger_type: "schedule", cron: "0 * * * *" }
        const problems = PipelineValidation.computeProblems([t1], [], [])
        verify(!problems.some((p) => p.nodeId === "t1"))
    }

    function test_manualTriggerNeedsNoOtherField() {
        const t1 = node("t1", "trigger_root")
        t1.config = { trigger_type: "manual" }
        const problems = PipelineValidation.computeProblems([t1], [], [])
        verify(!problems.some((p) => p.nodeId === "t1"))
    }

    function test_conditionWithNoExpressionIsAnError() {
        const nodes = [node("t1", "trigger_root"), node("c", "condition")]
        const problems = PipelineValidation.computeProblems(nodes, [edge("e1", "t1", "c")], [])
        verify(problems.some((p) => p.nodeId === "c" && p.category === "config_incomplete"))
    }

    function test_transportWithNoDestinationIsAnError() {
        const nodes = [node("t1", "trigger_root"), node("tr", "transport")]
        const problems = PipelineValidation.computeProblems(nodes, [edge("e1", "t1", "tr")], [])
        verify(problems.some((p) => p.nodeId === "tr" && p.category === "config_incomplete"))
    }

    function test_transportWithDestinationIsFine() {
        const nodes = [node("t1", "trigger_root"), node("tr", "transport")]
        nodes[1].config = { destination_id: "dest-1" }
        const problems = PipelineValidation.computeProblems(nodes, [edge("e1", "t1", "tr")], [])
        verify(!problems.some((p) => p.nodeId === "tr" && p.category === "config_incomplete"))
    }

    function test_actionWithNoTypeSelectedIsAnError() {
        const nodes = [node("t1", "trigger_root"), node("a", "action")]
        const problems = PipelineValidation.computeProblems(nodes, [edge("e1", "t1", "a")], [])
        verify(problems.some((p) => p.nodeId === "a" && p.category === "config_incomplete"))
    }

    function test_nodeWithNoEdgesAtAllIsDisconnected() {
        const nodes = [node("t1", "trigger_root"), node("a", "action")]
        const problems = PipelineValidation.computeProblems(nodes, [], [])
        verify(problems.some((p) => p.nodeId === "a" && p.category === "disconnected" && p.severity === "warning"))
    }

    function test_chainNotTracingBackToTriggerIsDisconnected() {
        const nodes = [node("t1", "trigger_root"), node("a", "action"), node("b", "action")]
        const problems = PipelineValidation.computeProblems(nodes, [edge("e1", "a", "b")], [])
        verify(problems.some((p) => p.nodeId === "a" && p.category === "disconnected"))
        verify(problems.some((p) => p.nodeId === "b" && p.category === "disconnected"))
    }

    function test_nodeReachableFromTriggerIsNotDisconnected() {
        const nodes = [node("t1", "trigger_root"), node("a", "action")]
        const problems = PipelineValidation.computeProblems(nodes, [edge("e1", "t1", "a")], [])
        verify(!problems.some((p) => p.nodeId === "a" && p.category === "disconnected"))
    }

    function test_disconnectedCheckSkippedWithoutExactlyOneTrigger() {
        const problems = PipelineValidation.computeProblems([node("a", "action")], [], [])
        verify(!problems.some((p) => p.category === "disconnected"))
    }

    function test_deletedCameraOnDeviceControlNodeIsAnError() {
        const nodes = [node("t1", "trigger_root"), node("dc", "device_control")]
        nodes[1].config = { action_type: "start_recording", camera_id: "gone-camera" }
        const problems = PipelineValidation.computeProblems(nodes, [edge("e1", "t1", "dc")], ["cam-1", "cam-2"])
        verify(problems.some((p) => p.nodeId === "dc" && p.category === "dangling_camera"))
    }

    function test_existingCameraOnDeviceControlNodeIsFine() {
        const nodes = [node("t1", "trigger_root"), node("dc", "device_control")]
        nodes[1].config = { action_type: "start_recording", camera_id: "cam-1" }
        const problems = PipelineValidation.computeProblems(nodes, [edge("e1", "t1", "dc")], ["cam-1", "cam-2"])
        verify(!problems.some((p) => p.nodeId === "dc" && p.category === "dangling_camera"))
    }

    function test_noCameraIdSetIsNotADanglingReference() {
        const nodes = [node("t1", "trigger_root"), node("a", "action")]
        nodes[1].config = { action_type: "extract_clip" }
        const problems = PipelineValidation.computeProblems(nodes, [edge("e1", "t1", "a")], ["cam-1"])
        verify(!problems.some((p) => p.category === "dangling_camera"))
    }

    function test_actionTypeWithoutCameraIdFieldIsNeverChecked() {
        const nodes = [node("t1", "trigger_root"), node("a", "action")]
        nodes[1].config = { action_type: "delay", camera_id: "gone-camera" }
        const problems = PipelineValidation.computeProblems(nodes, [edge("e1", "t1", "a")], ["cam-1"])
        verify(!problems.some((p) => p.category === "dangling_camera"))
    }

    function test_transcodeWithNoUpstreamArtifactSourceIsAnError() {
        const nodes = [node("t1", "trigger_root"), node("tc", "action")]
        nodes[1].config = { action_type: "transcode" }
        const problems = PipelineValidation.computeProblems(nodes, [edge("e1", "t1", "tc")], [])
        verify(problems.some((p) => p.nodeId === "tc" && p.category === "missing_artifact_source"
                                     && p.severity === "error"))
    }

    function test_transcodeDownstreamOfExtractClipIsFine() {
        const nodes = [node("t1", "trigger_root"), node("ec", "action"), node("tc", "action")]
        nodes[1].config = { action_type: "extract_clip" }
        nodes[2].config = { action_type: "transcode" }
        const edges = [edge("e1", "t1", "ec"), edge("e2", "ec", "tc")]
        const problems = PipelineValidation.computeProblems(nodes, edges, [])
        verify(!problems.some((p) => p.category === "missing_artifact_source"))
    }

    function test_transcodeDownstreamOfExtractClipThroughAnotherPassThroughIsFine() {
        const nodes = [node("t1", "trigger_root"), node("ec", "action"), node("cz", "action"), node("tc", "action")]
        nodes[1].config = { action_type: "extract_clip" }
        nodes[2].config = { action_type: "compress" }
        nodes[3].config = { action_type: "transcode" }
        const edges = [edge("e1", "t1", "ec"), edge("e2", "ec", "cz"), edge("e3", "cz", "tc")]
        const problems = PipelineValidation.computeProblems(nodes, edges, [])
        verify(!problems.some((p) => p.category === "missing_artifact_source"))
    }

    function test_mergeClipsWithNoUpstreamArtifactSourceIsAnError() {
        const nodes = [node("t1", "trigger_root"), node("mc", "action")]
        nodes[1].config = { action_type: "merge_clips" }
        const problems = PipelineValidation.computeProblems(nodes, [edge("e1", "t1", "mc")], [])
        verify(problems.some((p) => p.nodeId === "mc" && p.category === "missing_artifact_source"
                                     && p.severity === "error"))
    }

    function test_mergeClipsWithOnlyOneProducingBranchIsAWarning() {
        const nodes = [node("t1", "trigger_root"), node("fk", "fork"), node("ec", "action"),
                       node("dl", "action"), node("mc", "action")]
        nodes[2].config = { action_type: "extract_clip" }
        nodes[3].config = { action_type: "delay" }
        nodes[4].config = { action_type: "merge_clips" }
        const edges = [edge("e1", "t1", "fk"), edge("e2", "fk", "ec"), edge("e3", "fk", "dl"),
                       edge("e4", "ec", "mc"), edge("e5", "dl", "mc")]
        const problems = PipelineValidation.computeProblems(nodes, edges, [])
        verify(problems.some((p) => p.nodeId === "mc" && p.category === "missing_artifact_source"
                                     && p.severity === "warning"))
    }

    function test_mergeClipsWithTwoProducingBranchesIsFine() {
        const nodes = [node("t1", "trigger_root"), node("fk", "fork"), node("ec1", "action"),
                       node("ec2", "action"), node("mc", "action")]
        nodes[2].config = { action_type: "extract_clip" }
        nodes[3].config = { action_type: "extract_clip" }
        nodes[4].config = { action_type: "merge_clips" }
        const edges = [edge("e1", "t1", "fk"), edge("e2", "fk", "ec1"), edge("e3", "fk", "ec2"),
                       edge("e4", "ec1", "mc"), edge("e5", "ec2", "mc")]
        const problems = PipelineValidation.computeProblems(nodes, edges, [])
        verify(!problems.some((p) => p.category === "missing_artifact_source"))
    }
}
