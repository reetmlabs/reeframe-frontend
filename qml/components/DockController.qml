// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

// Tracks which dockable side panels are open, their front-to-back stacking
// order, and whether the frontmost two are split (each getting half the
// available height) or stacked as full-height overlays (only the front one
// visible). Panel identity is a plain string id; this file has no
// knowledge of what a "cameras" or "recordings" panel actually is.
Item {
    id: root
    visible: false

    // Open panels, back-to-front. The last entry is the front (topmost)
    // panel, the one shown in full when panels overlap.
    property var order: []

    // When true, the open panels split the available height evenly instead
    // of overlapping with only the front one visible. Only meaningful once
    // two or more panels are open, and it's forced back to false whenever the
    // count drops below that.
    property bool splitMode: false

    readonly property int count: root.order.length

    function isOpen(id) {
        return root.order.indexOf(id) !== -1
    }

    function isFront(id) {
        return root.order.length > 0 && root.order[root.order.length - 1] === id
    }

    function indexOf(id) {
        return root.order.indexOf(id)
    }

    // Adds or removes a panel from the open set. Newly-opened panels become
    // the front panel. No-op if the panel's open state already matches.
    function setOpen(id, open) {
        const idx = root.order.indexOf(id)
        if (open && idx === -1) {
            root.order = root.order.concat([id])
        } else if (!open && idx !== -1) {
            const copy = root.order.slice()
            copy.splice(idx, 1)
            root.order = copy
        }
        if (root.order.length < 2)
            root.splitMode = false
    }

    // Moves an already-open panel to the front without changing which
    // panels are open.
    function bringToFront(id) {
        const idx = root.order.indexOf(id)
        if (idx === -1 || idx === root.order.length - 1)
            return
        const copy = root.order.slice()
        copy.splice(idx, 1)
        copy.push(id)
        root.order = copy
    }

    function togglePin() {
        if (root.order.length >= 2)
            root.splitMode = !root.splitMode
    }
}
