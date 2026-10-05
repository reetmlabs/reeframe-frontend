// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes
import "../PipelineValidation.js" as PipelineValidation

Item {
    id: root
    // Nodes pan well past the canvas's own bounds during a drag; without
    // this they'd render over whatever sits next to the canvas instead of
    // disappearing at its edge.
    clip: true

    property real zoom: 1.0
    property real panX: 0.0
    property real panY: 0.0
    property string selectedId: ""

    // Re-evaluated live as nodes/edges/config change, so a node's problem
    // badge updates as you type. See PipelineValidation.js for the rules.
    // Depends on CameraModel.count purely to establish a binding:
    // refresh()/insertTestCamera()/clearTestCameras() only bump count, not a
    // dedicated signal (same trick as NodeConfigPanel's FormCameraCombo).
    readonly property var problems: {
        const _trackCameraCount = CameraModel.count
        return PipelineValidation.computeProblems(
            PipelineGraphModel.nodes, PipelineGraphModel.edges,
            CameraModel.searchableEntries().map((c) => c.id))
    }

    function problemsForNode(nodeId) {
        return root.problems.filter((p) => p.nodeId === nodeId)
    }

    // Drops focus (committing any pending edit via its blur handler) before
    // changing selection. Otherwise the outgoing node's config panel resets
    // its fields to the newly selected node's data first, discarding the edit.
    function selectId(id) {
        root.forceActiveFocus()
        root.selectedId = id
        root.highlightedIds = []
    }

    // Nodes flagged for a transient visual highlight, e.g. every node in a
    // cycle a problems list entry points at, where there's no single node to
    // select. Cleared by selectId() the next time the user picks anything
    // themselves, so it never lingers stale.
    property var highlightedIds: []

    function centerOn(worldX, worldY) {
        root.panX = root.width / 2 - worldX * root.zoom
        root.panY = root.height / 2 - worldY * root.zoom
    }

    // Selects and pans to a single node, e.g. from a problems list entry
    // pointing at exactly one node.
    function revealNode(nodeId) {
        const n = PipelineGraphModel.nodeById(nodeId)
        if (!n || n.id === undefined) return
        root.selectId(nodeId)
        root.centerOn(n.x + 80, n.y + 28)
    }

    // Highlights every node in the list at once with no single selection,
    // e.g. a cycle, where no one node is "the" problem. Pans to their
    // centroid rather than any single node's position.
    function revealNodes(nodeIds) {
        const nodes = nodeIds.map((id) => PipelineGraphModel.nodeById(id))
            .filter((n) => n && n.id !== undefined)
        if (nodes.length === 0) return
        root.selectId("")
        root.highlightedIds = nodeIds
        const cx = nodes.reduce((sum, n) => sum + n.x + 80, 0) / nodes.length
        const cy = nodes.reduce((sum, n) => sum + n.y + 28, 0) / nodes.length
        root.centerOn(cx, cy)
    }

    property bool drawingEdge: false
    property string edgeFromNodeId: ""
    property int edgeFromPortIndex: 0
    property point edgeCursorPos: Qt.point(0, 0)

    // Per-node {x, y} while being dragged (see DagNode.dragPositionChanged).
    // Lets edges follow the drag live without reassigning
    // PipelineGraphModel.nodes (which would reset the whole node Repeater).
    property var liveNodePos: ({})

    readonly property real minZoom: 0.25
    readonly property real maxZoom: 3.0
    // Pixels panned per full wheel notch (Qt reports one notch as 120 units
    // of angleDelta).
    readonly property real wheelPanStep: 60

    readonly property alias world: worldItem

    function resetView() {
        panX = 0
        panY = 0
        zoom = 1.0
    }

    // Zooms in place around the viewport centre. Used by the Ctrl+=/Ctrl+-
    // shortcuts below, which don't have a cursor position to pivot on the
    // way the wheel handler does.
    function zoomBy(factor) {
        const newZoom = Math.max(minZoom, Math.min(maxZoom, zoom * factor))
        const ratio = newZoom / zoom
        const cx = width / 2
        const cy = height / 2
        panX = cx - (cx - panX) * ratio
        panY = cy - (cy - panY) * ratio
        zoom = newZoom
    }

    function screenToWorld(sx, sy) {
        return Qt.point((sx - panX) / zoom, (sy - panY) / zoom)
    }

    function worldToScreen(wx, wy) {
        return Qt.point(wx * zoom + panX, wy * zoom + panY)
    }

    function viewportCentre() {
        return screenToWorld(width / 2, height / 2)
    }

    function edgeTypeFor(fromNodeId, portIndex) {
        const node = PipelineGraphModel.nodeById(fromNodeId)
        if (!node || node.id === undefined)
            return "normal"
        if (node.type === "condition")
            return portIndex === 0 ? "condition_true" : "condition_false"
        return "normal"
    }

    function outgoingEdgeCount(nodeId) {
        let n = 0
        for (const e of PipelineGraphModel.edges)
            if (e.fromNodeId === nodeId) n++
        return n
    }

    // Condition is always exactly true/false (2). Fork has no fixed arity:
    // it always shows one more empty port than it currently has edges wired
    // to, so dragging from that last port is how you grow it past 2 without
    // needing a separate "add port" control. Every other node type has 1.
    function outputPortCountFor(nodeId) {
        const node = PipelineGraphModel.nodeById(nodeId)
        if (!node || node.id === undefined)
            return 1
        if (node.type === "condition")
            return 2
        if (node.type === "fork")
            return Math.max(2, outgoingEdgeCount(nodeId) + 1)
        return 1
    }

    // A Condition's port is fixed by its edge type (true=0/false=1). A Fork's
    // edges carry no port of their own, so its port is just the edge's rank
    // among that fork's other outgoing edges, in list order.
    function portIndexForEdge(edge) {
        const node = PipelineGraphModel.nodeById(edge.fromNodeId)
        if (!node || node.id === undefined)
            return 0
        if (node.type === "condition")
            return edge.edgeType === "condition_false" ? 1 : 0
        if (node.type === "fork") {
            let rank = 0
            for (const e of PipelineGraphModel.edges) {
                if (e.id === edge.id) break
                if (e.fromNodeId === edge.fromNodeId) rank++
            }
            return rank
        }
        return 0
    }

    /* ----- Dot grid background (screen space, tracks pan + zoom) ----- */
    Canvas {
        id: gridCanvas
        anchors.fill: parent

        Connections {
            target: root
            function onPanXChanged() { gridCanvas.requestPaint() }
            function onPanYChanged() { gridCanvas.requestPaint() }
            function onZoomChanged() { gridCanvas.requestPaint() }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const spacing = 24 * root.zoom
            const offsetX = ((root.panX % spacing) + spacing) % spacing
            const offsetY = ((root.panY % spacing) + spacing) % spacing
            ctx.fillStyle = "#2e2e38"
            for (let x = offsetX; x < width; x += spacing) {
                for (let y = offsetY; y < height; y += spacing) {
                    ctx.beginPath()
                    ctx.arc(x, y, 1.5, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }

    /* ----- World space: pan + zoom transform applied here ----- */
    Item {
        id: worldItem
        x: root.panX
        y: root.panY
        scale: root.zoom
        transformOrigin: Item.TopLeft

        /* Edges, rendered below nodes */
        Repeater {
            model: PipelineGraphModel.edges

            delegate: DagEdge {
                required property var modelData

                edgeData: modelData
                isSelected: root.selectedId === modelData.id
                liveNodePos: root.liveNodePos
                fromPortIndex: root.portIndexForEdge(modelData)
                outputPortCount: root.outputPortCountFor(modelData.fromNodeId)
                onSelectRequested: root.selectId(edgeData.id)
            }
        }

        Shape {
            id: ghostEdge

            readonly property var fromNode: root.drawingEdge
                ? PipelineGraphModel.nodeById(root.edgeFromNodeId)
                : ({})
            readonly property bool gValid: fromNode && fromNode.id !== undefined
            readonly property int gPortCount: gValid ? root.outputPortCountFor(fromNode.id) : 1

            readonly property var gFromPos: (gValid && root.liveNodePos[fromNode.id])
                ? root.liveNodePos[fromNode.id] : fromNode

            readonly property real gStartX: gValid ? gFromPos.x + 160 : 0
            readonly property real gStartY: gValid
                ? gFromPos.y + 56 * (root.edgeFromPortIndex + 1) / (gPortCount + 1)
                : 0
            readonly property real gEndX: root.edgeCursorPos.x
            readonly property real gEndY: root.edgeCursorPos.y
            readonly property real cpOffset: Math.max(60, Math.min(Math.abs(gEndX - gStartX) * 0.6, 120))
            readonly property real pad: 130

            visible: root.drawingEdge && gValid
            antialiasing: true

            x: Math.min(gStartX, gEndX) - pad
            y: Math.min(gStartY, gEndY) - pad
            width: Math.abs(gEndX - gStartX) + 2 * pad
            height: Math.abs(gEndY - gStartY) + 2 * pad

            readonly property real lSX: gStartX - x
            readonly property real lSY: gStartY - y
            readonly property real lEX: gEndX - x
            readonly property real lEY: gEndY - y

            ShapePath {
                strokeColor: Theme.accent
                strokeWidth: 2
                fillColor: "transparent"
                strokeStyle: ShapePath.DashLine
                dashPattern: [6, 4]
                capStyle: ShapePath.RoundCap

                startX: ghostEdge.lSX
                startY: ghostEdge.lSY

                PathCubic {
                    x: ghostEdge.lEX
                    y: ghostEdge.lEY
                    control1X: ghostEdge.lSX + ghostEdge.cpOffset
                    control1Y: ghostEdge.lSY
                    control2X: ghostEdge.lEX - ghostEdge.cpOffset
                    control2Y: ghostEdge.lEY
                }
            }
        }

        /* Nodes, rendered above edges */
        Repeater {
            model: PipelineGraphModel.nodes

            delegate: DagNode {
                required property var modelData

                nodeData: modelData
                isSelected: root.selectedId === modelData.id || root.highlightedIds.includes(modelData.id)
                outputPortCount: root.outputPortCountFor(modelData.id)
                problems: root.problemsForNode(modelData.id)

                onSelectRequested: {
                    if (root.drawingEdge) {
                        root.drawingEdge = false
                        root.edgeFromNodeId = ""
                    }
                    root.selectId(nodeData.id)
                }

                onOutputPortClicked: (portIndex) => {
                    root.selectId("")
                    root.edgeFromNodeId = nodeData.id
                    root.edgeFromPortIndex = portIndex
                    root.edgeCursorPos = Qt.point(nodeData.x + 160, nodeData.y + 28)
                    root.drawingEdge = true
                }

                onInputPortClicked: {
                    if (!root.drawingEdge)
                        return
                    if (root.edgeFromNodeId === nodeData.id)
                        return
                    const etype = root.edgeTypeFor(root.edgeFromNodeId, root.edgeFromPortIndex)
                    PipelineGraphModel.addEdge(root.edgeFromNodeId, nodeData.id, etype)
                    root.drawingEdge = false
                    root.edgeFromNodeId = ""
                }

                onDragPositionChanged: (nodeId, x, y) => {
                    const m = Object.assign({}, root.liveNodePos)
                    m[nodeId] = { x: x, y: y }
                    root.liveNodePos = m
                }

                onDragEnded: (nodeId) => {
                    const m = Object.assign({}, root.liveNodePos)
                    delete m[nodeId]
                    root.liveNodePos = m
                }
            }
        }
    }

    MouseArea {
        id: panArea
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        property real pressX: 0
        property real pressY: 0
        property real pressPanX: 0
        property real pressPanY: 0

        onPressed: (mouse) => {
            // Reclaims keyboard focus from any config-panel text field the
            // user was last editing. Otherwise Delete/Backspace keep going
            // to that field (which swallows them) instead of PipelineEditorView.
            root.forceActiveFocus()
            pressX = mouse.x
            pressY = mouse.y
            pressPanX = root.panX
            pressPanY = root.panY
            if (!root.drawingEdge)
                cursorShape = Qt.ClosedHandCursor
        }
        onReleased: cursorShape = Qt.ArrowCursor
        onPositionChanged: (mouse) => {
            if (root.drawingEdge)
                root.edgeCursorPos = root.screenToWorld(mouse.x, mouse.y)
            if (pressed && !root.drawingEdge) {
                root.panX = pressPanX + (mouse.x - pressX)
                root.panY = pressPanY + (mouse.y - pressY)
            }
        }
        onClicked: {
            if (root.drawingEdge) {
                root.drawingEdge = false
                root.edgeFromNodeId = ""
            } else {
                root.selectId("")
            }
        }
    }

    /* ----- Cursor tracking for ghost edge while hovering over nodes ----- */
    HoverHandler {
        onPointChanged: {
            if (root.drawingEdge)
                root.edgeCursorPos = root.screenToWorld(point.position.x, point.position.y)
        }
    }

    /* ----- Wheel: Ctrl zooms (pivot on cursor), plain wheel pans ----- */
    WheelHandler {
        target: null
        // Without this, the handler ignores any wheel event sent while a
        // keyboard modifier is held, so Ctrl+wheel and Shift+wheel below
        // never even reach onWheel.
        acceptedModifiers: Qt.KeyboardModifierMask
        onWheel: (event) => {
            if (event.modifiers & Qt.ControlModifier) {
                const factor = event.angleDelta.y > 0 ? 1.1 : (1.0 / 1.1)
                const newZoom = Math.max(root.minZoom, Math.min(root.maxZoom, root.zoom * factor))
                const ratio = newZoom / root.zoom
                root.panX = event.x - (event.x - root.panX) * ratio
                root.panY = event.y - (event.y - root.panY) * ratio
                root.zoom = newZoom
                return
            }
            // A real horizontal scroll gesture (trackpad swipe, tilt wheel)
            // already reports its own angleDelta.x. Shift plus a plain
            // vertical wheel is the conventional way a normal mouse wheel
            // asks for horizontal scrolling instead, so treat that the same.
            const shiftHorizontal = (event.modifiers & Qt.ShiftModifier) && event.angleDelta.x === 0
            const dx = shiftHorizontal ? event.angleDelta.y : event.angleDelta.x
            const dy = shiftHorizontal ? 0 : event.angleDelta.y
            root.panX += dx / 120 * root.wheelPanStep
            root.panY += dy / 120 * root.wheelPanStep
        }
    }

    // Keyboard fallback for zoom. Some Wayland setups don't deliver
    // keyboard-modifier state to wheel events reliably, so Ctrl+wheel above
    // can't always be trusted as the only way to zoom.
    Shortcut {
        sequences: ["Ctrl+=", "Ctrl++"]
        context: Qt.WindowShortcut
        onActivated: root.zoomBy(1.1)
    }
    Shortcut {
        sequence: "Ctrl+-"
        context: Qt.WindowShortcut
        onActivated: root.zoomBy(1.0 / 1.1)
    }

    /* ----- Zoom controls ----- */
    Row {
        id: zoomControls
        spacing: Theme.spaceXs
        anchors { right: parent.right; bottom: parent.bottom; margins: Theme.spaceM }

        component ZoomButton: Rectangle {
            id: zoomBtn
            property alias iconSource: zoomBtnIcon.source

            signal clicked()

            width: 28; height: 28
            radius: Theme.radiusS
            color: zoomBtnMouse.containsMouse ? Theme.surfaceHover : Theme.surfaceCard
            border.color: Theme.border

            TblIcon {
                id: zoomBtnIcon
                size: 14
                color: Theme.textSecondary
                anchors.centerIn: parent
            }

            MouseArea {
                id: zoomBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: zoomBtn.clicked()
            }

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        ZoomButton {
            objectName: "dagCanvasZoomOutButton"
            iconSource: "qrc:/tb/minus.svg"
            onClicked: root.zoomBy(1.0 / 1.1)
        }
        ZoomButton {
            objectName: "dagCanvasZoomResetButton"
            iconSource: "qrc:/tb/zoom-reset.svg"
            onClicked: root.resetView()
        }
        ZoomButton {
            objectName: "dagCanvasZoomInButton"
            iconSource: "qrc:/tb/plus.svg"
            onClicked: root.zoomBy(1.1)
        }
    }

    Text {
        visible: PipelineGraphModel.loading
        anchors.centerIn: parent
        text: qsTr("Loading…")
        font.pixelSize: Theme.fontS
        color: Theme.textDisabled
    }

    EmptyState {
        visible: !PipelineGraphModel.loading && PipelineGraphModel.nodes.length === 0
        anchors.centerIn: parent
        icon: "qrc:/tb/git-merge.svg"
        title: qsTr("No nodes yet")
        message: qsTr("Add a node from the palette to start building your pipeline.")
    }
}
