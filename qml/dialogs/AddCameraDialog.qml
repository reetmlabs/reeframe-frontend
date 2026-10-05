// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Popup {
    id: root
    objectName: "addCameraDialog"

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 0
    closePolicy: Popup.CloseOnEscape

    // Caller sets these before open() to seed a "Duplicate camera" request
    // (see CameraPanel.qml's context menu); left at defaults for a plain
    // "+ Add Camera" open. Username/password are never prefilled.
    property string prefillName: ""
    property string prefillLocation: ""
    property string prefillRtspUrl: ""
    property string prefillSubRtspUrl: ""
    property bool prefillEnabled: true

    onOpened: {
        nameField.text = prefillName
        locationField.text = prefillLocation
        rtspField.text = prefillRtspUrl
        subRtspField.text = prefillSubRtspUrl
        userField.text = ""
        passField.text = ""
        enabledToggle.checked = prefillEnabled
        errorText.text = ""
        nameField.forceActiveFocus()
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
        target: CameraModel
        function onCreateCameraSucceeded() { root.close() }
        function onCreateCameraFailed(error) { errorText.text = error }
    }

    contentItem: Item {
        implicitWidth: 460
        implicitHeight: content.implicitHeight + Theme.spaceXl * 2

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spaceXl }
            spacing: Theme.spaceM

            Row {
                spacing: Theme.spaceS
                TblIcon { source: "qrc:/tb/video-plus.svg"; size: 20; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: qsTr("Add Camera")
                    font.pixelSize: Theme.fontL
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { width: 1; height: Theme.spaceXs }

            Text { text: qsTr("Name *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
            TextField {
                id: nameField
                width: parent.width; height: 36
                placeholderText: qsTr("e.g. Front Door")
                color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                background: Rectangle {
                    color: Theme.surface
                    border.color: nameField.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radiusS
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            Text { text: qsTr("Location"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
            TextField {
                id: locationField
                width: parent.width; height: 36
                placeholderText: qsTr("e.g. Floor 2 – East corridor (optional)")
                color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                background: Rectangle {
                    color: Theme.surface
                    border.color: locationField.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radiusS
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            Text { text: qsTr("RTSP URL (main stream) *"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
            TextField {
                id: rtspField
                width: parent.width; height: 36
                placeholderText: "rtsp://192.168.1.10:554/stream1"
                color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                background: Rectangle {
                    color: Theme.surface
                    border.color: rtspField.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radiusS
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            Text { text: qsTr("RTSP URL (sub stream)"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
            TextField {
                id: subRtspField
                width: parent.width; height: 36
                placeholderText: qsTr("rtsp://192.168.1.10:554/stream2 (optional)")
                color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                background: Rectangle {
                    color: Theme.surface
                    border.color: subRtspField.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radiusS
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spaceM

                Column {
                    width: (parent.width - Theme.spaceM) / 2
                    spacing: Theme.spaceS
                    Text { text: qsTr("Username"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                    TextField {
                        id: userField
                        width: parent.width; height: 36
                        placeholderText: "admin"
                        color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                        font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                        background: Rectangle {
                            color: Theme.surface
                            border.color: userField.activeFocus ? Theme.accent : Theme.border
                            radius: Theme.radiusS
                            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                        }
                    }
                }

                Column {
                    width: (parent.width - Theme.spaceM) / 2
                    spacing: Theme.spaceS
                    Text { text: qsTr("Password"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                    TextField {
                        id: passField
                        width: parent.width; height: 36
                        placeholderText: "••••••••"
                        echoMode: TextInput.Password
                        color: Theme.textPrimary; placeholderTextColor: Theme.textDisabled
                        font.pixelSize: Theme.fontS; leftPadding: Theme.spaceM; selectionColor: Theme.accent
                        background: Rectangle {
                            color: Theme.surface
                            border.color: passField.activeFocus ? Theme.accent : Theme.border
                            radius: Theme.radiusS
                            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                        }
                    }
                }
            }

            Row {
                spacing: Theme.spaceM

                Text {
                    text: qsTr("Enabled")
                    font.pixelSize: Theme.fontS
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    id: enabledToggle
                    property bool checked: true
                    width: 44; height: 24; radius: 12
                    color: checked ? Theme.accent : Theme.border
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 18; height: 18; radius: 9
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        x: enabledToggle.checked ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: enabledToggle.checked = !enabledToggle.checked
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            Text {
                id: errorText
                objectName: "addCameraErrorText"
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
                    width: 80; height: 32; radius: Theme.radiusS
                    color: addMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Add")
                        font.pixelSize: Theme.fontS; font.weight: Font.Medium
                        color: Theme.textOnAccent
                    }

                    MouseArea {
                        id: addMouse
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Always clickable; errors surface on click instead of disabling
                            // the button, which would give no feedback about what's wrong.
                            if (nameField.text.trim().length === 0) {
                                errorText.text = qsTr("Name is required.")
                                return
                            }
                            if (rtspField.text.trim().length === 0) {
                                errorText.text = qsTr("RTSP URL (main stream) is required.")
                                return
                            }
                            errorText.text = ""
                            CameraModel.createCamera(
                                nameField.text.trim(),
                                locationField.text.trim(),
                                rtspField.text.trim(),
                                subRtspField.text.trim(),
                                userField.text.trim(),
                                passField.text,
                                enabledToggle.checked
                            )
                        }
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                Rectangle {
                    width: 80; height: 32; radius: Theme.radiusS
                    color: cancelMouse.containsMouse ? Theme.surfaceHover : "transparent"
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Cancel")
                        font.pixelSize: Theme.fontS; color: Theme.textPrimary
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
            }
        }
    }
}
