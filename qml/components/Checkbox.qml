// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

// Shared selection checkbox for multi-select list rows (camera/pipeline/
// source lists). Custom-drawn rather than QtQuick.Controls.CheckBox to
// match this app's hand-styled control aesthetic (see ToggleSwitch.qml).
Rectangle {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    width: 16
    height: 16
    radius: Theme.radiusS
    color: root.checked ? Theme.accent : "transparent"
    border.color: root.checked ? Theme.accent : Theme.border
    border.width: 1

    activeFocusOnTab: root.enabled

    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: root.checked
    Accessible.focusable: root.enabled
    Accessible.onPressAction: if (root.enabled) root.toggled(!root.checked)

    Keys.onPressed: (event) => {
        if (!root.enabled)
            return
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.toggled(!root.checked)
            event.accepted = true
        }
    }

    Rectangle {
        visible: root.checked
        anchors.centerIn: parent
        width: 8
        height: 8
        radius: 2
        color: Theme.textOnAccent
    }

    // Never writes to its own `checked` property, since that would silently
    // sever a caller's `checked: someExpression` binding on the first
    // click (a plain property write inside the component overrides any
    // binding assigned from outside). Instead this only emits `toggled`
    // and leaves it to the caller to update whatever `checked` is bound to.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }

    // Keyboard-focus indicator, drawn outside the checkbox's own bounds so
    // it doesn't compete with the checked/unchecked border for the same
    // edge. HoverButton.qml uses the same pattern.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: Theme.radiusS + 3
        color: "transparent"
        border.width: 2
        border.color: Theme.focusRing
        visible: root.activeFocus
    }

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
}
