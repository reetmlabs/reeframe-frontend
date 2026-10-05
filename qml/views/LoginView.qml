// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

// Blocking sign-in screen for a single site's primary node. Shown by
// App.qml whenever the active site has a configured node but no session.
// Every route except the health check requires a valid token, so nothing
// else in the app can do anything useful until this resolves.
Item {
    id: root

    property string siteName: ""
    property var client: null

    property bool signingIn: false
    property string errorMessage: ""

    function attemptSignIn() {
        if (!root.client || usernameField.text.length === 0 || passwordField.text.length === 0)
            return
        root.signingIn = true
        root.errorMessage = ""
        root.client.signIn(usernameField.text, passwordField.text)
    }

    onClientChanged: {
        root.signingIn = false
        root.errorMessage = ""
        usernameField.text = ""
        passwordField.text = ""
    }

    Connections {
        target: root.client
        enabled: root.client !== null
        function onSignInFailed(message) {
            root.signingIn = false
            root.errorMessage = message
        }
        function onSessionChanged() {
            if (root.client && root.client.hasSession)
                root.signingIn = false
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spaceM
        width: 280

        Text {
            text: qsTr("Sign in to %1").arg(root.siteName)
            font.pixelSize: Theme.fontL
            font.weight: Font.Medium
            color: Theme.textPrimary
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        TextField {
            id: usernameField
            objectName: "loginUsernameField"
            width: parent.width; height: 36
            placeholderText: qsTr("Username")
            color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
            font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
            background: Rectangle {
                color: Theme.surfaceCard
                border.color: usernameField.activeFocus ? Theme.accent : Theme.border
                radius: Theme.radiusS
                Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
            }
            onAccepted: passwordField.forceActiveFocus()
        }

        TextField {
            id: passwordField
            objectName: "loginPasswordField"
            width: parent.width; height: 36
            placeholderText: qsTr("Password")
            echoMode: TextInput.Password
            color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
            font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
            background: Rectangle {
                color: Theme.surfaceCard
                border.color: passwordField.activeFocus ? Theme.accent : Theme.border
                radius: Theme.radiusS
                Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
            }
            onAccepted: root.attemptSignIn()
        }

        Text {
            objectName: "loginErrorText"
            visible: root.errorMessage.length > 0
            text: root.errorMessage
            color: Theme.error
            font.pixelSize: Theme.fontXs
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        HoverButton {
            objectName: "loginConnectButton"
            width: parent.width; height: 36
            variant: "primary"
            enabled: !root.signingIn && usernameField.text.length > 0 && passwordField.text.length > 0
            text: root.signingIn ? qsTr("Connecting…") : qsTr("Connect")
            onClicked: root.attemptSignIn()
        }
    }
}
