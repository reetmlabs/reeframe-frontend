// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// A tile whose live stream stalls must show "Connecting…" again, and a
// failed restream request must keep being retried with backoff for as long as
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
        const retryTimer = findChild(tileItem, "matrixTileRestreamRetryTimer");
        verify(retryTimer !== null, "restream retry timer not found");
        const sink = findChild(cameraTile, "cameraTileLiveSink");
        verify(sink !== null, "live sink not found");
        return { cameraTile: cameraTile, retryTimer: retryTimer, sink: sink };
    }

    function test_stalledStreamShowsConnectingAgain() {
        const parts = tileParts();
        CameraModel.setRestreamUrlForTest(cameraId, "rtsp://restream.test/stall", true);
        // Stands in for a stream that was playing and then froze.
        parts.cameraTile.connectionState = "connected";

        parts.sink.stalled();

        compare(parts.cameraTile.connectionState, "connecting",
                "a stalled stream must show Connecting instead of its frozen last frame");
    }

    function test_failedRestreamRequestIsRetriedWithBackoff() {
        const parts = tileParts();

        CameraModel.restreamStartFailed(cameraId, true);
        verify(parts.retryTimer.running, "a failed restream request must schedule a retry");
        compare(parts.retryTimer.interval, 2000);
        verify(parts.cameraTile.awaitingRestream,
               "the tile must keep showing Connecting while a retry is pending");

        CameraModel.restreamStartFailed(cameraId, true);
        compare(parts.retryTimer.interval, 4000, "each further failure must back off");
        CameraModel.restreamStartFailed(cameraId, true);
        CameraModel.restreamStartFailed(cameraId, true);
        CameraModel.restreamStartFailed(cameraId, true);
        compare(parts.retryTimer.interval, 10000, "the backoff must be capped at 10s");

        CameraModel.setRestreamUrlForTest(cameraId, "rtsp://restream.test/back", true);
        verify(!parts.retryTimer.running, "a successful restream must cancel the pending retry");

        CameraModel.restreamStartFailed(cameraId, true);
        compare(parts.retryTimer.interval, 2000, "a successful restream must reset the backoff");
        parts.retryTimer.stop();
    }
}
