// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: root

    height: 24
    color:  Theme.surfaceAlt

    /* ----- Top border ----- */
    Rectangle {
        height: 1
        color:  Theme.border
        anchors { left: parent.left; right: parent.right; top: parent.top }
    }

    /* ----- FE stats (left) ----- */
    Row {
        spacing: Theme.spaceM
        anchors {
            left:           parent.left
            leftMargin:     Theme.spaceL
            verticalCenter: parent.verticalCenter
        }

        Text {
            text:           qsTr("FE CPU —")
            font.pixelSize: Theme.fontXs
            color:          Theme.textDisabled
        }
        Text {
            text:           qsTr("RAM —")
            font.pixelSize: Theme.fontXs
            color:          Theme.textDisabled
        }
        Text {
            text:           qsTr("GPU —")
            font.pixelSize: Theme.fontXs
            color:          Theme.textDisabled
        }
        Text {
            text:           qsTr("↓ — Mbps")
            font.pixelSize: Theme.fontXs
            color:          Theme.textDisabled
        }
    }

    /* ----- Node / stream count (right) ----- */
    Row {
        spacing: Theme.spaceM
        anchors {
            right:          parent.right
            rightMargin:    Theme.spaceL
            verticalCenter: parent.verticalCenter
        }

        Text {
            text:           qsTr("0 nodes")
            font.pixelSize: Theme.fontXs
            color:          Theme.textDisabled
        }
        Text {
            text:           qsTr("0 streams")
            font.pixelSize: Theme.fontXs
            color:          Theme.textDisabled
        }
    }
}
