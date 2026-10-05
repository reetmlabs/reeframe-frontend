// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

// Pill badge for run status.
// status: "pending" | "running" | "completed" | "failed" | "cancelled"
Rectangle {
    id: root

    property string status: "pending"

    implicitWidth: label.implicitWidth + Theme.spaceL
    implicitHeight: 20
    radius: 10

    color: {
        switch (status) {
        case "running":   return Qt.rgba(Theme.warning.r,  Theme.warning.g,  Theme.warning.b,  0.12)
        case "completed": return Qt.rgba(Theme.success.r,  Theme.success.g,  Theme.success.b,  0.12)
        case "failed":    return Qt.rgba(Theme.error.r,    Theme.error.g,    Theme.error.b,    0.12)
        default:          return "transparent"
        }
    }

    border.width: 1
    border.color: {
        switch (status) {
        case "running":   return Theme.warning
        case "completed": return Theme.success
        case "failed":    return Theme.error
        default:          return Theme.textDisabled
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: {
            switch (root.status) {
            case "running":   return "Running"
            case "completed": return "Completed"
            case "failed":    return "Failed"
            case "cancelled": return "Cancelled"
            default:          return "Pending"
            }
        }
        font.pixelSize: Theme.fontXs
        color: {
            switch (root.status) {
            case "running":   return Theme.warning
            case "completed": return Theme.success
            case "failed":    return Theme.error
            default:          return Theme.textDisabled
            }
        }
    }

    SequentialAnimation on opacity {
        running: root.status === "running"
        loops: Animation.Infinite
        NumberAnimation { to: 0.4; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
        onStopped: root.opacity = 1.0
    }
}
