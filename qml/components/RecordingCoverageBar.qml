// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

// Horizontal bar for one calendar day: x-axis spans local 00:00-24:00,
// filled where recorded, empty for real gaps. Pixel-accurate, not bucketed.
Item {
    id: root

    // "yyyy-MM-dd" (local), needed to compute each session's offset from
    // this day's own midnight.
    required property string date

    // [{startTime, endTime}, ...] for this day; endTime is "" for a
    // still-open session.
    //
    // The backend buckets by UTC day but this bar renders local
    // midnight-to-midnight, so a session near UTC midnight may clamp to this
    // bar's edge. Cosmetic only.
    required property var sessions

    implicitHeight: 6

    readonly property double dayStartMs: new Date(date + "T00:00:00").getTime()
    readonly property double dayEndMs: dayStartMs + 24 * 60 * 60 * 1000

    // Clamps into this day's span before converting to a fraction. Handles
    // midnight-straddling sessions and in-progress ones with no endTime yet.
    function fractionOf(iso, fallbackMs) {
        const ms = iso ? new Date(iso).getTime() : fallbackMs
        return Math.max(0, Math.min(1, (ms - dayStartMs) / (dayEndMs - dayStartMs)))
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.border
        clip: true

        Repeater {
            model: root.sessions
            delegate: Rectangle {
                required property var modelData
                readonly property double startFrac: root.fractionOf(modelData.startTime, root.dayStartMs)
                // A still-open session's fill runs to "now" (clamped to
                // day's end) instead of collapsing to zero width.
                readonly property double endFrac: root.fractionOf(modelData.endTime, Date.now())

                x: startFrac * track.width
                width: Math.max(1, (endFrac - startFrac) * track.width)
                height: track.height
                color: Theme.success
            }
        }
    }
}
