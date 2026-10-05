// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic
import "../components"
import "../dialogs"

Item {
    id: root

    property string pendingDeleteId: ""
    property string pendingDeleteName: ""

    Component.onCompleted: SourceModel.refresh()

    /* ----- Undoable delete -----
       Deferred through the app-wide PendingDeletes singleton rather than a
       view-local queue, since App.qml's StackView destroys this view on
       navigation, which would drop a view-owned pending Timer before it
       fires. See PipelineListView.qml for the same pattern. */
    property int undoWindowMs: 5000

    function isSourcePendingDelete(id) {
        const _ = PendingDeletes.version // force re-evaluation, see PendingDeletes.qml
        return PendingDeletes.isPending(id)
    }

    function requestDeleteSource(id, name) {
        PendingDeletes.schedule(id, root.undoWindowMs, function() {
            SourceModel.deleteSource(id)
        })
        PendingDeletes.notify(qsTr("Deleted \"%1\"").arg(name), [id], root.undoWindowMs)
    }

    // Lets tests and App.qml's global toast action cancel a delete by id
    // without depending directly on the PendingDeletes singleton's API.
    function undoDelete(ids) {
        for (const id of ids)
            PendingDeletes.cancel(id)
    }

    /* ----- Global command palette jump target ----- */
    property string flashSourceId: ""

    function flashSource(id) {
        searchBar.text = ""
        const idx = SourceModel.sourceIndexById(id)
        if (idx >= 0)
            list.positionViewAtIndex(idx, ListView.Contain)
        root.flashSourceId = id
        flashTimer.restart()
    }

    Timer {
        id: flashTimer
        interval: 1500
        onTriggered: root.flashSourceId = ""
    }

    /* ----- Header ----- */
    Rectangle {
        id: header
        height: 44
        color: "transparent"
        anchors { left: parent.left; right: parent.right; top: parent.top }

        Text {
            text: qsTr("Sources")
            font.pixelSize: Theme.fontM
            font.weight: Font.Medium
            color: Theme.textPrimary
            anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
        }

        Rectangle {
            width: 110; height: 30; radius: Theme.radiusS
            color: addMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent
            anchors { right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }

            Text {
                anchors.centerIn: parent
                text: qsTr("+ Add Source")
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
        visible: SourceModel.loading
        anchors.centerIn: parent
        text: qsTr("Loading…")
        font.pixelSize: Theme.fontS
        color: Theme.textDisabled
    }

    /* ----- List ----- */
    ListView {
        id: list
        model: SourceModel
        clip: true
        anchors {
            left: parent.left; right: parent.right
            top: searchBar.bottom; bottom: parent.bottom
            topMargin: Theme.spaceM
        }

        delegate: Rectangle {
            id: row
            objectName: "sourceRow_" + sourceId

            required property string sourceId
            required property string sourceName
            required property string sourceType
            required property bool sourceEnabled

            width: list.width
            height: visible ? 48 : 0
            visible: !root.isSourcePendingDelete(sourceId) &&
                     (searchBar.text.length === 0 ||
                      sourceName.toLowerCase().includes(searchBar.text.toLowerCase()))
            color: row.sourceId === root.flashSourceId
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                : (rowMouse.containsMouse ? Theme.surfaceHover : "transparent")

            /* Type chip */
            TypeChip {
                id: chip
                type: row.sourceType
                anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
            }

            /* Delete button */
            Rectangle {
                id: deleteBtn
                // Above rowMouse (declared later below), which anchors.fill:
                // parent and would otherwise swallow clicks meant for delMouse.
                z: 1
                width: 28; height: 28; radius: Theme.radiusS
                color: delMouse.containsMouse
                    ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15) : "transparent"
                anchors { right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: Theme.fontXs
                    color: delMouse.containsMouse ? Theme.error : Theme.textSecondary
                }

                MouseArea {
                    id: delMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.pendingDeleteId = row.sourceId
                        root.pendingDeleteName = row.sourceName
                        confirmDialog.open()
                    }
                }

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            /* Edit button */
            Rectangle {
                id: editBtn
                // Above rowMouse (declared later below), which anchors.fill:
                // parent and would otherwise swallow clicks meant for editMouse.
                z: 1
                width: 28; height: 28; radius: Theme.radiusS
                color: editMouse.containsMouse ? Theme.surfaceHover : "transparent"
                anchors { right: deleteBtn.left; rightMargin: Theme.spaceXs; verticalCenter: parent.verticalCenter }

                Text {
                    anchors.centerIn: parent
                    text: "✎"
                    font.pixelSize: Theme.fontXs
                    color: editMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                }

                MouseArea {
                    id: editMouse
                    objectName: "editSourceButton_" + row.sourceId
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        editDialog.sourceId = row.sourceId
                        editDialog.isEditMode = true
                        editDialog.open()
                    }
                }

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            /* Enabled dot + label */
            Row {
                id: statusRow
                spacing: Theme.spaceXs
                anchors { right: editBtn.left; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: row.sourceEnabled ? Theme.success : Theme.textDisabled
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: row.sourceEnabled ? qsTr("Enabled") : qsTr("Disabled")
                    font.pixelSize: Theme.fontXs
                    color: row.sourceEnabled ? Theme.textSecondary : Theme.textDisabled
                }
            }

            /* Name */
            Text {
                text: row.sourceName
                font.pixelSize: Theme.fontS
                font.weight: Font.Medium
                color: Theme.textPrimary
                elide: Text.ElideRight
                anchors {
                    left: chip.right; leftMargin: Theme.spaceM
                    right: statusRow.left; rightMargin: Theme.spaceM
                    verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
            }

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }
    }

    // Declared after the ListView above (not before) so it stacks on top.
    // ListView is a Flickable and captures press events across its full
    // bounds even with zero delegates, which would otherwise swallow clicks
    // on this button.
    EmptyState {
        visible: !SourceModel.loading && SourceModel.count === 0
        anchors.centerIn: parent
        icon: "qrc:/tb/git-merge.svg"
        title: qsTr("No sources")
        message: qsTr("Add a source to use as a pipeline trigger.")
        actionText: qsTr("+ Add Source")
        onActionClicked: addDialog.open()
    }

    /* ----- Dialogs ----- */
    AddSourceDialog { id: addDialog }
    AddSourceDialog { id: editDialog; objectName: "editSourceDialog" }

    ConfirmDialog {
        id: confirmDialog
        title: qsTr("Delete source")
        message: qsTr("Delete this source? Any pipelines using it will stop receiving events.")
        confirmLabel: qsTr("Delete")
        onConfirmed: root.requestDeleteSource(root.pendingDeleteId, root.pendingDeleteName)
    }
}
