// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic
import "../components"
import "../dialogs"

Item {
    id: root

    property string expandedId: ""
    property string pendingDeleteId: ""
    property string pendingDeleteName: ""

    Component.onCompleted: PipelineModel.refresh()
    Component.onDestruction: RunModel.stopPolling()

    // Only one row's run history can be on screen at a time (RunModel polls
    // a single pipeline), so expanding a row here is what drives polling.
    onExpandedIdChanged: {
        if (expandedId !== "")
            RunModel.startPolling(expandedId)
        else
            RunModel.stopPolling()
    }

    function isPipelinePendingDelete(id) {
        const _ = PendingDeletes.version // force re-evaluation, see PendingDeletes.qml
        return PendingDeletes.isPending(id)
    }

    // Deferred through the app-wide PendingDeletes singleton rather than a
    // view-local queue; see SourceListView.qml for the rationale.
    function requestDeletePipeline(id, name) {
        if (root.expandedId === id)
            root.expandedId = ""
        PendingDeletes.schedule(id, 5000, function() {
            PipelineModel.deletePipeline(id)
        })
        PendingDeletes.notify(qsTr("Deleted \"%1\"").arg(name), [id], 5000)
    }

    function formatDuration(triggeredAt, completedAt) {
        if (completedAt <= 0 || triggeredAt <= 0) return "—"
        const secs = completedAt - triggeredAt
        if (secs < 60) return secs + "s"
        const mins = Math.floor(secs / 60)
        const rem  = secs % 60
        return rem > 0 ? mins + "m " + rem + "s" : mins + "m"
    }

    function formatTime(epochSecs) {
        if (epochSecs <= 0) return "—"
        return Qt.formatTime(new Date(epochSecs * 1000), "hh:mm:ss")
    }

    /* ----- Global command palette jump target ----- */
    function expandPipeline(id) {
        const idx = PipelineModel.pipelineIndexById(id)
        if (idx >= 0)
            list.positionViewAtIndex(idx, ListView.Contain)
        root.expandedId = id
    }

    /* ----- Header ----- */
    Rectangle {
        id: header
        height: 44
        color: "transparent"
        anchors { left: parent.left; right: parent.right; top: parent.top }

        Text {
            text: qsTr("Pipelines")
            font.pixelSize: Theme.fontM
            font.weight: Font.Medium
            color: Theme.textPrimary
            anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
        }

        Rectangle {
            width: 120; height: 30; radius: Theme.radiusS
            color: addMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent
            anchors { right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }

            Text {
                anchors.centerIn: parent
                text: qsTr("+ Add Pipeline")
                font.pixelSize: Theme.fontS
                font.weight: Font.Medium
                color: Theme.textOnAccent
            }

            MouseArea {
                id: addMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: addDialog.open()
            }

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        Rectangle {
            height: 1; color: Theme.border
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        }
    }

    /* ----- Search ----- */
    SearchBar {
        id: searchBar
        anchors {
            left: parent.left; right: parent.right; top: header.bottom
            leftMargin: Theme.spaceL; rightMargin: Theme.spaceL; topMargin: Theme.spaceM
        }
    }

    /* ----- Loading ----- */
    Text {
        visible: PipelineModel.loading
        anchors.centerIn: parent
        text: qsTr("Loading…")
        font.pixelSize: Theme.fontS
        color: Theme.textDisabled
    }

    /* ----- List ----- */
    ListView {
        id: list
        model: PipelineModel
        clip: true
        anchors {
            left: parent.left; right: parent.right
            top: searchBar.bottom; bottom: parent.bottom
            topMargin: Theme.spaceM
        }

        delegate: Column {
            id: rowItem
            objectName: "pipelineRow_" + pipelineId

            required property string pipelineId
            required property string pipelineName
            required property string pipelineDescription
            required property string pipelineType
            required property bool pipelineEnabled
            required property int pipelineCreatedAt
            required property int pipelineUpdatedAt
            required property int pipelineValidationErrorCount
            required property int pipelineValidationWarningCount

            property bool toggling: false
            property bool runHistoryExpanded: true
            readonly property bool expanded: root.expandedId === pipelineId

            width: list.width
            visible: !root.isPipelinePendingDelete(pipelineId) &&
                     (searchBar.text.length === 0 ||
                      pipelineName.toLowerCase().includes(searchBar.text.toLowerCase()))
            height: visible ? implicitHeight : 0

            // Reset toggling when the model rolls back the value.
            Connections {
                target: PipelineModel
                function onEnableRollback(id, previousValue, message) {
                    if (id === rowItem.pipelineId) {
                        rowItem.toggling = false
                        toast.show(message)
                    }
                }
                function onTriggered(pipelineId) {
                    if (pipelineId === rowItem.pipelineId)
                        toast.show(qsTr("Run queued"))
                }
            }

            /* ----- Summary row (always visible) ----- */
            Rectangle {
                id: summary
                width: parent.width
                height: 52
                color: rowMouse.containsMouse ? Theme.surfaceHover : (rowItem.expanded ? Theme.surfaceHover : "transparent")

                // Declared before rightZone's ToggleSwitch (not after) so the
                // switch stacks on top and receives its own clicks instead of
                // this full-row area swallowing them.
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expandedId = rowItem.expanded ? "" : rowItem.pipelineId
                }

                /* Type chip */
                TypeChip {
                    id: chip
                    type: rowItem.pipelineType
                    anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                }

                /* Toggle + created date (right zone) */
                Row {
                    id: rightZone
                    spacing: Theme.spaceL
                    anchors { right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }

                    Text {
                        text: Qt.formatDate(new Date(rowItem.pipelineCreatedAt * 1000), "d MMM yyyy")
                        font.pixelSize: Theme.fontXs
                        color: Theme.textDisabled
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    ToggleSwitch {
                        checked: rowItem.pipelineEnabled
                        enabled: !rowItem.toggling
                        anchors.verticalCenter: parent.verticalCenter
                        onToggled: (val) => {
                            rowItem.toggling = true
                            PipelineModel.setEnabled(rowItem.pipelineId, val)
                        }
                    }
                }

                /* Name + description */
                Column {
                    anchors {
                        left: chip.right; leftMargin: Theme.spaceM
                        right: rightZone.left; rightMargin: Theme.spaceM
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        text: rowItem.pipelineName
                        font.pixelSize: Theme.fontS
                        font.weight: Font.Medium
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Text {
                        visible: rowItem.pipelineDescription.length > 0
                        text: rowItem.pipelineDescription
                        font.pixelSize: Theme.fontXs
                        color: Theme.textDisabled
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    // Split by severity rather than a merged count: only errors
                    // block enabling, warnings don't.
                    Text {
                        objectName: "pipelineRowValidationSummary_" + rowItem.pipelineId
                        visible: rowItem.pipelineValidationErrorCount > 0 || rowItem.pipelineValidationWarningCount > 0
                        text: qsTr("%1 error(s) · %2 warning(s)")
                                .arg(rowItem.pipelineValidationErrorCount)
                                .arg(rowItem.pipelineValidationWarningCount)
                        font.pixelSize: Theme.fontXs
                        color: rowItem.pipelineValidationErrorCount > 0 ? Theme.error : Theme.warning
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            /* ----- Expanded detail panel ----- */
            Rectangle {
                objectName: "pipelineDetailPanel_" + rowItem.pipelineId
                // True once the height animation has finished opening the panel.
                readonly property bool fullyExpanded: rowItem.expanded && height === detailContent.implicitHeight
                width: parent.width
                height: rowItem.expanded ? detailContent.implicitHeight : 0
                clip: true
                color: Theme.surface
                border.color: rowItem.expanded ? Theme.border : "transparent"

                Behavior on height { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.InOutQuad } }

                Column {
                    id: detailContent
                    width: parent.width
                    topPadding: Theme.spaceM
                    bottomPadding: Theme.spaceM

                    /* Field rows */
                    Column {
                        width: parent.width
                        leftPadding: Theme.spaceXl
                        rightPadding: Theme.spaceXl

                        Repeater {
                            model: [
                                { label: qsTr("Type"),    special: "type" },
                                { label: qsTr("Enabled"), special: "enabled" },
                                { label: qsTr("Created"), special: "date", value: rowItem.pipelineCreatedAt },
                                { label: qsTr("Updated"), special: "date", value: rowItem.pipelineUpdatedAt }
                            ]

                            delegate: Item {
                                required property var modelData
                                width: parent.width - Theme.spaceXl * 2
                                height: 32

                                Text {
                                    text: modelData.label; font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                                    width: 90; anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                }

                                TypeChip {
                                    visible: modelData.special === "type"
                                    type: rowItem.pipelineType
                                    anchors { left: parent.left; leftMargin: 90; verticalCenter: parent.verticalCenter }
                                }

                                Row {
                                    visible: modelData.special === "enabled"
                                    spacing: Theme.spaceS
                                    anchors { left: parent.left; leftMargin: 90; verticalCenter: parent.verticalCenter }
                                    Rectangle { width: 8; height: 8; radius: 4; color: rowItem.pipelineEnabled ? Theme.success : Theme.textDisabled; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: rowItem.pipelineEnabled ? qsTr("Enabled") : qsTr("Disabled"); font.pixelSize: Theme.fontS; color: rowItem.pipelineEnabled ? Theme.success : Theme.textDisabled }
                                }

                                Text {
                                    visible: modelData.special === "date"
                                    text: modelData.value > 0 ? Qt.formatDate(new Date(modelData.value * 1000), "d MMM yyyy") : "—"
                                    font.pixelSize: Theme.fontS; color: Theme.textPrimary
                                    anchors { left: parent.left; leftMargin: 90; verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                    }

                    /* Action bar */
                    Row {
                        leftPadding: Theme.spaceXl
                        topPadding: Theme.spaceS
                        bottomPadding: Theme.spaceS
                        spacing: Theme.spaceS

                        Rectangle {
                            objectName: "pipelineEditGraphButton_" + rowItem.pipelineId
                            width: 90; height: 32; radius: Theme.radiusS
                            color: graphMouse.containsMouse ? Theme.surfaceHover : "transparent"; border.color: Theme.border
                            Text { anchors.centerIn: parent; text: qsTr("Edit graph"); font.pixelSize: Theme.fontS; color: Theme.textPrimary }
                            MouseArea {
                                id: graphMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.StackView.view.push(Qt.resolvedUrl("PipelineEditorView.qml"), {
                                    pipelineId:      rowItem.pipelineId,
                                    pipelineName:    rowItem.pipelineName,
                                    pipelineEnabled: rowItem.pipelineEnabled
                                })
                            }
                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        }

                        Rectangle {
                            width: 70; height: 32; radius: Theme.radiusS
                            color: editMouse.containsMouse ? Theme.surfaceHover : "transparent"; border.color: Theme.border
                            Text { anchors.centerIn: parent; text: qsTr("Edit"); font.pixelSize: Theme.fontS; color: Theme.textPrimary }
                            MouseArea {
                                id: editMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    editDialog.pipelineId          = rowItem.pipelineId
                                    editDialog.pipelineName        = rowItem.pipelineName
                                    editDialog.pipelineDescription = rowItem.pipelineDescription
                                    editDialog.pipelineType        = rowItem.pipelineType
                                    editDialog.open()
                                }
                            }
                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        }

                        Rectangle {
                            width: 70; height: 32; radius: Theme.radiusS
                            color: deleteMouse.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15) : "transparent"
                            border.color: deleteMouse.containsMouse ? Theme.error : Theme.border
                            Text { anchors.centerIn: parent; text: qsTr("Delete"); font.pixelSize: Theme.fontS; color: deleteMouse.containsMouse ? Theme.error : Theme.textPrimary }
                            MouseArea {
                                id: deleteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.pendingDeleteId = rowItem.pipelineId
                                    root.pendingDeleteName = rowItem.pipelineName
                                    confirmDialog.open()
                                }
                            }
                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                        }

                        Rectangle {
                            width: 90; height: 32; radius: Theme.radiusS
                            color: triggerMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent
                            Text { anchors.centerIn: parent; text: qsTr("Trigger →"); font.pixelSize: Theme.fontS; font.weight: Font.Medium; color: Theme.textOnAccent }
                            MouseArea {
                                id: triggerMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { triggerDialog.pipelineId = rowItem.pipelineId; triggerDialog.open() }
                            }
                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        }
                    }

                    /* Run history divider + header */
                    Rectangle { width: parent.width; height: 1; color: Theme.border }

                    Rectangle {
                        width: parent.width; height: 36; color: "transparent"

                        Row {
                            spacing: Theme.spaceS
                            anchors { left: parent.left; leftMargin: Theme.spaceXl; verticalCenter: parent.verticalCenter }

                            TblIcon {
                                source: rowItem.runHistoryExpanded ? "qrc:/tb/chevron-down.svg" : "qrc:/tb/chevron-right.svg"
                                color: Theme.textSecondary
                                size: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: qsTr("Run History")
                                font.pixelSize: Theme.fontS; font.weight: Font.Medium; color: Theme.textSecondary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            visible: RunModel.loading
                            text: qsTr("Loading…"); font.pixelSize: Theme.fontXs; color: Theme.textDisabled
                            anchors { right: parent.right; rightMargin: Theme.spaceXl; verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rowItem.runHistoryExpanded = !rowItem.runHistoryExpanded
                        }
                    }

                    /* Empty run history */
                    Rectangle {
                        visible: rowItem.expanded && rowItem.runHistoryExpanded && !RunModel.loading && RunModel.count === 0
                        width: parent.width; height: 40; color: "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("No runs yet")
                            font.pixelSize: Theme.fontS; color: Theme.textDisabled
                        }
                    }

                    /* Run rows. Only meaningful while this row is the expanded
                       one, since RunModel polls a single pipeline at a time. */
                    Repeater {
                        model: (rowItem.expanded && rowItem.runHistoryExpanded) ? RunModel : null

                        delegate: Rectangle {
                            id: runRow

                            required property string runId
                            required property string runStatus
                            required property string runTriggerType
                            required property int runTriggeredAt
                            required property int runCompletedAt
                            required property string runError

                            width: detailContent.width
                            height: 40
                            color: runMouse.containsMouse ? Theme.surfaceHover : "transparent"

                            Row {
                                anchors { left: parent.left; leftMargin: Theme.spaceXl; verticalCenter: parent.verticalCenter }
                                spacing: Theme.spaceM

                                Text {
                                    text: root.formatTime(runRow.runTriggeredAt)
                                    font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                TypeChip {
                                    // GET .../runs never sends a trigger_type field (see
                                    // PipelineRunDto in the backend), so this stays blank.
                                    // Hide the pill rather than show an empty one.
                                    visible: runRow.runTriggerType.length > 0
                                    type: runRow.runTriggerType
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                RunStatusBadge {
                                    status: runRow.runStatus
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                text: root.formatDuration(runRow.runTriggeredAt, runRow.runCompletedAt)
                                font.pixelSize: Theme.fontXs; color: Theme.textDisabled
                                anchors { right: parent.right; rightMargin: Theme.spaceXl; verticalCenter: parent.verticalCenter }
                            }

                            MouseArea {
                                id: runMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.StackView.view.push(Qt.resolvedUrl("RunDetailView.qml"), {
                                    runId: runRow.runId,
                                    pipelineId: rowItem.pipelineId,
                                    runStatus: runRow.runStatus,
                                    runTriggeredAt: runRow.runTriggeredAt,
                                    runCompletedAt: runRow.runCompletedAt,
                                    runError: runRow.runError
                                })
                            }

                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        }
                    }
                }
            }
        }
    }

    // Declared after the ListView above (not before) so it stacks on top.
    // ListView is a Flickable and captures press events across its full
    // bounds even with zero delegates, which would otherwise swallow clicks
    // on this button.
    EmptyState {
        visible: !PipelineModel.loading && PipelineModel.count === 0
        anchors.centerIn: parent
        icon: "qrc:/tb/git-merge.svg"
        title: qsTr("No pipelines")
        message: qsTr("Create a pipeline to automate camera events.")
        actionText: qsTr("+ Add Pipeline")
        onActionClicked: addDialog.open()
    }

    /* ----- Dialogs ----- */
    AddPipelineDialog { id: addDialog }

    EditPipelineDialog { id: editDialog }

    TriggerDialog {
        id: triggerDialog
        onAccepted: (params) => PipelineModel.triggerPipeline(triggerDialog.pipelineId, params)
    }

    Toast { id: toast; z: 10 }

    ConfirmDialog {
        id: confirmDialog
        title: qsTr("Delete pipeline")
        message: qsTr("Delete \"%1\"?").arg(root.pendingDeleteName)
        confirmLabel: qsTr("Delete")
        onConfirmed: root.requestDeletePipeline(root.pendingDeleteId, root.pendingDeleteName)
    }

    Connections {
        target: PipelineModel
        function onUpdatePipelineFailed(message) { toast.show(message) }
    }
}
