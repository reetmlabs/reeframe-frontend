// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

TextField {
    id: root

    placeholderText: qsTr("Search…")
    height: 34
    leftPadding: Theme.spaceXl
    rightPadding: clearBtn.visible ? Theme.spaceXl : Theme.spaceM
    color: Theme.textPrimary
    placeholderTextColor: Theme.textDisabled
    font.pixelSize: Theme.fontS
    selectionColor: Theme.accent

    background: Rectangle {
        color: Theme.surface
        border.color: root.activeFocus ? Theme.accent : Theme.border
        radius: Theme.radiusS
        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    }

    TblIcon {
        source: "qrc:/tb/search.svg"
        color: Theme.textDisabled
        size: 16
        anchors { left: parent.left; leftMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }
    }

    Rectangle {
        id: clearBtn
        visible: root.text.length > 0
        width: 18
        height: 18
        radius: 9
        color: clearMouse.containsMouse ? Theme.surfaceHover : "transparent"
        anchors { right: parent.right; rightMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }

        TblIcon {
            anchors.centerIn: parent
            source: "qrc:/tb/x.svg"
            color: Theme.textSecondary
            size: 14
        }

        MouseArea {
            id: clearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clear()
        }
    }
}
