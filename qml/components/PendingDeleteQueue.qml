// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

// Backs the "Undo" toast pattern: scheduling an id delays the real delete
// call until a grace period elapses, so cancel() before then means the
// delete never happened at all.
//
// Each pending id gets its own dynamically-created Timer so multiple
// deletes can be in their grace period concurrently.
Item {
    id: root
    visible: false

    // Bump on every schedule()/cancel() so a `visible: !q.isPending(id)`
    // row binding actually re-evaluates. isPending() itself is a plain
    // function call, and mutating the `_pending` map in place doesn't
    // emit any change notification a binding could depend on otherwise.
    property int version: 0

    property var _pending: ({})

    function schedule(id, delayMs, onCommit) {
        cancel(id)
        const timer = Qt.createQmlObject(
            "import QtQuick; Timer { running: true; repeat: false }",
            root, "PendingDeleteTimer")
        timer.interval = delayMs
        timer.triggered.connect(function() {
            delete root._pending[id]
            timer.destroy()
            root.version++
            onCommit()
        })
        root._pending[id] = timer
        root.version++
    }

    // Cancels a still-pending action (the "Undo" path). Returns false if
    // it already committed or was never scheduled.
    function cancel(id) {
        const timer = root._pending[id]
        if (!timer)
            return false
        delete root._pending[id]
        timer.stop()
        timer.destroy()
        root.version++
        return true
    }

    function isPending(id) {
        return root._pending[id] !== undefined
    }
}
