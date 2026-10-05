// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Regression coverage for: deleting a camera must remove any tile that was
// assigned to it, rather than leaving a tile pointing at a camera that no
// longer exists.
//
// CameraModel.deleteCamera() itself requires a live backend connection
// (it's a real network DELETE request), which isn't available in this
// offline test binary, so this exercises TileLayoutModel.removeTilesForCamera()
// directly, the method that does the actual work and that CameraModel's
// cameraDeleted signal is wired to in both main.cpp and TestSetup.cpp.
//
// Each test gives TileLayoutModel a freshly-named site id: Qt Quick Test
// runs test_* functions alphabetically, not declaration order, so tests
// must not depend on state left behind by whichever other test ran first.
TestCase {
    id: testCase
    name: "TileCameraDeletionCleanup"
    when: true

    function freshSite(label) {
        TileLayoutModel.activeSiteId = "qmltest-cam-delete-" + label + "-" + Date.now();
    }

    function test_removingCameraRemovesItsTile() {
        freshSite("basic");
        const cameraId = "qmltest-deleted-cam-" + Date.now();
        const tileId = TileLayoutModel.addTile();
        TileLayoutModel.assignCamera(tileId, cameraId);
        compare(TileLayoutModel.rowCount(), 1);
        verify(TileLayoutModel.hasCameraAssigned(cameraId));

        TileLayoutModel.removeTilesForCamera(cameraId);

        compare(TileLayoutModel.rowCount(), 0,
                "the tile assigned to the deleted camera should be gone");
        verify(!TileLayoutModel.hasCameraAssigned(cameraId));
    }

    function test_removingCameraLeavesOtherTilesUntouched() {
        freshSite("other-tiles");
        const deletedCameraId = "qmltest-deleted-cam-" + Date.now();
        const keptCameraId = "qmltest-kept-cam-" + Date.now();

        const deletedTileId = TileLayoutModel.addTile();
        TileLayoutModel.assignCamera(deletedTileId, deletedCameraId);
        const keptTileId = TileLayoutModel.addTile();
        TileLayoutModel.assignCamera(keptTileId, keptCameraId);
        const emptyTileId = TileLayoutModel.addTile();
        compare(TileLayoutModel.rowCount(), 3);

        TileLayoutModel.removeTilesForCamera(deletedCameraId);

        compare(TileLayoutModel.rowCount(), 2,
                "only the tile bound to the deleted camera should be removed");
        verify(TileLayoutModel.hasCameraAssigned(keptCameraId),
               "the other camera's tile must survive");
        compare(TileLayoutModel.tileById(keptTileId).cameraId, keptCameraId);
        verify(TileLayoutModel.tileById(emptyTileId).cameraId !== undefined,
               "unrelated empty tile must still exist");
        verify(TileLayoutModel.tileById(deletedTileId).cameraId === undefined,
               "the removed tile's own record should no longer be found");
    }

    function test_removingUnassignedCameraIsANoOp() {
        freshSite("no-op");
        const tileId = TileLayoutModel.addTile();
        compare(TileLayoutModel.rowCount(), 1);

        TileLayoutModel.removeTilesForCamera("qmltest-camera-never-assigned-" + Date.now());

        compare(TileLayoutModel.rowCount(), 1,
                "removing a camera with no assigned tile must not affect existing tiles");
    }
}
