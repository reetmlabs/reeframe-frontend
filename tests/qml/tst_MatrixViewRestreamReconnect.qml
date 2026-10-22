// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// A tile's video sink only reopens when its restreamUrl property actually
// changes value. If the backend hands back the same URL text a camera
// already had (as it can after a recovery), a plain reassignment would be
// a silent no-op, so the tile must still force a real property change.
TestCase {
    id: testCase
    name: "MatrixViewRestreamReconnect"
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
        cameraId = "qmltest-restream-cam-" + Date.now();
        CameraModel.insertTestCamera(cameraId, "Test Camera");
        tileId = TileLayoutModel.addTile();
        TileLayoutModel.assignCamera(tileId, cameraId);
    }

    function test_sameRestreamUrlStillForcesTheTileToReopenItsStream() {
        const tileItem = findChild(matrixView, "matrixTile_" + tileId);
        verify(tileItem !== null, "matrix tile not found");
        const cameraTile = findChild(tileItem, "matrixTileCameraStream");
        verify(cameraTile !== null, "camera tile stream not found");

        const spy = Qt.createQmlObject(
            'import QtTest; SignalSpy { }', testCase, "connectionStateSpy");
        spy.target = cameraTile;
        spy.signalName = "connectionStateChanged";

        CameraModel.setRestreamUrlForTest(cameraId, "rtsp://restream.test/one", true);
        compare(cameraTile.connectionState, "connecting",
                "expected the tile to attempt opening the fresh restream");

        const countBeforeRepeat = spy.count;
        // Same URL as before: must still force a real reopen rather than
        // being silently swallowed as a no-op property assignment.
        CameraModel.setRestreamUrlForTest(cameraId, "rtsp://restream.test/one", true);

        verify(spy.count > countBeforeRepeat,
               "reasserting the same restream URL must still force the tile to reopen its stream");
    }
}
