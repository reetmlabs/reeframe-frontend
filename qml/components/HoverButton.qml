// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

// Shared hover/press/active surface for every clickable element in the app.
//
// Non-primary variants show hover feedback only through border/text color,
// never an animated fill, because animating a translucent fill causes rendering
// flicker on some platforms. `primary`'s opaque fill and `active`'s
// persistent fill aren't affected.
Item {
    id: root

    property string variant: "ghost" // "ghost" | "primary" | "destructive" | "flat"
    property bool active: false
    property bool showBorder: variant === "ghost" || variant === "destructive"

    property string text: ""
    property int fontSize: Theme.fontXs
    property string icon: ""
    property int iconSize: 16
    property int spacing: Theme.spaceXs
    property int horizontalPadding: Theme.spaceM

    property alias containsMouse: mouseArea.containsMouse
    property alias pressed: mouseArea.pressed

    signal clicked()

    enabled: true
    opacity: enabled ? 1.0 : 0.4
    implicitHeight: 28
    implicitWidth: contentRow.implicitWidth + horizontalPadding * 2

    activeFocusOnTab: root.enabled

    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Accessible.focusable: root.enabled
    Accessible.onPressAction: if (root.enabled) root.clicked()

    Keys.onPressed: (event) => {
        if (!root.enabled)
            return
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.clicked()
            event.accepted = true
        }
    }

    readonly property bool _hover: mouseArea.containsMouse && root.enabled

    // fillColor, borderColor, and contentColor are all overridable. The
    // defaults cover plain ghost/primary/destructive buttons, but some
    // icon-style buttons want different hover behavior.
    property color fillColor: {
        if (variant === "primary")
            return _hover ? Qt.darker(Theme.accent, 1.1) : Theme.accent
        if (active)
            return Theme.accent
        return "transparent"
    }
    property color borderColor: {
        if (variant === "primary")
            return "transparent"
        if (variant === "destructive")
            return _hover ? Theme.error : Theme.border
        if (active)
            return Theme.accent
        return _hover ? Theme.borderHover : Theme.border
    }
    property color contentColor: {
        if (variant === "primary" || active)
            return Theme.textOnAccent
        if (variant === "destructive")
            return _hover ? Theme.error : Theme.textSecondary
        return Theme.textSecondary
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Theme.radiusS
        color: root.fillColor
        border.width: root.showBorder ? 1 : 0
        border.color: root.borderColor

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: root.icon.length > 0 && root.text.length > 0 ? root.spacing : 0

        TblIcon {
            visible: root.icon.length > 0
            source: root.icon
            size: root.iconSize
            color: root.contentColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.text.length > 0
            text: root.text
            color: root.contentColor
            font.pixelSize: root.fontSize
            font.weight: root.variant === "primary" ? Font.Medium : Font.Normal
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    // Keyboard-focus indicator: a separate outer ring since background.border
    // already carries hover/active/destructive meaning.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: Theme.radiusS + 3
        color: "transparent"
        border.width: 2
        border.color: Theme.focusRing
        visible: root.activeFocus
    }
}
