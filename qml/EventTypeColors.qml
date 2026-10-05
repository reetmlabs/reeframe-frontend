// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

pragma Singleton
import QtQuick

// Colorblind-safe (Okabe-Ito) categorical palette for the timeline's event
// markers, keyed by the backend's event_type string. An unrecognized
// event_type still renders, using fallbackColor, rather than being dropped.
QtObject {
    readonly property color fallbackColor: "#9AA0A6"

    readonly property var _colors: ({
        "motion_started": "#56B4E9",
        "motion_stopped": "#0072B2",
        "scene_change": "#F0E442",
        "tamper_detected": "#D55E00",
        "tamper_cleared": "#009E73",
        "signal_lost": "#CC79A7",
        "signal_restored": "#E69F00"
    })

    function colorFor(eventType) {
        return _colors.hasOwnProperty(eventType) ? _colors[eventType] : fallbackColor
    }

    // Stable legend order for the known types. Anything else falls under a
    // single trailing "Other" bucket rendered with fallbackColor.
    readonly property var knownTypes: Object.keys(_colors)
}
