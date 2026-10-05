// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

Rectangle {
    id: root

    property bool recording: false

    width: 8
    height: 8
    radius: 4
    color: recording ? Theme.error : Theme.textDisabled

    SequentialAnimation on opacity {
        running: root.recording
        loops: Animation.Infinite
        NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
        onStopped: root.opacity = 1.0
    }

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
}
