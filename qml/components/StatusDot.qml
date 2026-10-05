// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

// Status indicator dot. Maps BackendClient::Status int values:
//   0 Disconnected  1 Connecting  2 Online  3 Error
Rectangle {
    id: root

    property int status: 0

    width: 8
    height: 8
    radius: 4

    color: {
        switch (status) {
        case 2:  return Theme.success
        case 1:  return Theme.warning
        case 3:  return Theme.error
        default: return Theme.textDisabled
        }
    }

    SequentialAnimation on opacity {
        running: root.status === 1
        loops: Animation.Infinite
        NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
        onStopped: root.opacity = 1.0
    }

    Behavior on color {
        ColorAnimation { duration: Theme.durationFast }
    }
}
