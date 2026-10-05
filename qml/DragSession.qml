// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

pragma Singleton
import QtQuick

// Shared state for the camera-row-to-matrix-tile drag.
//
// The dragged camera row lives inside CameraPanel's clipped ListView and
// never itself crosses into MatrixView's part of the tree, so it cannot be
// the item DropArea.containsDrag checks against. That check is a geometry
// overlap test against whatever item currently carries Drag.active, and an
// item that never moves can never overlap a DropArea somewhere else on
// screen. DragSession is observed by a small ghost Item declared at the
// App.qml root (so its coordinate space spans the whole window) that tracks
// the live cursor position and actually carries the Drag attached
// properties DropArea checks against.
QtObject {
    property bool active: false
    property string cameraId: ""
    property string cameraName: ""
    property real globalX: 0
    property real globalY: 0
}
