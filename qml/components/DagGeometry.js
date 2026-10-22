.pragma library

// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

// Node size and port positions shared by DagNode, DagEdge and DagCanvas, so
// edges always meet the ports DagNode actually draws. All Y values are
// relative to the node's top edge.

var nodeWidth = 160
var minNodeHeight = 56
// Smallest centre-to-centre distance between adjacent output ports
// (Theme.spaceL). Ports are 10px, so this leaves a 6px gap between them.
var minPortPitch = 16

// Tall enough to fit outputPortCount ports at minPortPitch, and never
// shorter than minNodeHeight. The top edge stays put; the node grows down.
function nodeHeight(outputPortCount) {
    return Math.max(minNodeHeight, minPortPitch * (outputPortCount + 1))
}

function outputPortY(index, outputPortCount) {
    return nodeHeight(outputPortCount) * (index + 1) / (outputPortCount + 1)
}

function inputPortY(outputPortCount) {
    return nodeHeight(outputPortCount) / 2
}
