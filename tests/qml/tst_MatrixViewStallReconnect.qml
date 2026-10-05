// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// A tile whose live stream stalls must show "Connecting…" again, and a
// failed relay request must keep being retried with backoff for as long as
// the tile shows that camera.
TestCase {
    id: testCase
    name: "MatrixViewStallReconnect"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    MatrixView {
        id: matrixView
        anchors.fill: parent
    }

    property string cameraId: ""
    property string tileId: ""

    function initTestCase() {
        TileLayoutModel.activeSiteId = "qmltest-site-" + Date.now();
        cameraId = "qmltest-stall-cam-" + Date.now();
        CameraModel.insertTestCamera(cameraId, "Stall Camera");
        tileId = TileLayoutModel.addTile();
        TileLayoutModel.assignCamera(tileId, cameraId);
    }

    function tileParts() {
        const tileItem = findChild(matrixView, "matrixTile_" + tileId);
        verify(tileItem !== null, "matrix tile not found");
        const cameraTile = findChild(tileItem, "matrixTileCameraStream");
        verify(cameraTile !== null, "camera tile stream not found");
        const retryTimer = findChild(tileItem, "matrixTileRelayRetryTimer");
        verify(retryTimer !== null, "relay retry timer not found");
        const sink = findChild(cameraTile, "cameraTileLiveSink");
        verify(sink !== null, "live sink not found");
        return { cameraTile: cameraTile, retryTimer: retryTimer, sink: sink };
    }

    function test_stalledStreamShowsConnectingAgain() {
        const parts = tileParts();
        CameraModel.setRelayUrlForTest(cameraId, "rtsp://relay.test/stall", true);
        // Stands in for a stream that was playing and then froze.
        parts.cameraTile.connectionState = "connected";

        parts.sink.stalled();

        compare(parts.cameraTile.connectionState, "connecting",
                "a stalled stream must show Connecting instead of its frozen last frame");
    }

    function test_failedRelayRequestIsRetriedWithBackoff() {
        const parts = tileParts();

        CameraModel.relayStartFailed(cameraId, true);
        verify(parts.retryTimer.running, "a failed relay request must schedule a retry");
        compare(parts.retryTimer.interval, 2000);
        verify(parts.cameraTile.awaitingRelay,
               "the tile must keep showing Connecting while a retry is pending");

        CameraModel.relayStartFailed(cameraId, true);
        compare(parts.retryTimer.interval, 4000, "each further failure must back off");
        CameraModel.relayStartFailed(cameraId, true);
        CameraModel.relayStartFailed(cameraId, true);
        CameraModel.relayStartFailed(cameraId, true);
        compare(parts.retryTimer.interval, 10000, "the backoff must be capped at 10s");

        CameraModel.setRelayUrlForTest(cameraId, "rtsp://relay.test/back", true);
        verify(!parts.retryTimer.running, "a successful relay must cancel the pending retry");

        CameraModel.relayStartFailed(cameraId, true);
        compare(parts.retryTimer.interval, 2000, "a successful relay must reset the backoff");
        parts.retryTimer.stop();
    }
}
