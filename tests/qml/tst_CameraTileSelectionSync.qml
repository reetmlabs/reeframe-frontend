// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Regression coverage for two-way sync between CameraPanel's row selection
// and MatrixView's tile selection: selecting a camera in the list must
// highlight its tile, and clicking a tile must select that camera in the
// list (which is what drives RecordingsPanel's auto-loaded camera, via its
// existing syncedCameraId binding to CameraPanel.selectedCameraId).
TestCase {
    id: testCase
    name: "CameraTileSelectionSync"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    App {
        id: appUnderTest
        anchors.fill: parent
    }

    function initTestCase() {
        OverlayPrefs.cameraPanelOpen = true;
        TileLayoutModel.activeSiteId = "qmltest-tile-select-" + Date.now();
    }

    function cameraPanel() { return findChild(appUnderTest, "cameraPanel"); }

    function test_selectingCameraInListHighlightsItsTile() {
        const camId = "qmltest-select-sync-a-" + Date.now();
        CameraModel.insertTestCamera(camId, "Select Sync A");
        const tileId = TileLayoutModel.addTile();
        TileLayoutModel.assignCamera(tileId, camId);

        const tile = findChild(appUnderTest, "matrixTile_" + tileId);
        verify(tile !== null, "matrix tile not found");
        compare(tile.isSelected, false, "tile must not start selected");

        cameraPanel().selectCamera(camId, "Select Sync A");

        tryCompare(tile, "isSelected", true);
    }

    function test_clickingTileSelectsItsCameraInTheList() {
        const camId = "qmltest-select-sync-b-" + Date.now();
        CameraModel.insertTestCamera(camId, "Select Sync B");
        const tileId = TileLayoutModel.addTile();
        TileLayoutModel.assignCamera(tileId, camId);

        const tile = findChild(appUnderTest, "matrixTile_" + tileId);
        verify(tile !== null, "matrix tile not found");
        wait(50);

        mouseClick(tile, tile.width / 2, tile.height / 2);

        // Only the id is asserted here, not selectedCameraName: the name
        // comes from tile.camData, which CameraModel is free to reset out
        // from under any test at any time via its own background BE-health
        // poll (CameraModel is one shared instance for the whole qmltests
        // binary). tileCameraId itself, owned by TileLayoutModel, is not
        // subject to that race, and the id is what actually drives
        // RecordingsPanel's synced camera.
        tryCompare(cameraPanel(), "selectedCameraId", camId);
    }

    function test_clickingOneTileMovesTheHighlightAwayFromAnother() {
        const camId1 = "qmltest-select-sync-c-" + Date.now();
        const camId2 = "qmltest-select-sync-d-" + Date.now();
        CameraModel.insertTestCamera(camId1, "Select Sync C");
        CameraModel.insertTestCamera(camId2, "Select Sync D");
        const tileId1 = TileLayoutModel.addTile();
        TileLayoutModel.assignCamera(tileId1, camId1);
        const tileId2 = TileLayoutModel.addTile();
        TileLayoutModel.assignCamera(tileId2, camId2);

        const tile1 = findChild(appUnderTest, "matrixTile_" + tileId1);
        const tile2 = findChild(appUnderTest, "matrixTile_" + tileId2);
        verify(tile1 !== null && tile2 !== null, "both matrix tiles must exist");
        wait(50);

        mouseClick(tile1, tile1.width / 2, tile1.height / 2);
        tryCompare(tile1, "isSelected", true);

        mouseClick(tile2, tile2.width / 2, tile2.height / 2);
        tryCompare(tile2, "isSelected", true);
        compare(tile1.isSelected, false, "previous tile must lose its highlight");
    }
}
