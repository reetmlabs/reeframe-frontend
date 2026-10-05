// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

// Vertical strip of icon buttons, one per dockable side panel. Clicking an
// entry opens, raises, or closes its panel depending on current state.
Rectangle {
    id: root

    readonly property int railWidth: 40

    property var entries: []
    property var controller: null

    signal entryClicked(string id)

    width: root.railWidth
    color: Theme.surfaceAlt

    Rectangle {
        width: 1
        color: Theme.border
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
    }

    Column {
        anchors { left: parent.left; leftMargin: 1; right: parent.right; top: parent.top; topMargin: Theme.spaceS }

        Repeater {
            model: root.entries

            delegate: Item {
                id: entryItem
                required property var modelData

                readonly property bool open: root.controller ? root.controller.isOpen(modelData.id) : false

                width: root.railWidth - 1
                height: root.railWidth

                Rectangle {
                    visible: entryItem.open
                    width: 3
                    color: Theme.accent
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                }

                TblIcon {
                    source: entryItem.modelData.icon
                    size: 18
                    color: entryItem.open ? Theme.accent : Theme.textSecondary
                    anchors.centerIn: parent
                }

                MouseArea {
                    objectName: "dockRailButton_" + entryItem.modelData.id
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.entryClicked(entryItem.modelData.id)
                }
            }
        }
    }
}
