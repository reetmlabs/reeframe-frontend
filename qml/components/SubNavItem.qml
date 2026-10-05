// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

// Sub-level nav entry, always hidden when the sidebar is collapsed.
// Indented one level deeper than NavItem (spaceM indent + spaceXl icon slot).
Rectangle {
    id: root

    property string label:    ""
    property string iconText: ""
    property bool   active:   false

    signal clicked()

    height:  visible ? 36 : 0
    // Collapse visibility is controlled externally by the parent NavItem's column.

    color: active ? Theme.surfaceHover : (mouse.containsMouse ? Theme.surfaceHover : "transparent")

    Behavior on height {
        NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic }
    }

    Rectangle {
        visible:  root.active
        width:    2
        color:    Theme.accent
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
    }

    // Fixed width matches NavItem's icon column so icons line up across levels.
    Item {
        id:     iconSlot
        width:  Theme.spaceXl
        height: parent.height
        x:      Theme.spaceM + Theme.spaceXl   // NavItem indent + NavItem icon slot

        Text {
            text:           root.iconText
            font.pixelSize: Theme.fontS
            color:          root.active ? Theme.textPrimary : Theme.textSecondary
            anchors.centerIn: parent
            visible:        root.iconText.length > 0
        }
    }

    Text {
        text:           root.label
        font.pixelSize: Theme.fontS
        color:          root.active ? Theme.textPrimary : Theme.textSecondary
        anchors {
            left:           iconSlot.right
            leftMargin:     Theme.spaceS
            verticalCenter: parent.verticalCenter
            right:          parent.right
            rightMargin:    Theme.spaceS
        }
        elide: Text.ElideRight
    }

    MouseArea {
        id:           mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked:    root.clicked()
    }

    Behavior on color {
        ColorAnimation { duration: Theme.durationFast }
    }
}
