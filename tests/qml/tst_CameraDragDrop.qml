// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for dragging a camera row from the right-side CameraPanel onto
// the matrix to assign it, the only way to assign a camera to a tile.
// Exercises the real CameraPanel.qml / MatrixView.qml through a synthetic
// press-move-release sequence, the same QTest::mouse* injection used by
// tst_MatrixViewFullScreen.qml, so it needs no OS-level automation tool.
//
// Each test gives TileLayoutModel a freshly-named site id rather than
// sharing one from initTestCase(): Qt Quick Test runs test_* functions in
// alphabetical order, not declaration order, so tests must not depend on
// state left behind by whichever other test happened to run first.
TestCase {
    id: testCase
    name: "CameraDragDrop"
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
        CameraModel.insertTestCamera("qmltest-dnd-cam-1", "Lobby");
        CameraModel.insertTestCamera("qmltest-dnd-cam-2", "Loading Dock");
        // ListView delegates are created incrementally, unlike Repeater, so
        // give it a turn of the event loop before looking for camera rows.
        wait(50);
    }

    // Unique per call: the test app.db is a real SQLite file that persists
    // across invocations (see TestSetup.cpp), and every test needs its own
    // isolated profile/tiles regardless of run order.
    function freshSite(label) {
        TileLayoutModel.activeSiteId = "qmltest-dnd-" + label + "-" + Date.now();
    }

    // Drags `sourceItem` to the center of `targetItem` via a synthetic
    // press/move/release sequence, which drives the same QQuickDrag /
    // DropArea machinery a real mouse drag would. Every event is dispatched
    // against `testCase` itself (the actual window-root item) with positions
    // pre-mapped into its coordinate space, and walked in several steps. This
    // avoids relying on cross-item coordinate mapping inside a single
    // mouseMove call and gives Qt Quick's drag/hit-testing a chance to
    // process each intermediate position.
    function dragOnto(sourceItem, targetItem) {
        const start = testCase.mapFromItem(sourceItem, sourceItem.width / 2, sourceItem.height / 2);
        const end = testCase.mapFromItem(targetItem, targetItem.width / 2, targetItem.height / 2);

        mousePress(testCase, start.x, start.y);

        const steps = 8;
        for (let i = 1; i <= steps; i++) {
            const x = start.x + (end.x - start.x) * (i / steps);
            const y = start.y + (end.y - start.y) * (i / steps);
            mouseMove(testCase, x, y);
            wait(10);
        }

        mouseRelease(testCase, end.x, end.y);
    }

    function test_dragCameraOntoEmptyGridCreatesTile() {
        freshSite("empty-grid");
        compare(TileLayoutModel.rowCount(), 0, "expected an empty layout at test start");

        const row = findChild(appUnderTest, "cameraRow_qmltest-dnd-cam-1");
        verify(row !== null, "camera row not found in panel");

        const grid = findChild(appUnderTest, "matrixGridArea");
        verify(grid !== null, "matrix grid area not found");

        dragOnto(row, grid);

        tryVerify(function() { return TileLayoutModel.rowCount() === 1; });
        compare(TileLayoutModel.assignedCameraIds, ["qmltest-dnd-cam-1"]);
    }

    function test_dragCameraOntoExistingTileReplacesAssignment() {
        freshSite("replace");
        const seedTileId = TileLayoutModel.addTile();
        TileLayoutModel.assignCamera(seedTileId, "qmltest-dnd-cam-1");
        compare(TileLayoutModel.rowCount(), 1);

        const row = findChild(appUnderTest, "cameraRow_qmltest-dnd-cam-2");
        verify(row !== null, "second camera row not found in panel");

        const tile = findChild(appUnderTest, "matrixTile_" + seedTileId);
        verify(tile !== null, "existing matrix tile not found");
        // Let the tile's slide-into-place Behavior (MatrixView.qml, 120ms)
        // finish settling before reading its geometry. Otherwise the drag
        // below targets a still-animating position and drifts off the tile
        // by drop time, landing on the grid's empty-space DropArea instead.
        wait(200);

        dragOnto(row, tile);

        tryCompare(TileLayoutModel, "assignedCameraIds", ["qmltest-dnd-cam-2"]);
        compare(TileLayoutModel.rowCount(), 1, "dropping on an existing tile must not create a new one");
    }

    function test_dragAlreadyAssignedCameraIsBlocked() {
        freshSite("blocked");
        const seedTileId = TileLayoutModel.addTile();
        TileLayoutModel.assignCamera(seedTileId, "qmltest-dnd-cam-2");
        compare(TileLayoutModel.rowCount(), 1);

        const row = findChild(appUnderTest, "cameraRow_qmltest-dnd-cam-2");
        verify(row !== null, "already-assigned camera's row not found in panel");

        const ghost = findChild(appUnderTest, "dragGhost");
        verify(ghost !== null, "drag ghost not found");

        const grid = findChild(appUnderTest, "matrixGridArea");
        verify(grid !== null, "matrix grid area not found");

        const start = testCase.mapFromItem(row, row.width / 2, row.height / 2);
        const end = testCase.mapFromItem(grid, grid.width / 2, grid.height / 2);
        mousePress(testCase, start.x, start.y);
        for (let i = 1; i <= 8; i++) {
            mouseMove(testCase, start.x + (end.x - start.x) * (i / 8),
                                 start.y + (end.y - start.y) * (i / 8));
            wait(10);
        }
        // Dragging an already-assigned camera must show the blocked/error
        // state (App.qml's dragGhost.blocked), and dropping it anywhere
        // must not create a second tile for the same camera.
        verify(ghost.blocked, "ghost should be in the blocked state for an already-assigned camera");
        mouseRelease(testCase, end.x, end.y);

        compare(TileLayoutModel.rowCount(), 1, "dropping an already-assigned camera must not create a new tile");
        compare(TileLayoutModel.assignedCameraIds, ["qmltest-dnd-cam-2"]);
    }
}
