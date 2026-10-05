// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

// Manages Coordinator connections. Mirrors SiteManagerView's shape
// deliberately (same header/list/empty-state structure) but without its
// undoable-delete pattern: removing a Coordinator connection is a simpler,
// immediate operation gated by ConfirmDialog alone.
Item {
    id: root

    property string pendingUrl: ""

    // ----- Header -----
    Rectangle {
        id: header
        height: 44
        color: "transparent"
        anchors { left: parent.left; right: parent.right; top: parent.top }

        Text {
            text: qsTr("Coordinators")
            font.pixelSize: Theme.fontM
            font.weight: Font.Medium
            color: Theme.textPrimary
            anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
        }

        Rectangle {
            id: addBtn
            objectName: "addCoordinatorButton"
            width: 140
            height: 30
            radius: Theme.radiusS
            color: addMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent
            anchors { right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }

            Text {
                anchors.centerIn: parent
                text: qsTr("+ Add Coordinator")
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

    // ----- Connection list -----
    ListView {
        id: list
        model: CoordinatorManager
        clip: true
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }

        delegate: Rectangle {
            id: row
            objectName: "coordinatorRow_" + url

            required property string url
            required property bool hasSession
            required property int index

            readonly property var client: CoordinatorManager.clientFor(row.url)

            width: list.width
            height: 52
            color: rowMouse.containsMouse ? Theme.surfaceHover : "transparent"

            Row {
                id: rightButtons
                anchors { right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                spacing: Theme.spaceS

                Rectangle {
                    objectName: "coordinatorSignInButton_" + row.url
                    visible: !row.hasSession
                    width: visible ? 70 : 0
                    height: 28
                    radius: Theme.radiusS
                    color: signInMouse.containsMouse ? Theme.surfaceHover : "transparent"
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Sign in")
                        font.pixelSize: Theme.fontXs
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: signInMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            loginDialog.coordinatorUrl = row.url
                            loginDialog.client = row.client
                            loginDialog.open()
                        }
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
                            root.pendingUrl = row.url
                            confirmDialog.open()
                        }
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            Column {
                anchors {
                    left: parent.left
                    leftMargin: Theme.spaceL
                    right: rightButtons.left
                    rightMargin: Theme.spaceM
                    verticalCenter: parent.verticalCenter
                }
                spacing: 2

                Text {
                    text: row.url
                    font.pixelSize: Theme.fontS
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    elide: Text.ElideMiddle
                    width: parent.width
                }

                Text {
                    objectName: "coordinatorRowSessionLabel_" + row.url
                    text: row.hasSession && row.client
                        ? qsTr("Signed in as %1").arg(row.client.username)
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
                z: -1
            }
        }
    }

    // Declared after the ListView above so it stacks on top. ListView is a
    // Flickable and captures clicks across its bounds even with no
    // delegates, which would otherwise swallow clicks on this button.
    EmptyState {
        visible: CoordinatorManager.count === 0
        anchors.centerIn: parent
        icon: "qrc:/tb/broadcast.svg"
        title: qsTr("No Coordinators connected")
        message: qsTr("Connect to a Coordinator to manage sites across a fleet.")
        actionText: qsTr("+ Add Coordinator")
        onActionClicked: addDialog.open()
    }

    // ----- Dialogs -----
    AddCoordinatorDialog {
        id: addDialog
    }

    CoordinatorLoginDialog {
        id: loginDialog
    }

    ConfirmDialog {
        id: confirmDialog
        title: qsTr("Remove Coordinator connection")
        message: qsTr("Remove this Coordinator connection? Its sites will no longer be reachable.")
        confirmLabel: qsTr("Remove")
        onConfirmed: CoordinatorManager.removeConnection(root.pendingUrl)
    }
}
