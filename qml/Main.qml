// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

ApplicationWindow {
    id: root
    width: 1280
    height: 800
    minimumWidth: 800
    minimumHeight: 600
    visible: true
    color: Theme.surface
    flags: Qt.FramelessWindowHint | Qt.Window

    Component.onCompleted: {
        if (WindowPrefs.hasSavedGeometry) {
            root.x = WindowPrefs.x
            root.y = WindowPrefs.y
            root.width = WindowPrefs.width
            root.height = WindowPrefs.height
        }
        if (WindowPrefs.maximized)
            root.showMaximized()
    }

    // Tracks the last non-hidden visibility, since by the time
    // onVisibleChanged below fires, visibility has already moved to Hidden
    // and can no longer distinguish Windowed from Maximized.
    property bool _wasMaximized: false
    onVisibilityChanged: {
        if (root.visibility === Window.Maximized)
            root._wasMaximized = true
        else if (root.visibility === Window.Windowed)
            root._wasMaximized = false
    }

    function saveGeometry() {
        if (!root._wasMaximized) {
            WindowPrefs.x = root.x
            WindowPrefs.y = root.y
            WindowPrefs.width = root.width
            WindowPrefs.height = root.height
        }
        WindowPrefs.maximized = root._wasMaximized
    }

    // Saved only when the window is hidden or the app is about to quit, not
    // on every x/y/width/height change during a drag/resize (see the resize
    // handles below). TrayManager hides the window on close instead of
    // closing it, so onVisibleChanged is what actually catches a normal
    // titlebar-close click; aboutToQuit covers the tray menu's real quit path.
    onVisibleChanged: if (!root.visible) root.saveGeometry()

    Connections {
        target: Qt.application
        function onAboutToQuit() { root.saveGeometry() }
    }

    App {
        anchors.fill: parent
    }

    /* ----- Window edge border (frameless, so no native shadow) ----- */
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.18)
        border.width: 1
        z: 200
        visible: root.visibility !== Window.Maximized
    }

    /* ----- Resize handles ----- */
    Item {
        anchors.fill: parent
        z: 100
        visible: root.visibility !== Window.Maximized

        // Corners (declared before edges so they take priority in hit testing)
        MouseArea {
            width: 12; height: 12
            anchors { left: parent.left; top: parent.top }
            cursorShape: Qt.SizeFDiagCursor
            onPressed: root.startSystemResize(Qt.LeftEdge | Qt.TopEdge)
        }
        MouseArea {
            width: 12; height: 12
            anchors { right: parent.right; top: parent.top }
            cursorShape: Qt.SizeBDiagCursor
            onPressed: root.startSystemResize(Qt.RightEdge | Qt.TopEdge)
        }
        MouseArea {
            width: 12; height: 12
            anchors { left: parent.left; bottom: parent.bottom }
            cursorShape: Qt.SizeBDiagCursor
            onPressed: root.startSystemResize(Qt.LeftEdge | Qt.BottomEdge)
        }
        MouseArea {
            width: 12; height: 12
            anchors { right: parent.right; bottom: parent.bottom }
            cursorShape: Qt.SizeFDiagCursor
            onPressed: root.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
        }

        MouseArea {
            width: 6
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 12; bottomMargin: 12 }
            cursorShape: Qt.SizeHorCursor
            onPressed: root.startSystemResize(Qt.LeftEdge)
        }
        MouseArea {
            width: 6
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 12; bottomMargin: 12 }
            cursorShape: Qt.SizeHorCursor
            onPressed: root.startSystemResize(Qt.RightEdge)
        }
        MouseArea {
            height: 6
            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
            cursorShape: Qt.SizeVerCursor
            onPressed: root.startSystemResize(Qt.TopEdge)
        }
        MouseArea {
            height: 6
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
            cursorShape: Qt.SizeVerCursor
            onPressed: root.startSystemResize(Qt.BottomEdge)
        }
    }
}
