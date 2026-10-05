// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Regression coverage: MatrixView sits outside the overlay StackView, so a
// tile's expand button must route through a requestFullScreen signal rather
// than resolving StackView.view directly (which is null there), and a full-
// screen tile's close button must actually be wired up rather than covered
// by a dead placeholder.
TestCase {
    id: testCase
    name: "MatrixViewFullScreen"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    App {
        id: appUnderTest
        anchors.fill: parent
    }

    function initTestCase() {
        // Unique per run: the test app.db is a real SQLite file that persists
        // across invocations (see TestSetup.cpp). A fixed site id here would
        // accumulate one leftover tile per past run, eventually pushing the
        // tile this test targets off whatever a fresh findChild() locates.
        TileLayoutModel.activeSiteId = "qmltest-site-" + Date.now();
        // Camera must exist in CameraModel (not just TileLayoutModel's own
        // binding table) for CameraTile.cameraId to resolve to a non-empty
        // value, which is required for the VideoSinkRegistry registration this
        // suite exercises below to actually happen.
        CameraModel.insertTestCamera("qmltest-camera-1", "Test Camera");
        const tileId = TileLayoutModel.addTile();
        TileLayoutModel.assignCamera(tileId, "qmltest-camera-1");
    }

    function test_expandButtonOpensFullScreen() {
        const stack = findChild(appUnderTest, "overlayStack");
        verify(stack !== null, "overlay StackView not found");
        stack.clear(); // reset regardless of what other test_* functions left behind
        compare(stack.depth, 0);

        const expandButton = findChild(appUnderTest, "expandButton");
        verify(expandButton !== null, "expand button not found on camera tile");

        mouseClick(expandButton, expandButton.width / 2, expandButton.height / 2);

        tryCompare(stack, "depth", 1);
        verify(stack.currentItem !== null, "no view was pushed onto the stack");
        verify(String(stack.currentItem).indexOf("FullCameraView") !== -1,
               "expected FullCameraView on the stack, got: " + stack.currentItem);

        // Full-screen must borrow the tile's already-registered sink rather
        // than opening a second, independent connection to the same camera.
        verify(stack.currentItem.borrowedSink !== null,
               "expected FullCameraView to borrow the tile's registered sink, " +
               "not fall back to opening its own connection");
    }

    function test_minimizeButtonReturnsToMatrix() {
        const stack = findChild(appUnderTest, "overlayStack");
        verify(stack !== null, "overlay StackView not found");
        stack.clear(); // reset regardless of what other test_* functions left behind

        const expandButton = findChild(appUnderTest, "expandButton");
        verify(expandButton !== null, "expand button not found on camera tile");
        mouseClick(expandButton, expandButton.width / 2, expandButton.height / 2);
        tryCompare(stack, "depth", 1);

        const minimizeButton = findChild(appUnderTest, "minimizeButton");
        verify(minimizeButton !== null, "minimize button not found on full-screen view");
        mouseClick(minimizeButton, minimizeButton.width / 2, minimizeButton.height / 2);

        tryCompare(stack, "depth", 0);
    }

    function test_minimizeAlwaysForcesPlaybackBackToLive() {
        const stack = findChild(appUnderTest, "overlayStack");
        verify(stack !== null, "overlay StackView not found");
        stack.clear();

        const expandButton = findChild(appUnderTest, "expandButton");
        verify(expandButton !== null, "expand button not found on camera tile");
        mouseClick(expandButton, expandButton.width / 2, expandButton.height / 2);
        tryCompare(stack, "depth", 1);

        // A maximized day-playback session is self-contained: minimizing
        // must unconditionally return to live, regardless of prior state.
        TimelineController.seekTo("2026-07-23T10:00:00.000Z", "qmltest-camera-1");
        compare(TimelineController.isLive, false);

        const minimizeButton = findChild(appUnderTest, "minimizeButton");
        verify(minimizeButton !== null, "minimize button not found on full-screen view");
        mouseClick(minimizeButton, minimizeButton.width / 2, minimizeButton.height / 2);

        compare(TimelineController.isLive, true);
        compare(TimelineController.scopeCameraId, "");
    }

    function test_recordingsPanelDayRowDoubleClickMaximizesThatCamera() {
        const stack = findChild(appUnderTest, "overlayStack");
        verify(stack !== null, "overlay StackView not found");
        stack.clear();
        TimelineController.goLive();

        const recordingsPanel = findChild(appUnderTest, "recordingsPanel");
        verify(recordingsPanel !== null, "recordings panel not found");
        const cameraPanel = findChild(appUnderTest, "cameraPanel");
        verify(cameraPanel !== null, "camera panel not found");
        cameraPanel.selectCamera("qmltest-camera-1", "Test Camera");

        recordingsPanel.dailySummaries = [{
            date: "2026-07-23",
            sessions: [{ startTime: "2026-07-23T08:00:00Z", endTime: "2026-07-23T08:10:00Z",
                         sizeBytes: 1000, chunkCount: 1 }],
            totalCoverageSecs: 600,
            firstSessionStart: "2026-07-23T08:00:00Z"
        }];

        const row = findChild(recordingsPanel, "recordingsPanelDayRow_0");
        verify(row !== null, "day row not found");
        // See tst_RecordingsPanelDayList.qml's own note: Qt's synthetic
        // double-click detection isn't reliable under the offscreen test
        // platform, so this calls the same function the real gesture calls.
        row.activateDayPlayback();

        tryCompare(stack, "depth", 1);
        verify(stack.currentItem !== null, "no view was pushed onto the stack");
        verify(String(stack.currentItem).indexOf("FullCameraView") !== -1,
               "expected FullCameraView on the stack, got: " + stack.currentItem);
        compare(stack.currentItem.cameraId, "qmltest-camera-1");
    }
}
