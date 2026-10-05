// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Window

Rectangle {
    id: root

    property bool sidebarCollapsed: false
    signal sidebarToggleClicked()
    signal signInRequested()

    height: 44
    color: Theme.surfaceAlt

    /* ----- Bottom border ----- */
    Rectangle {
        height: 1
        color: Theme.border
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    }

    /* ----- Drag to move + double-click to maximise ----- */
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton
        onPressed: root.Window.window.startSystemMove()
        onDoubleClicked: {
            const win = root.Window.window
            win.visibility === Window.Maximized ? win.showNormal() : win.showMaximized()
        }
    }

    /* ----- App name ----- */
    Row {
        spacing: Theme.spaceS
        anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }

        Image {
            source: Theme.isDark ? "qrc:/icons/reframe-icon-dark-32.png"
                                 : "qrc:/icons/reframe-icon-32.png"
            width: 24
            height: 24
            fillMode: Image.PreserveAspectFit
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "Reeframe VMS"
            font.pixelSize: Theme.fontM
            font.weight: Font.Medium
            color: Theme.textPrimary
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            width: 1
            height: 16
            color: Theme.border
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            id: sidebarToggleBtn
            width: 28
            height: 28
            radius: Theme.radiusS
            color: sidebarToggleMouse.containsMouse ? Theme.surfaceHover : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            TblIcon {
                anchors.centerIn: parent
                source: root.sidebarCollapsed ? "qrc:/tb/layout-sidebar-left-expand.svg"
                                              : "qrc:/tb/layout-sidebar-left-collapse.svg"
                color: Theme.textSecondary
                size: 18
            }

            MouseArea {
                id: sidebarToggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sidebarToggleClicked()
            }

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }
    }

    /* ----- Centre: site selector ----- */
    Row {
        anchors.centerIn: parent
        spacing: Theme.spaceM

        Text {
            visible: SiteManager.count === 0
            text: qsTr("No site connected")
            font.pixelSize: Theme.fontS
            color: Theme.textSecondary
            anchors.verticalCenter: parent.verticalCenter
        }

        ComboBox {
            id: siteSelector
            visible: SiteManager.count > 0
            model: SiteManager
            textRole: "siteName"
            width: 200
            height: 30
            currentIndex: SiteManager.activeSiteIndex
            anchors.verticalCenter: parent.verticalCenter

            onActivated: SiteManager.activeSiteIndex = currentIndex

            background: Rectangle {
                color: siteSelector.pressed ? Theme.surfaceHover : "transparent"
                border.color: Theme.border
                radius: Theme.radiusS
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            contentItem: Row {
                leftPadding: Theme.spaceM
                spacing: Theme.spaceS

                StatusDot {
                    status: SiteManager.activeSiteStatus
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: siteSelector.displayText
                    font.pixelSize: Theme.fontS
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            indicator: Text {
                x: siteSelector.width - width - Theme.spaceM
                text: "▾"
                font.pixelSize: Theme.fontXs
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }

            delegate: ItemDelegate {
                id: siteItem
                required property int index
                required property string siteName
                required property int siteWorstStatus
                width: siteSelector.popup.width
                height: 36
                highlighted: siteSelector.highlightedIndex === siteItem.index
                padding: 0

                contentItem: Row {
                    leftPadding: Theme.spaceM
                    spacing: Theme.spaceS

                    StatusDot {
                        status: siteItem.siteWorstStatus
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: siteItem.siteName
                        font.pixelSize: Theme.fontS
                        color: Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                background: Rectangle {
                    color: siteItem.highlighted ? Theme.surfaceHover : "transparent"
                }
            }

            popup: Popup {
                y: siteSelector.height + 2
                width: siteSelector.width
                padding: Theme.spaceXs
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                background: Rectangle {
                    color: Theme.surfaceCard
                    border.color: Theme.border
                    radius: Theme.radiusS
                }

                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: siteSelector.delegateModel
                    currentIndex: siteSelector.highlightedIndex
                }
            }
        }

        Text {
            visible: SiteManager.count > 0 && SiteManager.activeSiteStatus === 2
                     && SiteManager.activeSiteVersion.length > 0
            text: SiteManager.activeSiteVersion
            font.pixelSize: Theme.fontXs
            color: Theme.textDisabled
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    /* ----- Right zone: avatar + window controls ----- */
    Row {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }

        /* User avatar chip + sign-in popover */
        Item {
            id: avatarChip
            width: 28 + Theme.spaceL * 2
            height: parent.height

            readonly property var activeClient: SiteManager.activeSiteId.length > 0
                ? SiteManager.clientForSite(SiteManager.activeSiteId) : null
            readonly property bool hasSession: avatarChip.activeClient !== null
                && avatarChip.activeClient.hasSession

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: Theme.accent
                anchors.centerIn: parent

                Text {
                    anchors.centerIn: parent
                    text: avatarChip.hasSession
                        ? avatarChip.activeClient.username.charAt(0).toUpperCase() : "?"
                    font.pixelSize: Theme.fontS
                    font.weight: Font.Medium
                    color: Theme.textOnAccent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: profilePopup.visible ? profilePopup.close() : profilePopup.open()
                }
            }

            Popup {
                id: profilePopup
                objectName: "profilePopup"
                y: parent.height
                x: parent.width - width
                width: 220
                padding: Theme.spaceM
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                background: Rectangle {
                    color: Theme.surfaceCard
                    border.color: Theme.border
                    radius: Theme.radiusS
                }

                contentItem: Column {
                    spacing: Theme.spaceS

                    Text {
                        objectName: "profileUsernameText"
                        text: avatarChip.hasSession ? avatarChip.activeClient.username : qsTr("Not signed in")
                        font.pixelSize: Theme.fontS
                        font.weight: Font.Medium
                        color: Theme.textPrimary
                        width: parent.width
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: avatarChip.hasSession && avatarChip.activeClient.role.length > 0
                        text: avatarChip.hasSession ? avatarChip.activeClient.role : ""
                        font.pixelSize: Theme.fontXs
                        color: Theme.textSecondary
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.border }

                    Text {
                        text: SiteManager.activeSiteName.length > 0
                            ? SiteManager.activeSiteName : qsTr("No active site")
                        font.pixelSize: Theme.fontXs
                        color: Theme.textDisabled
                        width: parent.width
                        elide: Text.ElideRight
                    }

                    HoverButton {
                        objectName: "profileSignInButton"
                        width: parent.width
                        // Coordinator mode only: brings back the Coordinator dialog after
                        // cancelling it once. Keyed off CoordinatorManager
                        // directly rather than the active site, since signing
                        // out prunes the site away and would leave
                        // activeSiteCoordinatorUrl empty right when it's needed.
                        visible: CoordinatorManager.hasUnsignedConnection
                        variant: "primary"
                        text: qsTr("Sign in")
                        onClicked: {
                            root.signInRequested()
                            profilePopup.close()
                        }
                    }

                    HoverButton {
                        objectName: "profileSignOutButton"
                        width: parent.width
                        visible: avatarChip.hasSession
                        variant: "destructive"
                        text: qsTr("Sign out")
                        onClicked: {
                            // Coordinator mode: the per-BE client only holds a derived
                            // Coordinator token, so sign out of the Coordinator
                            // instead; SiteManager reacts and rebuilds this
                            // site's client with no session.
                            if (SiteManager.activeSiteCoordinatorUrl.length > 0)
                                CoordinatorManager.logout(SiteManager.activeSiteCoordinatorUrl)
                            else
                                avatarChip.activeClient.logout()
                            profilePopup.close()
                        }
                    }
                }
            }
        }

        Rectangle {
            width: 46
            height: parent.height
            color: minMouse.containsMouse ? Theme.surfaceHover : "transparent"

            TblIcon {
                anchors.centerIn: parent
                source: "qrc:/tb/minus.svg"
                color: Theme.textSecondary
                size: 18
            }

            MouseArea {
                id: minMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.Window.window.showMinimized()
            }

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        Rectangle {
            width: 46
            height: parent.height
            color: maxMouse.containsMouse ? Theme.surfaceHover : "transparent"

            TblIcon {
                anchors.centerIn: parent
                source: root.Window.window && root.Window.window.visibility === Window.Maximized
                        ? "qrc:/tb/arrows-minimize.svg" : "qrc:/tb/arrows-maximize.svg"
                color: Theme.textSecondary
                size: 18
            }

            MouseArea {
                id: maxMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const win = root.Window.window
                    win.visibility === Window.Maximized ? win.showNormal() : win.showMaximized()
                }
            }

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        Rectangle {
            width: 46
            height: parent.height
            color: closeMouse.containsMouse ? Theme.error : "transparent"

            TblIcon {
                anchors.centerIn: parent
                source: "qrc:/tb/x.svg"
                color: closeMouse.containsMouse ? Theme.textOnAccent : Theme.textSecondary
                size: 18
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.Window.window.close()
            }

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }
    }
}
