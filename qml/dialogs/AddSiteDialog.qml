// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Popup {
    id: root
    objectName: "addSiteDialog"

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 0
    closePolicy: Popup.CloseOnEscape

    onOpened: {
        nameField.text = ""
        urlField.text = ""
        testState = "idle"
        nameField.forceActiveFocus()
    }

    // "idle" | "testing" | "ok" | "fail"
    property string testState: "idle"
    property string testVersion: ""

    background: Rectangle {
        color: Theme.surfaceCard
        border.color: Theme.border
        radius: Theme.radiusM
    }

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    Connections {
        target: SiteManager
        function onTestConnectionResult(success, version) {
            root.testState = success ? "ok" : "fail"
            root.testVersion = version
        }
    }

    contentItem: Item {
        implicitWidth: 420
        implicitHeight: content.implicitHeight + Theme.spaceXl * 2

        Column {
            id: content
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.spaceXl
            }
            spacing: Theme.spaceM

            Row {
                spacing: Theme.spaceS
                TblIcon { source: "qrc:/tb/world.svg"; size: 20; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: qsTr("Add Site")
                    font.pixelSize: Theme.fontL
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { width: 1; height: Theme.spaceXs }

            Text {
                text: qsTr("Display name")
                font.pixelSize: Theme.fontXs
                color: Theme.textSecondary
            }

            TextField {
                id: nameField
                width: parent.width
                height: 36
                placeholderText: qsTr("e.g. HQ Building A")
                color: Theme.textPrimary
                placeholderTextColor: Theme.textDisabled
                font.pixelSize: Theme.fontS
                leftPadding: Theme.spaceM
                selectionColor: Theme.accent

                background: Rectangle {
                    color: Theme.surface
                    border.color: nameField.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radiusS
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            Text {
                text: qsTr("URL")
                font.pixelSize: Theme.fontXs
                color: Theme.textSecondary
            }

            Row {
                width: parent.width
                spacing: Theme.spaceS

                TextField {
                    id: urlField
                    width: parent.width - testBtn.width - Theme.spaceS
                    height: 36
                    placeholderText: "http://192.168.1.100:8080"
                    color: Theme.textPrimary
                    placeholderTextColor: Theme.textDisabled
                    font.pixelSize: Theme.fontS
                    leftPadding: Theme.spaceM
                    selectionColor: Theme.accent

                    background: Rectangle {
                        color: Theme.surface
                        border.color: urlField.activeFocus ? Theme.accent : Theme.border
                        radius: Theme.radiusS
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                    }

                    onTextChanged: root.testState = "idle"
                }

                Rectangle {
                    id: testBtn
                    width: 70
                    height: 36
                    radius: Theme.radiusS
                    color: testMouse.containsMouse ? Theme.surfaceHover : "transparent"
                    border.color: Theme.border
                    enabled: urlField.text.trim().length > 0

                    Text {
                        anchors.centerIn: parent
                        text: root.testState === "testing" ? "…" : qsTr("Test")
                        font.pixelSize: Theme.fontS
                        color: parent.enabled ? Theme.textPrimary : Theme.textDisabled
                    }

                    MouseArea {
                        id: testMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.testState = "testing"
                            SiteManager.testConnection(urlField.text.trim())
                        }
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            Text {
                visible: root.testState === "ok" || root.testState === "fail"
                width: parent.width
                text: root.testState === "ok"
                    ? (qsTr("✓ Connected") + (root.testVersion.length ? " · " + root.testVersion : ""))
                    : qsTr("✗ Could not connect")
                font.pixelSize: Theme.fontXs
                color: root.testState === "ok" ? Theme.success : Theme.error
            }

            Item { width: 1; height: Theme.spaceXs }

            Row {
                layoutDirection: Qt.RightToLeft
                spacing: Theme.spaceS
                width: parent.width

                Rectangle {
                    width: 80
                    height: 32
                    radius: Theme.radiusS
                    color: addMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent
                    enabled: nameField.text.trim().length > 0 && urlField.text.trim().length > 0

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Add")
                        font.pixelSize: Theme.fontS
                        font.weight: Font.Medium
                        color: Theme.textOnAccent
                    }

                    MouseArea {
                        id: addMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const siteId = SiteManager.addSite(nameField.text.trim())
                            SiteManager.addNode(siteId, urlField.text.trim())
                            // Switching to it immediately is what
                            // prompts for credentials: App.qml's sign-in
                            // gate reacts to whichever site is active, and
                            // a brand new node never has a session yet.
                            SiteManager.activeSiteIndex = SiteManager.siteIndexById(siteId)
                            root.close()
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
