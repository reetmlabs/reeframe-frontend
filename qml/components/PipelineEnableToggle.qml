// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

// "Enabled" toggle for the pipeline currently open in the editor, separate
// from the pipeline list row's own toggle (same PipelineModel.setEnabled()
// underneath, just a second place to flip it without leaving the editor).
Row {
    id: root
    objectName: "pipelineEnableToggle"

    property string pipelineId: ""
    property bool pipelineEnabled: false
    property int errorCount: 0

    // Local mirror of pipelineEnabled so the switch flips immediately and
    // rolls back on failure. PipelineModel.setEnabled() only ever signals
    // back on failure (see onEnableRollback below), so there's deliberately
    // no "in flight" disabled state here to get stuck on success.
    property bool localEnabled: root.pipelineEnabled

    // Only turning a pipeline on is blocked by its errors; turning
    // an already-enabled one off stays available regardless.
    readonly property bool blocked: !root.localEnabled && root.errorCount > 0

    spacing: Theme.spaceXs

    Connections {
        target: PipelineModel
        function onEnableRollback(id, previousValue, message) {
            if (id !== root.pipelineId) return
            root.localEnabled = previousValue
            toast.show(message)
        }
    }

    Text {
        text: qsTr("Enabled")
        font.pixelSize: Theme.fontXs; color: Theme.textSecondary
        anchors.verticalCenter: parent.verticalCenter
    }

    ToggleSwitch {
        id: toggle
        objectName: "pipelineEnableToggleSwitch"
        checked: root.localEnabled
        enabled: !root.blocked
        anchors.verticalCenter: parent.verticalCenter
        onToggled: (val) => {
            root.localEnabled = val
            PipelineModel.setEnabled(root.pipelineId, val)
        }

        HoverHandler { id: toggleHover }

        ToolTip {
            visible: root.blocked && toggleHover.hovered
            text: qsTr("Fix %1 pipeline error(s) before enabling — see the Problems panel.").arg(root.errorCount)
            delay: 300
        }
    }

    Toast { id: toast; z: 10 }
}
