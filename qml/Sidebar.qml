// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: root

    color: Theme.surfaceAlt

    signal navigateTo(url viewUrl)

    property int  currentIndex: 0
    property bool collapsed:    false

    width: collapsed ? Theme.sidebarCollapsedWidth : Theme.sidebarWidth

    Behavior on width {
        NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic }
    }

    /* ----- Right border ----- */
    Rectangle {
        width: 1
        color: Theme.border
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
    }

    /* ----- Primary nav ----- */
    Column {
        anchors { top: parent.top; left: parent.left; right: parent.right }

        NavItem {
            icon: "qrc:/tb/layout-grid.svg"; iconFill: "qrc:/tb/layout-grid-filled.svg"
            label: qsTr("Matrix")
            collapsed: root.collapsed
            active: root.currentIndex === 0
            onClicked: { root.currentIndex = 0; root.navigateTo(Qt.resolvedUrl("views/MatrixView.qml")) }
        }

        NavItem {
            icon: "qrc:/tb/git-merge.svg"
            label: qsTr("Pipelines")
            collapsed: root.collapsed
            active: root.currentIndex >= 1 && root.currentIndex <= 3
            onClicked: { root.currentIndex = 1; root.navigateTo(Qt.resolvedUrl("views/PipelineListView.qml")) }

            NavItem {
                label: qsTr("Pipelines")
                active: root.currentIndex === 1
                onClicked: { root.currentIndex = 1; root.navigateTo(Qt.resolvedUrl("views/PipelineListView.qml")) }
            }
            NavItem {
                label: qsTr("Sources")
                active: root.currentIndex === 2
                onClicked: { root.currentIndex = 2; root.navigateTo(Qt.resolvedUrl("views/SourceListView.qml")) }
            }
            NavItem {
                label: qsTr("Destinations")
                active: root.currentIndex === 3
                onClicked: { root.currentIndex = 3; root.navigateTo(Qt.resolvedUrl("views/DestinationListView.qml")) }
            }
        }

        NavItem {
            icon: "qrc:/tb/world.svg"
            label: qsTr("Sites")
            collapsed: root.collapsed
            active: root.currentIndex === 4
            onClicked: { root.currentIndex = 4; root.navigateTo(Qt.resolvedUrl("views/SiteManagerView.qml")) }
        }

        NavItem {
            icon: "qrc:/tb/broadcast.svg"
            label: qsTr("Coordinators")
            collapsed: root.collapsed
            active: root.currentIndex === 6
            onClicked: { root.currentIndex = 6; root.navigateTo(Qt.resolvedUrl("views/CoordinatorManagerView.qml")) }
        }
    }

    /* ----- Divider ----- */
    Rectangle {
        id: divider
        height: 1
        color: Theme.border
        anchors { left: parent.left; right: parent.right; bottom: settingsItem.top }
    }

    /* ----- Settings (pinned bottom) ----- */
    NavItem {
        id: settingsItem
        icon: "qrc:/tb/settings.svg"; iconFill: "qrc:/tb/settings-filled.svg"
        label: qsTr("Settings")
        collapsed: root.collapsed
        active: root.currentIndex === 5
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: Theme.spaceS }
        onClicked: { root.currentIndex = 5; root.navigateTo(Qt.resolvedUrl("views/SettingsView.qml")) }
    }
}
