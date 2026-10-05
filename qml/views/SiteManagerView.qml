// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Item {
    id: root

    // Tracks which site the confirm dialog is acting on.
    property string pendingSiteId: ""
    property string pendingSiteName: ""

    /* ----- Undoable delete -----
       See CameraPanel.qml for the full rationale. Confirming a removal
       hides the row and defers the real SiteManager.removeSite() call
       until the undo window elapses, so "Undo" just cancels a call that
       was never sent rather than needing to re-create anything. */
    property int undoWindowMs: 5000
    property var _deleteRequested: ({})

    function isSitePendingDelete(id) {
        const _ = pendingDeletes.version // force re-evaluation, see PendingDeleteQueue.qml
        return pendingDeletes.isPending(id) || root._deleteRequested[id] === true
    }

    function requestRemoveSite(id, name) {
        root._deleteRequested[id] = true
        pendingDeletes.schedule(id, root.undoWindowMs, function() {
            SiteManager.removeSite(id)
        })
        toast.showWithAction(qsTr("Removed \"%1\"").arg(name), qsTr("Undo"), [id], root.undoWindowMs)
    }

    // Cancels one or more pending deletes; exposed as its own function so
    // it's directly callable from tests. See CameraPanel.qml's undoDelete
    // for why the flag is cleared before cancel() rather than after.
    function undoDelete(ids) {
        for (const id of ids) {
            if (!pendingDeletes.isPending(id))
                continue
            delete root._deleteRequested[id]
            pendingDeletes.cancel(id)
        }
    }

    PendingDeleteQueue { id: pendingDeletes }

    // Explicit z rather than relying on declaration order: this is
    // declared before the ListView below, and without a z override the
    // ListView's later declaration would stack on top and both hide the
    // toast and swallow clicks meant for its "Undo" button.
    Toast {
        id: toast
        z: 10
        onActionTriggered: (data) => root.undoDelete(data)
    }

    // ----- Header -----
    Rectangle {
        id: header
        height: 44
        color: "transparent"
        anchors { left: parent.left; right: parent.right; top: parent.top }

        Text {
            text: qsTr("Sites")
            font.pixelSize: Theme.fontM
            font.weight: Font.Medium
            color: Theme.textPrimary
            anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
        }

        Rectangle {
            id: addBtn
            objectName: "addSiteButton"
            width: 100
            height: 30
            radius: Theme.radiusS
            color: addMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent
            anchors { right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
            // Local mode (no Coordinator connection configured) allows exactly
            // one locally-configured site; a Coordinator connection lifts
            // this limit entirely, since sites then live in its own
            // directory rather than being added here at all.
            visible: CoordinatorManager.isCoordinatorMode || SiteManager.count === 0

            Text {
                anchors.centerIn: parent
                text: qsTr("+ Add Site")
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
            height: 1
            color: Theme.border
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        }
    }

    // ----- Site list -----
    ListView {
        id: list
        model: SiteManager
        clip: true
        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            bottom: parent.bottom
        }

        delegate: Rectangle {
            id: row
            objectName: "siteRow_" + siteId

            required property string siteId
            required property string siteName
            required property int siteWorstStatus
            required property string sitePrimaryUrl
            required property string siteVersion
            required property string siteCoordinatorUrl
            required property int index

            readonly property var client: SiteManager.clientForSite(row.siteId)
            readonly property bool hasSession: row.client !== null && row.client.hasSession

            width: list.width
            height: visible ? 52 : 0
            visible: !root.isSitePendingDelete(siteId)
            color: rowMouse.containsMouse ? Theme.surfaceHover : "transparent"

            // Left accent bar when online
            Rectangle {
                visible: row.siteWorstStatus === 2
                width: 2
                color: Theme.accent
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            }

            StatusDot {
                id: dot
                status: row.siteWorstStatus
                anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
            }

            // Right-side buttons
            Row {
                id: rightButtons
                anchors { right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                spacing: Theme.spaceS

                // Retry, only shown on error
                Rectangle {
                    visible: row.siteWorstStatus === 3
                    width: visible ? 56 : 0
                    height: 28
                    radius: Theme.radiusS
                    color: retryMouse.containsMouse ? Theme.surfaceHover : "transparent"
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Retry")
                        font.pixelSize: Theme.fontXs
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: retryMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SiteManager.checkHealth(row.siteId)
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: Theme.radiusS
                    color: removeMouse.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: Theme.fontXs
                        color: removeMouse.containsMouse ? Theme.error : Theme.textSecondary
                    }

                    MouseArea {
                        id: removeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.pendingSiteId = row.siteId
                            root.pendingSiteName = row.siteName
                            confirmDialog.open()
                        }
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            // Status / version label
            Text {
                id: statusLabel
                anchors {
                    right: rightButtons.left
                    rightMargin: Theme.spaceM
                    verticalCenter: parent.verticalCenter
                }
                text: {
                    switch (row.siteWorstStatus) {
                    case 2:  return row.siteVersion.length ? row.siteVersion : qsTr("Online")
                    case 1:  return qsTr("Connecting…")
                    case 3:  return qsTr("Error")
                    default: return qsTr("Disconnected")
                    }
                }
                font.pixelSize: Theme.fontXs
                color: {
                    switch (row.siteWorstStatus) {
                    case 2:  return Theme.textSecondary
                    case 1:  return Theme.warning
                    case 3:  return Theme.error
                    default: return Theme.textDisabled
                    }
                }
            }

            // Name + URL
            Column {
                anchors {
                    left: dot.right
                    leftMargin: Theme.spaceM
                    right: statusLabel.left
                    rightMargin: Theme.spaceM
                    verticalCenter: parent.verticalCenter
                }
                spacing: 2

                Text {
                    text: row.siteName
                    font.pixelSize: Theme.fontS
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    text: row.sitePrimaryUrl
                    font.pixelSize: Theme.fontXs
                    color: Theme.textDisabled
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    objectName: "siteRowSessionLabel_" + row.siteId
                    text: row.hasSession ? qsTr("Signed in as %1").arg(row.client.username)
                                         : qsTr("Not signed in")
                    font.pixelSize: Theme.fontXs
                    color: row.hasSession ? Theme.success : Theme.textDisabled
                    elide: Text.ElideRight
                    width: parent.width
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
        visible: SiteManager.count === 0
        anchors.centerIn: parent
        icon: "qrc:/tb/world.svg"
        title: qsTr("No sites connected")
        message: qsTr("Connect to a backend to get started.")
        actionText: qsTr("+ Add Site")
        onActionClicked: addDialog.open()
    }

    // ----- Dialogs -----
    AddSiteDialog {
        id: addDialog
    }

    ConfirmDialog {
        id: confirmDialog
        title: qsTr("Remove site")
        message: qsTr("Remove this site and disconnect from all its nodes?")
        confirmLabel: qsTr("Remove")
        onConfirmed: root.requestRemoveSite(root.pendingSiteId, root.pendingSiteName)
    }
}
