// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

// Compact pill showing a source or destination type string.
Rectangle {
    id: root

    property string type: ""

    implicitWidth: label.implicitWidth + Theme.spaceL
    implicitHeight: 20
    radius: 10
    color: Theme.surfaceCard
    border.color: Theme.border
    border.width: 1

    function displayName(t) {
        const map = {
            "mqtt":          "MQTT",
            "homeassistant": "Home Assistant",
            "webhook":       "Webhook",
            "poller":        "Poller",
            "filewatcher":   "File Watcher",
            "s3":            "S3",
            "sftp":          "SFTP",
            "smb":           "SMB",
            "local":         "Local",
            "telegram":      "Telegram",
            "email":         "Email",
            "slack":         "Slack",
            "sms":           "SMS",
            "manual":        "Manual",
            "scheduled":     "Scheduled",
            "event":         "Event",
            "user":          "User",
            "system":        "System"
        }
        return map[t] || t
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.displayName(root.type)
        font.pixelSize: Theme.fontXs
        color: Theme.textSecondary
    }
}
