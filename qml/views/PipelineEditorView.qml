// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic
import "../components"

Item {
    id: root

    required property string pipelineId
    required property string pipelineName
    property bool pipelineEnabled: false

    focus: true

    component PaletteEntry: Rectangle {
        id: entry

        required property string nodeType
        required property string entryLabel
        required property color entryColor

        width: parent.width
        height: 40
        color: entryMouse.containsMouse ? Theme.surfaceHover : "transparent"

        Rectangle {
            width: 3; height: parent.height
            color: entry.entryColor
        }

        Text {
            anchors { left: parent.left; leftMargin: 11; verticalCenter: parent.verticalCenter }
            text: entry.entryLabel
            font.pixelSize: Theme.fontXs
            color: Theme.textPrimary
        }

        MouseArea {
            id: entryMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const c = canvas.viewportCentre()
                const id = PipelineGraphModel.addNode(entry.nodeType, c.x - 80, c.y - 28)
                canvas.selectedId = id
            }
        }

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    function handleDeleteKey() {
        const id = canvas.selectedId
        if (id === "") return
        // Node/edge ids only carry a "node-"/"edge-" prefix before their first
        // save (see PipelineGraphModel::addNode/addEdge). Once persisted the
        // id is server-assigned, so branch on actual membership instead.
        if (PipelineGraphModel.nodeById(id).id !== undefined)
            PipelineGraphModel.removeNode(id)
        else
            PipelineGraphModel.removeEdge(id)
        canvas.selectedId = ""
    }

    Keys.onDeletePressed: handleDeleteKey()
    // No Keys.onBackspacePressed signal exists on the Keys attached type
    // (unlike onDeletePressed), so Backspace has to be caught via onPressed.
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Backspace) {
            handleDeleteKey()
            event.accepted = true
        }
    }
    Keys.onEscapePressed: {
        if (canvas.drawingEdge) {
            canvas.drawingEdge = false
            canvas.edgeFromNodeId = ""
        } else {
            canvas.selectedId = ""
        }
    }

    readonly property var selectedNode: {
        const _ = PipelineGraphModel.nodes
        if (canvas.selectedId === "") return ({})
        return PipelineGraphModel.nodeById(canvas.selectedId)
    }

    readonly property bool showConfigPanel: {
        const t = root.selectedNode.type
        return t === "action" || t === "device_control" || t === "transport"
            || t === "trigger_root" || t === "condition"
    }

    readonly property bool isTransportNode: root.selectedNode.type === "transport"
    readonly property bool isTriggerNode: root.selectedNode.type === "trigger_root"
    readonly property bool isConditionNode: root.selectedNode.type === "condition"

    Component.onCompleted: PipelineGraphModel.load(root.pipelineId)

    Connections {
        target: PipelineGraphModel
        function onSaveSucceeded() { toast.show(qsTr("Saved")) }
        function onSaveFailed(error) { toast.show(qsTr("Save failed: %1").arg(error)) }
        function onLoadFailed(error) { toast.show(qsTr("Load failed: %1").arg(error)) }
    }

    function tryBack() {
        if (PipelineGraphModel.dirty)
            discardDialog.open()
        else
            root.StackView.view.pop()
    }

    /* ----- Toolbar ----- */
    Rectangle {
        id: toolbar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 44
        color: Theme.surface

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Theme.border
        }

        Rectangle {
            id: backBtn
            width: 72; height: 30; radius: Theme.radiusS
            color: backMouse.containsMouse ? Theme.surfaceHover : "transparent"
            anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }

            Text { anchors.centerIn: parent; text: qsTr("← Back"); font.pixelSize: Theme.fontS; color: Theme.textSecondary }

            MouseArea {
                id: backMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.tryBack()
            }

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        Text {
            text: root.pipelineName
            font.pixelSize: Theme.fontM; font.weight: Font.Medium; color: Theme.textPrimary
            elide: Text.ElideRight
            anchors {
                left: backBtn.right; leftMargin: Theme.spaceL
                right: toolbarRight.left; rightMargin: Theme.spaceL
                verticalCenter: parent.verticalCenter
            }
        }

        Row {
            id: toolbarRight
            spacing: Theme.spaceS
            anchors { right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }

            PipelineEnableToggle {
                id: enableToggle
                pipelineId: root.pipelineId
                pipelineEnabled: root.pipelineEnabled
                errorCount: problemsPanel.errorCount
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                visible: PipelineGraphModel.dirty
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: Theme.warning
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: qsTr("Unsaved")
                    font.pixelSize: Theme.fontXs
                    color: Theme.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: 70; height: 30; radius: Theme.radiusS
                color: saveMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent
                opacity: PipelineGraphModel.loading ? 0.5 : 1.0

                Text {
                    anchors.centerIn: parent
                    text: PipelineGraphModel.loading ? "…" : qsTr("Save")
                    font.pixelSize: Theme.fontS; font.weight: Font.Medium
                    color: Theme.textOnAccent
                }

                MouseArea {
                    id: saveMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    enabled: !PipelineGraphModel.loading
                    onClicked: PipelineGraphModel.save()
                }

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }
        }
    }

    /* ----- Node palette panel ----- */
    Rectangle {
        id: palette
        anchors { left: parent.left; top: toolbar.bottom; bottom: parent.bottom }
        width: 104
        color: Theme.surface

        Rectangle {
            anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
            width: 1
            color: Theme.border
        }

        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top }

            /* Section header */
            Rectangle {
                width: parent.width; height: 32
                color: "transparent"

                Text {
                    anchors { left: parent.left; leftMargin: 11; verticalCenter: parent.verticalCenter }
                    text: qsTr("NODES")
                    font.pixelSize: Theme.fontXs
                    font.weight: Font.Medium
                    font.letterSpacing: 0.8
                    color: Theme.textDisabled
                }
            }

            PaletteEntry { nodeType: "trigger_root";   entryLabel: qsTr("Trigger");     entryColor: Theme.accent }
            PaletteEntry { nodeType: "action";         entryLabel: qsTr("Action");      entryColor: "#4a9eed" }
            PaletteEntry { nodeType: "device_control"; entryLabel: qsTr("Device ctrl"); entryColor: "#9c6fe4" }
            PaletteEntry { nodeType: "transport";      entryLabel: qsTr("Transport");   entryColor: Theme.success }
            PaletteEntry { nodeType: "condition";      entryLabel: qsTr("Condition");   entryColor: Theme.warning }
            PaletteEntry { nodeType: "fork";           entryLabel: qsTr("Fork");        entryColor: "#e46f9c" }
        }
    }

    /* ----- Node config panel (action / device_control nodes) ----- */
    Rectangle {
        id: configPanel
        anchors { right: parent.right; top: toolbar.bottom; bottom: parent.bottom }
        width: root.showConfigPanel ? 280 : 0
        color: Theme.surface
        clip: true
        visible: width > 0

        Behavior on width { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.InOutQuad } }

        NodeConfigPanel {
            anchors.fill: parent
            nodeData: root.selectedNode
            visible: !root.isTransportNode && !root.isTriggerNode && !root.isConditionNode
        }

        TransportConfigPanel {
            anchors.fill: parent
            nodeData: root.selectedNode
            visible: root.isTransportNode
        }

        TriggerConfigPanel {
            anchors.fill: parent
            nodeData: root.selectedNode
            visible: root.isTriggerNode
        }

        ConditionConfigPanel {
            anchors.fill: parent
            nodeData: root.selectedNode
            visible: root.isConditionNode
        }
    }

    /* ----- Canvas ----- */
    DagCanvas {
        id: canvas
        anchors { left: palette.right; right: configPanel.left; top: toolbar.bottom; bottom: problemsPanel.top }
    }

    ProblemsPanel {
        id: problemsPanel
        anchors { left: palette.right; right: configPanel.left; bottom: parent.bottom }
        problems: canvas.problems
        onEntryActivated: (problem) => {
            if (problem.nodeIds && problem.nodeIds.length > 0)
                canvas.revealNodes(problem.nodeIds)
            else if (problem.nodeId)
                canvas.revealNode(problem.nodeId)
        }
    }

    Toast { id: toast }

    ConfirmDialog {
        id: discardDialog
        title: qsTr("Discard changes?")
        message: qsTr("You have unsaved changes. Go back and discard them?")
        confirmLabel: qsTr("Discard")
        onConfirmed: root.StackView.view.pop()
    }
}
