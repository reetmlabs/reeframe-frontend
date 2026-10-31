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

// Edges are cubic beziers from an output port (start) to an input port (end),
// with both control points pulled out horizontally by this much. The floor
// keeps near-vertically stacked nodes (small dx) from collapsing the curve
// into a straight, kinked-looking line.
function edgeControlOffset(startX, endX) {
    return Math.max(60, Math.min(Math.abs(endX - startX) * 0.6, 120))
}

// Shortest distance from (px, py) to the edge drawn from (sx, sy) to
// (ex, ey), measured against the curve split into straight segments.
function distanceToEdge(px, py, sx, sy, ex, ey) {
    const segments = 24
    const offset = edgeControlOffset(sx, ex)
    const c1x = sx + offset, c1y = sy
    const c2x = ex - offset, c2y = ey
    let best = Infinity
    let prevX = sx, prevY = sy
    for (let i = 1; i <= segments; i++) {
        const t = i / segments
        const u = 1 - t
        const x = u * u * u * sx + 3 * u * u * t * c1x + 3 * u * t * t * c2x + t * t * t * ex
        const y = u * u * u * sy + 3 * u * u * t * c1y + 3 * u * t * t * c2y + t * t * t * ey
        best = Math.min(best, distanceToSegment(px, py, prevX, prevY, x, y))
        prevX = x
        prevY = y
    }
    return best
}

function distanceToSegment(px, py, ax, ay, bx, by) {
    const dx = bx - ax, dy = by - ay
    const lengthSq = dx * dx + dy * dy
    const t = lengthSq === 0 ? 0
        : Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / lengthSq))
    const cx = ax + t * dx, cy = ay + t * dy
    return Math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy))
}
