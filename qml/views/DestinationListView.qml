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

    Component.onCompleted: DestinationModel.refresh()

    /* ----- Undoable delete -----
       Deferred through the app-wide PendingDeletes singleton rather than a
       view-local queue; see SourceListView.qml for the rationale. */
    property int undoWindowMs: 5000

    function isDestinationPendingDelete(id) {
        const _ = PendingDeletes.version // force re-evaluation, see PendingDeletes.qml
        return PendingDeletes.isPending(id)
    }

    function requestDeleteDestination(id, name) {
        PendingDeletes.schedule(id, root.undoWindowMs, function() {
            DestinationModel.deleteDestination(id)
        })
        PendingDeletes.notify(qsTr("Deleted \"%1\"").arg(name), [id], root.undoWindowMs)
    }

    // Lets tests and App.qml's global toast action cancel a delete by id
    // without depending directly on the PendingDeletes singleton's API.
    function undoDelete(ids) {
        for (const id of ids)
            PendingDeletes.cancel(id)
    }

    /* ----- Header ----- */
    Rectangle {
        id: header
        height: 44
        color: "transparent"
        anchors { left: parent.left; right: parent.right; top: parent.top }

        Text {
            text: qsTr("Destinations")
            font.pixelSize: Theme.fontM
            font.weight: Font.Medium
            color: Theme.textPrimary
            anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
        }

        Rectangle {
            width: 130; height: 30; radius: Theme.radiusS
            color: addMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent
            anchors { right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }

            Text {
                anchors.centerIn: parent
                text: qsTr("+ Add Destination")
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
        visible: DestinationModel.loading
        anchors.centerIn: parent
        text: qsTr("Loading…")
        font.pixelSize: Theme.fontS
        color: Theme.textDisabled
    }

    /* ----- List ----- */
    ListView {
        id: list
        model: DestinationModel
        clip: true
        anchors {
            left: parent.left; right: parent.right
            top: searchBar.bottom; bottom: parent.bottom
            topMargin: Theme.spaceM
        }

        delegate: Rectangle {
            id: row
            objectName: "destinationRow_" + destId

            required property string destId
            required property string destName
            required property string destType
            required property bool destEnabled

            width: list.width
            height: visible ? 48 : 0
            visible: !root.isDestinationPendingDelete(destId) &&
                     (searchBar.text.length === 0 ||
                      destName.toLowerCase().includes(searchBar.text.toLowerCase()))
            color: rowMouse.containsMouse ? Theme.surfaceHover : "transparent"

            TypeChip {
                id: chip
                type: row.destType
                anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
            }

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
                        root.pendingDeleteId = row.destId
                        root.pendingDeleteName = row.destName
                        confirmDialog.open()
                    }
                }

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

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
                    objectName: "editDestinationButton_" + row.destId
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        editDialog.destinationId = row.destId
                        editDialog.isEditMode = true
                        editDialog.open()
                    }
                }

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            Row {
                id: statusRow
                spacing: Theme.spaceXs
                anchors { right: editBtn.left; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: row.destEnabled ? Theme.success : Theme.textDisabled
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: row.destEnabled ? qsTr("Enabled") : qsTr("Disabled")
                    font.pixelSize: Theme.fontXs
                    color: row.destEnabled ? Theme.textSecondary : Theme.textDisabled
                }
            }

            Text {
                text: row.destName
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
        visible: !DestinationModel.loading && DestinationModel.count === 0
        anchors.centerIn: parent
        icon: "qrc:/tb/git-merge.svg"
        title: qsTr("No destinations")
        message: qsTr("Add a destination to use as a pipeline output.")
        actionText: qsTr("+ Add Destination")
        onActionClicked: addDialog.open()
    }

    /* ----- Dialogs ----- */
    AddDestinationDialog { id: addDialog }
    AddDestinationDialog { id: editDialog; objectName: "editDestinationDialog" }

    ConfirmDialog {
        id: confirmDialog
        title: qsTr("Delete destination")
        message: qsTr("Delete this destination? Any pipelines routing to it will stop delivering.")
        confirmLabel: qsTr("Delete")
        onConfirmed: root.requestDeleteDestination(root.pendingDeleteId, root.pendingDeleteName)
    }
}
