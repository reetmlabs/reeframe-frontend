// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

Item {
    Rectangle {
        anchors.fill: parent
        color: Theme.surfaceCard

        Text {
            anchors.centerIn: parent
            text: qsTr("Stats")
            font.pixelSize: Theme.fontS
            color: Theme.textDisabled
        }
    }
}
