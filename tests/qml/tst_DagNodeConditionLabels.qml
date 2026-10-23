// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// A Condition's two output ports are labelled True and False so its branches
// aren't told apart by edge colour alone. The labels sit outside the card,
// above the true port and below the false port, clear of the edges leaving
// each port. No other node type shows port labels.
TestCase {
    id: testCase
    name: "DagNodeConditionLabels"
    width: 600
    height: 400
    visible: true
    when: windowShown

    DagNode {
        id: conditionNode
        x: 50; y: 50
        nodeData: ({ id: "labelCondition", type: "condition", x: 50, y: 50 })
        outputPortCount: 2
    }

    DagNode {
        id: forkNode
        x: 50; y: 200
        nodeData: ({ id: "labelFork", type: "fork", x: 50, y: 200 })
        outputPortCount: 3
    }

    DagNode {
        id: actionNode
        x: 300; y: 50
        nodeData: ({ id: "labelAction", type: "action", x: 300, y: 50 })
    }

    function labelFor(node, index) {
        const label = findChild(node, "dagNodePortLabel_" + node.nodeData.id + "_" + index)
        verify(label !== null, "port label " + index + " not found")
        return label
    }

    function portFor(node, index) {
        const port = findChild(node, "dagNodeOutputPort_" + node.nodeData.id + "_" + index)
        verify(port !== null, "output port " + index + " not found")
        return port
    }

    function test_conditionPortsAreLabelledTrueAndFalse() {
        const trueLabel = labelFor(conditionNode, 0)
        const falseLabel = labelFor(conditionNode, 1)
        verify(trueLabel.visible && falseLabel.visible)
        compare(trueLabel.text, "True")
        compare(falseLabel.text, "False")
    }

    function test_labelsStayClearOfTheirEdges() {
        const truePort = portFor(conditionNode, 0)
        const falsePort = portFor(conditionNode, 1)
        const trueLabel = labelFor(conditionNode, 0)
        const falseLabel = labelFor(conditionNode, 1)

        const trueBox = trueLabel.mapToItem(conditionNode, 0, 0, trueLabel.width, trueLabel.height)
        const falseBox = falseLabel.mapToItem(conditionNode, 0, 0, falseLabel.width, falseLabel.height)

        verify(trueBox.x >= conditionNode.width && falseBox.x >= conditionNode.width,
               "labels must sit outside the card")
        verify(trueBox.y + trueBox.height <= truePort.y + 0.01,
               "the True label must sit above its port, clear of the edge")
        verify(falseBox.y >= falsePort.y + falsePort.height - 0.01,
               "the False label must sit below its port, clear of the edge")
    }

    function test_otherNodeTypesShowNoPortLabels() {
        for (let i = 0; i < 3; i++)
            verify(!labelFor(forkNode, i).visible, "a Fork port must not be labelled")
        verify(!labelFor(actionNode, 0).visible, "an Action port must not be labelled")
    }
}
