// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

Item {
    id: root

    required property string textTL
    required property string textTC
    required property string textTR
    required property string textBL
    required property string textBC
    required property string textBR
    required property int    fontSize
    required property color  textColor
    required property real   bgOpacity

    readonly property bool hasTopRow: textTL.length > 0 || textTC.length > 0 || textTR.length > 0
    readonly property bool hasBottomRow: textBL.length > 0 || textBC.length > 0 || textBR.length > 0

    /* ----- Top strip: TL / TC / TR ----- */
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.fontSize + 16
        visible: root.hasTopRow
        color: Qt.rgba(0, 0, 0, root.bgOpacity)

        Text {
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            width: (parent.width - 16) / 3
            text: root.textTL
            visible: root.textTL.length > 0
            color: root.textColor
            font.pixelSize: root.fontSize
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            width: (parent.width - 16) / 3
            text: root.textTC
            visible: root.textTC.length > 0
            color: root.textColor
            font.pixelSize: root.fontSize
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            width: (parent.width - 16) / 3
            text: root.textTR
            visible: root.textTR.length > 0
            color: root.textColor
            font.pixelSize: root.fontSize
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    /* ----- Bottom strip: BL / BC / BR ----- */
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: root.fontSize + 16
        visible: root.hasBottomRow
        color: Qt.rgba(0, 0, 0, root.bgOpacity)

        Text {
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            width: (parent.width - 16) / 3
            text: root.textBL
            visible: root.textBL.length > 0
            color: root.textColor
            font.pixelSize: root.fontSize
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            width: (parent.width - 16) / 3
            text: root.textBC
            visible: root.textBC.length > 0
            color: root.textColor
            font.pixelSize: root.fontSize
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            width: (parent.width - 16) / 3
            text: root.textBR
            visible: root.textBR.length > 0
            color: root.textColor
            font.pixelSize: root.fontSize
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
