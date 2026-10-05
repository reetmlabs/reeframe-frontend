// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Covers CameraTile's live/playback switch, driven by TimelineController.
// No real backend or media decoder is available in this sandbox, so these
// tests cover the state transitions and which VideoOutput is shown, not an
// actual decoded frame.
TestCase {
    id: testCase
    name: "CameraTilePlayback"
    width: 400
    height: 300
    visible: true
    when: windowShown

    CameraTile {
        id: tile
        objectName: "tileUnderTest"
        anchors.fill: parent
        cameraId: "qmltest-tile-playback-cam"
        cameraName: "Test Camera"
    }

    function cleanup() {
        TimelineController.goLive()
    }

    function test_liveByDefaultShowsLiveVideoOutput() {
        const liveOutput = findChild(tile, "cameraTileLiveVideoOutput")
        const playbackOutput = findChild(tile, "cameraTilePlaybackVideoOutput")
        verify(liveOutput !== null && playbackOutput !== null, "video outputs not found")

        compare(liveOutput.visible, true)
        compare(playbackOutput.visible, false)
    }

    function test_seekingSwitchesToPlaybackAndResolves() {
        TimelineController.seekTo("2026-07-23T10:00:00.000Z")

        const liveOutput = findChild(tile, "cameraTileLiveVideoOutput")
        const playbackOutput = findChild(tile, "cameraTilePlaybackVideoOutput")
        compare(liveOutput.visible, false)
        compare(playbackOutput.visible, true)
        compare(tile.playbackState, "resolving")
    }

    function test_goingLiveSwitchesBackToLiveVideoOutput() {
        TimelineController.seekTo("2026-07-23T10:00:00.000Z")
        TimelineController.goLive()

        const liveOutput = findChild(tile, "cameraTileLiveVideoOutput")
        const playbackOutput = findChild(tile, "cameraTilePlaybackVideoOutput")
        compare(liveOutput.visible, true)
        compare(playbackOutput.visible, false)
    }

    function test_recordingModelResponseIsFilteredByCameraId() {
        TimelineController.seekTo("2026-07-23T10:00:00.000Z")
        compare(tile.playbackState, "resolving")

        // A response for a different camera must not affect this tile.
        RecordingModel.playbackResolved("some-other-camera", "rec-1", "http://example/stream",
                                        0, "2026-07-23T10:00:00.000Z")
        compare(tile.playbackState, "resolving")

        RecordingModel.playbackGap("qmltest-tile-playback-cam", "2026-07-23T09:00:00Z",
                                   "2026-07-23T11:00:00Z", "2026-07-23T10:00:00.000Z")
        compare(tile.playbackState, "gap")
    }

    function test_staleResponseForASupersededSeekIsIgnored() {
        // Mirrors a double-click / rapid slider drag: two seeks fire before
        // either request's response comes back.
        TimelineController.seekTo("2026-07-23T10:00:00.000Z")
        TimelineController.seekTo("2026-07-23T11:00:00.000Z")
        compare(tile.playbackState, "resolving")

        // The first (now-superseded) request's response arrives late and
        // must not stomp the tile with an error.
        RecordingModel.playbackFailed("qmltest-tile-playback-cam", "boom",
                                      "2026-07-23T10:00:00.000Z")
        compare(tile.playbackState, "resolving")

        RecordingModel.playbackResolved("qmltest-tile-playback-cam", "rec-1",
                                        "http://example/stream", 0, "2026-07-23T11:00:00.000Z")
        compare(tile.playbackState, "ready")
    }

    function test_tileStaysLiveWhenScopedToADifferentCamera() {
        TimelineController.seekTo("2026-07-23T10:00:00.000Z", "some-other-camera");

        compare(tile.playbackState, "idle");
        const liveOutput = findChild(tile, "cameraTileLiveVideoOutput")
        const playbackOutput = findChild(tile, "cameraTilePlaybackVideoOutput")
        compare(liveOutput.visible, true)
        compare(playbackOutput.visible, false)
    }

    function test_tileEntersPlaybackWhenScopeMatchesItsOwnCamera() {
        TimelineController.seekTo("2026-07-23T10:00:00.000Z", "qmltest-tile-playback-cam");
        compare(tile.playbackState, "resolving")
    }

    function test_tileDropsBackToLiveWhenScopeNarrowsAwayMidPlayback() {
        // Matrix-wide playback (no scope) puts every tile into playback...
        TimelineController.seekTo("2026-07-23T10:00:00.000Z");
        compare(tile.playbackState, "resolving")

        // ...then scoping to a different camera (e.g. maximizing it from a
        // daily-summary row) must send this tile straight back to live.
        TimelineController.seekTo("2026-07-23T11:00:00.000Z", "some-other-camera");
        const liveOutput = findChild(tile, "cameraTileLiveVideoOutput")
        compare(liveOutput.visible, true)
    }
}
