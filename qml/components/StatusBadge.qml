// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

// Pill badge. status: "enabled" | "disabled" | "recording"
Rectangle {
    id: root

    property string status: "disabled"

    implicitWidth: label.implicitWidth + Theme.spaceM
    implicitHeight: 20
    radius: 10

    color: {
        switch (status) {
        case "enabled":   return Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.12)
        case "recording": return Qt.rgba(Theme.error.r,   Theme.error.g,   Theme.error.b,   0.12)
        default:          return "transparent"
        }
    }

    border.width: 1
    border.color: {
        switch (status) {
        case "enabled":   return Theme.success
        case "recording": return Theme.error
        default:          return Theme.textDisabled
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: {
            switch (root.status) {
            case "enabled":   return "Enabled"
            case "recording": return "Recording"
            default:          return "Disabled"
            }
        }
        font.pixelSize: Theme.fontXs
        color: {
            switch (root.status) {
            case "enabled":   return Theme.success
            case "recording": return Theme.error
            default:          return Theme.textDisabled
            }
        }
    }

    SequentialAnimation on opacity {
        running: root.status === "recording"
        loops: Animation.Infinite
        NumberAnimation { to: 0.4; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
        onStopped: root.opacity = 1.0
    }
}
