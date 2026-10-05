// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string source: ""
    property color  color:  Theme.textPrimary
    property int    size:   16

    width:  size
    height: size

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectFit
        visible: false
    }

    MultiEffect {
        source: img
        anchors.fill: img
        brightness: 1.0
        colorization: 1.0
        colorizationColor: root.color
    }
}
