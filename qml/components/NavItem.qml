// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

// Recursive nav entry: declared children become sub-items via the default
// property alias. depth is set by the parent; don't set it manually.
Item {
    id: root

    property string icon: ""
    property string iconFill: ""
    property string label: ""
    property bool active: false
    property bool collapsed: false
    property int depth: 0

    signal clicked()

    default property alias subItems: subColumn.children

    readonly property bool hasSubItems: subColumn.children.length > 0
    property bool expanded: false

    width: parent ? parent.width : 0
    height: header.height + subColumn.height

    // Propagate collapsed and depth to every direct sub-item.
    function syncChildren() {
        for (let i = 0; i < subColumn.children.length; i++) {
            const c = subColumn.children[i]
            if ("collapsed" in c)
                c.collapsed = Qt.binding(() => root.collapsed)
            if ("depth" in c)
                c.depth = root.depth + 1
        }
    }

    Component.onCompleted: syncChildren()
    Connections {
        target: subColumn
        function onChildrenChanged() { root.syncChildren() }
    }

    // Shared by mouse click, Space/Enter, and Accessible press so all three behave identically.
    function activate() {
        if (root.hasSubItems && !root.collapsed)
            root.expanded = !root.expanded
        else
            root.clicked()
    }

    Rectangle {
        id: header
        objectName: "navItemHeader"
        width: parent.width
        height: 40
        color: root.active ? Theme.accent : (mouse.containsMouse ? Theme.surfaceHover : "transparent")
        anchors.top: parent.top

        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: root.label
        Accessible.focusable: true
        Accessible.onPressAction: root.activate()

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activate()
                event.accepted = true
            }
        }

        Rectangle {
            visible: root.active
            width: root.depth === 0 ? 3 : 2
            color: root.depth === 0 ? Theme.highlight : Theme.accent
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        }

        Item {
            id: iconSlot
            width: Theme.spaceXl
            height: parent.height
            visible: root.depth === 0
            x: root.collapsed ? (parent.width - width) / 2
                              : Theme.spaceM

            Behavior on x {
                NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic }
            }

            TblIcon {
                anchors.centerIn: parent
                size: 20
                source: (root.active && root.iconFill.length > 0) ? root.iconFill : root.icon
                color: root.active ? Theme.textOnAccent : Theme.textPrimary
                visible: root.icon.length > 0
            }
        }

        Text {
            text: root.label
            font.pixelSize: root.depth === 0 ? Theme.fontM : Theme.fontS
            color: root.active ? Theme.textOnAccent
                               : (root.depth > 0 ? Theme.textSecondary : Theme.textPrimary)
            opacity: root.collapsed ? 0 : 1
            elide: Text.ElideRight
            anchors {
                left: iconSlot.visible ? iconSlot.right : parent.left
                leftMargin: iconSlot.visible ? Theme.spaceS
                                             : Theme.spaceM + (root.depth) * Theme.spaceXl
                right: chevron.visible ? chevron.left : parent.right
                rightMargin: Theme.spaceS
                verticalCenter: parent.verticalCenter
            }
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        }

        TblIcon {
            id: chevron
            visible: root.hasSubItems && !root.collapsed
            source: root.expanded ? "qrc:/tb/chevron-down.svg" : "qrc:/tb/chevron-right.svg"
            color: root.active ? Theme.textOnAccent : Theme.textSecondary
            size: 14
            anchors { right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
        }

        ToolTip {
            visible: root.collapsed && mouse.containsMouse
            text: root.label
            delay: 400
            timeout: 3000
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activate()
        }

        // Inset focus ring, unlike HoverButton/Checkbox's outset rings: nav
        // rows are edge-to-edge, so an outer ring would overlap the next row.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            color: "transparent"
            border.width: 2
            border.color: Theme.focusRing
            visible: header.activeFocus
        }

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    Column {
        id: subColumn
        width: parent.width
        anchors.top: header.bottom
        height: (root.expanded && !root.collapsed) ? implicitHeight : 0
        clip: true

        Behavior on height {
            NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic }
        }
    }
}
