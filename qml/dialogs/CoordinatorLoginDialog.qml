// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

// Compact sign-in prompt for one Coordinator connection. LoginView isn't
// reused because it's a full-screen gate sized for App.qml's single active site.
// CoordinatorClient mirrors BackendClient's signIn/sessionChanged/hasSession
// shape by design, just consumed differently here.
Popup {
    id: root
    objectName: "coordinatorLoginDialog"

    property var client: null
    property string coordinatorUrl: ""

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 0
    closePolicy: Popup.CloseOnEscape

    onOpened: {
        usernameField.text = ""
        passwordField.text = ""
        errorText.text = ""
        usernameField.forceActiveFocus()
    }

    background: Rectangle {
        color: Theme.surfaceCard
        border.color: Theme.border
        radius: Theme.radiusM
    }

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    Connections {
        target: root.client
        enabled: root.client !== null
        function onSignInFailed(message) { errorText.text = message }
        function onSessionChanged() {
            if (root.client && root.client.hasSession)
                root.close()
        }
    }

    contentItem: Item {
        implicitWidth: 320
        implicitHeight: content.implicitHeight + Theme.spaceXl * 2

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spaceXl }
            spacing: Theme.spaceM

            Text {
                text: qsTr("Sign in to %1").arg(root.coordinatorUrl)
                font.pixelSize: Theme.fontL
                font.weight: Font.Medium
                color: Theme.textPrimary
                width: parent.width
                elide: Text.ElideMiddle
            }

            Item { width: 1; height: Theme.spaceXs }

            TextField {
                id: usernameField
                objectName: "coordinatorLoginUsernameField"
                width: parent.width
                height: 36
                placeholderText: qsTr("Username")
                color: Theme.textPrimary
                placeholderTextColor: Theme.textDisabled
                font.pixelSize: Theme.fontS
                leftPadding: Theme.spaceM
                selectionColor: Theme.accent
                background: Rectangle {
                    color: Theme.surface
                    border.color: usernameField.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radiusS
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                }
                onAccepted: passwordField.forceActiveFocus()
            }

            TextField {
                id: passwordField
                objectName: "coordinatorLoginPasswordField"
                width: parent.width
                height: 36
                placeholderText: qsTr("Password")
                echoMode: TextInput.Password
                color: Theme.textPrimary
                placeholderTextColor: Theme.textDisabled
                font.pixelSize: Theme.fontS
                leftPadding: Theme.spaceM
                rightPadding: Theme.spaceM + revealIcon.width + Theme.spaceXs
                selectionColor: Theme.accent
                background: Rectangle {
                    color: Theme.surface
                    border.color: passwordField.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radiusS
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                }
                onAccepted: {
                    if (root.client)
                        root.client.signIn(usernameField.text, passwordField.text)
                }

                TblIcon {
                    id: revealIcon
                    objectName: "coordinatorLoginPasswordReveal"
                    source: passwordField.echoMode === TextInput.Password ? "qrc:/tb/eye.svg" : "qrc:/tb/eye-off.svg"
                    color: Theme.textSecondary
                    size: 16
                    anchors { right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            passwordField.echoMode = passwordField.echoMode === TextInput.Password
                                ? TextInput.Normal
                                : TextInput.Password
                        }
                    }
                }
            }

            Text {
                id: errorText
                objectName: "coordinatorLoginErrorText"
                visible: text.length > 0
                width: parent.width
                color: Theme.error
                font.pixelSize: Theme.fontXs
                wrapMode: Text.WordWrap
            }

            Item { width: 1; height: Theme.spaceXs }

            Row {
                layoutDirection: Qt.RightToLeft
                spacing: Theme.spaceS
                width: parent.width

                Rectangle {
                    objectName: "coordinatorLoginConnectButton"
                    width: 90
                    height: 32
                    radius: Theme.radiusS
                    color: connectMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent
                    enabled: usernameField.text.length > 0 && passwordField.text.length > 0

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Sign In")
                        font.pixelSize: Theme.fontS
                        font.weight: Font.Medium
                        color: Theme.textOnAccent
                    }

                    MouseArea {
                        id: connectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.client)
                                root.client.signIn(usernameField.text, passwordField.text)
                        }
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                Rectangle {
                    width: 80
                    height: 32
                    radius: Theme.radiusS
                    color: cancelMouse.containsMouse ? Theme.surfaceHover : "transparent"
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Cancel")
                        font.pixelSize: Theme.fontS
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
            }
        }
    }
}
