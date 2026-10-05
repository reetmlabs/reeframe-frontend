// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Popup {
    id: root

    property string cameraId: ""
    property string cameraName: ""
    property string cameraLocation: ""
    property string cameraRtspUrl: ""
    property string cameraSubRtspUrl: ""
    property string cameraUsername: ""
    property bool cameraEnabled: true

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 0
    closePolicy: Popup.CloseOnEscape

    onOpened: {
        nameField.text = root.cameraName
        locationField.text = root.cameraLocation
        rtspField.text = root.cameraRtspUrl
        subRtspField.text = root.cameraSubRtspUrl
        userField.text = root.cameraUsername
        passField.text = ""
        enabledToggle.checked = root.cameraEnabled
        excludeOverlayToggle.checked = OverlayPrefs.excludedCameras.indexOf(root.cameraId) !== -1
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

    contentItem: Item {
        implicitWidth: 460
        implicitHeight: content.implicitHeight + Theme.spaceXl * 2

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spaceXl }
            spacing: Theme.spaceM

            Row {
                spacing: Theme.spaceS
                TblIcon { source: "qrc:/tb/video.svg"; size: 20; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: qsTr("Edit Camera")
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
                placeholderText: qsTr("optional")
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
                    Text { text: qsTr("New password (blank = keep)"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary }
                    TextField {
                        id: passField
                        width: parent.width; height: 36
                        placeholderText: qsTr("leave blank to keep")
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

            Row {
                spacing: Theme.spaceM

                Text {
                    text: qsTr("Exclude from overlay")
                    font.pixelSize: Theme.fontS
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }

                ToggleSwitch {
                    id: excludeOverlayToggle
                    anchors.verticalCenter: parent.verticalCenter
                    onToggled: (checked) => OverlayPrefs.setExcluded(root.cameraId, checked)
                }
            }

            Item { width: 1; height: Theme.spaceXs }

            Row {
                layoutDirection: Qt.RightToLeft
                spacing: Theme.spaceS
                width: parent.width

                Rectangle {
                    width: 80; height: 32; radius: Theme.radiusS
                    color: saveMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent
                    enabled: nameField.text.trim().length > 0 && rtspField.text.trim().length > 0

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Save")
                        font.pixelSize: Theme.fontS; font.weight: Font.Medium
                        color: parent.enabled ? Theme.textOnAccent : Theme.textDisabled
                    }

                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            CameraModel.updateCamera(
                                root.cameraId,
                                nameField.text.trim(),
                                locationField.text.trim(),
                                rtspField.text.trim(),
                                subRtspField.text.trim(),
                                userField.text.trim(),
                                passField.text,
                                enabledToggle.checked
                            )
                            root.close()
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
