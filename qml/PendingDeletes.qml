// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

pragma Singleton
import QtQuick

// App-wide version of PendingDeleteQueue.qml's delayed-dispatch "Undo"
// pattern. App.qml's StackView destroys a page on navigation (replace() or
// pop()), which would destroy a page-local PendingDeleteQueue/Toast (and
// the pending Timer inside it) before the deferred delete call ever fires.
// Only a component that is never destroyed by that navigation (CameraPanel,
// a persistent dock item) can safely use the local PendingDeleteQueue instead.
QtObject {
    id: root

    // Bump on every schedule()/cancel() so a `visible: !isPending(id)` row
    // binding re-evaluates. Mutating the maps below in place emits no
    // change notification on its own.
    property int version: 0

    property var _pending: ({})    // id -> Timer, while the undo window is open
    property var _requested: ({})  // id -> true, from request until undone

    // Consumed by a global Toast (declared in App.qml, which survives any
    // view's navigation) to actually show the "Undo" action.
    signal toastRequested(string message, var ids, int durationMs)

    function schedule(id, delayMs, onCommit) {
        root._requested[id] = true
        _cancelTimer(id)
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

    function _cancelTimer(id) {
        const timer = root._pending[id]
        if (!timer)
            return false
        delete root._pending[id]
        timer.stop()
        timer.destroy()
        return true
    }

    // Cancels a still-pending delete (the "Undo" path); returns false if it
    // already committed or was never scheduled. Clears the "requested" flag
    // before bumping version, since QML property change notifications
    // propagate synchronously and a row binding on version re-evaluates
    // during this call, not after it returns.
    function cancel(id) {
        if (!root._pending[id])
            return false
        delete root._requested[id]
        _cancelTimer(id)
        root.version++
        return true
    }

    function isPending(id) {
        return root._pending[id] !== undefined || root._requested[id] === true
    }

    // Un-hides an id whose deferred commit call (see schedule() above) came
    // back as a failure. Otherwise _requested[id] stays true forever (only
    // cancel()/Undo clears it), hiding a row that was never actually deleted.
    function clearFailed(id) {
        delete root._requested[id]
        root.version++
    }

    function notify(message, ids, durationMs) {
        root.toastRequested(message, ids, durationMs)
    }
}
