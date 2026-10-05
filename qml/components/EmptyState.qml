// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

// Shared "nothing here yet" surface for list/panel/canvas views: an icon,
// a title, an optional secondary hint, and an optional call-to-action button.
Column {
    id: root

    property string icon: ""
    property int iconSize: 40
    property string title: ""
    property string message: ""
    property string actionText: ""

    signal actionClicked()

    width: 220
    spacing: Theme.spaceM

    TblIcon {
        visible: root.icon.length > 0
        source: root.icon
        size: root.iconSize
        color: Theme.textDisabled
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Text {
        visible: root.title.length > 0
        text: root.title
        font.pixelSize: Theme.fontM
        color: Theme.textSecondary
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        width: parent.width
    }

    Text {
        visible: root.message.length > 0
        text: root.message
        font.pixelSize: Theme.fontS
        color: Theme.textDisabled
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        width: parent.width
    }

    HoverButton {
        objectName: "emptyStateActionButton"
        visible: root.actionText.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        variant: "primary"
        text: root.actionText
        onClicked: root.actionClicked()
    }
}
