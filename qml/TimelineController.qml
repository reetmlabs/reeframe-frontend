// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

pragma Singleton
import QtQuick

// Shared "what point in time is the whole app looking at" state. MatrixView
// and FullCameraView read this to decide between live feed and recording;
// TimelineBar is the one control that changes it.
QtObject {
    id: root

    property bool isLive: true
    // RFC 3339 instant, only meaningful while !isLive.
    property string currentInstant: ""
    // Only meaningful while !isLive; live view has no separate
    // play/pause concept.
    property bool isPlaying: true

    // "" means every camera enters playback (matrix-wide scrubbing).
    // Non-empty restricts playback to just that camera (e.g. maximizing a
    // camera from its daily-summary row), so every other tile stays live
    // instead of following along.
    property string scopeCameraId: ""

    function seekTo(instant, cameraId) {
        root.scopeCameraId = cameraId || ""
        root.currentInstant = instant
        root.isLive = false
        root.isPlaying = true
    }

    function goLive() {
        root.isLive = true
        root.isPlaying = true
        root.currentInstant = ""
        root.scopeCameraId = ""
    }

    function togglePlayPause() {
        if (!root.isLive)
            root.isPlaying = !root.isPlaying
    }
}
