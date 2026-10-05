// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

Rectangle {
    id: root

    property bool checked: false
    property bool enabled: true

    signal toggled(bool checked)

    width: 44
    height: 24
    radius: 12
    color: !root.enabled ? Theme.border : root.checked ? Theme.accent : Theme.border
    opacity: root.enabled ? 1.0 : 0.5

    activeFocusOnTab: root.enabled

    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: root.checked
    Accessible.focusable: root.enabled
    Accessible.onPressAction: if (root.enabled) { root.checked = !root.checked; root.toggled(root.checked) }

    Keys.onPressed: (event) => {
        if (!root.enabled)
            return
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.checked = !root.checked
            root.toggled(root.checked)
            event.accepted = true
        }
    }

    Rectangle {
        width: 18; height: 18; radius: 9
        color: "white"
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3

        Behavior on x { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }

    // Keyboard-focus indicator, drawn outside the switch's own bounds.
    // HoverButton.qml uses the same pattern.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: parent.radius + 3
        color: "transparent"
        border.width: 2
        border.color: Theme.focusRing
        visible: root.activeFocus
    }

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
}
