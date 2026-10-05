// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for MatrixView.qml's tile resize handles and drag-to-reposition
// DragHandler. Real pointer-drag interactions like these are prone to
// crashes, silent no-ops, and data loss, so they're driven with real mouse
// events here.
//
// Each test gives TileLayoutModel a freshly-named site id: Qt Quick Test
// runs test_* functions alphabetically, not declaration order, so tests
// must not depend on state left behind by whichever other test ran first.
TestCase {
    id: testCase
    name: "MatrixViewResizeReposition"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    App {
        id: appUnderTest
        anchors.fill: parent
    }

    function freshSite(label) {
        TileLayoutModel.activeSiteId = "qmltest-resize-" + label + "-" + Date.now();
    }

    // Drags from the center of `item` by (dx, dy) via a synthetic
    // press/move/release sequence walked in several steps, mirroring
    // tst_CameraDragDrop.qml's dragOnto() helper.
    function dragBy(item, dx, dy) {
        const start = testCase.mapFromItem(item, item.width / 2, item.height / 2);
        mousePress(testCase, start.x, start.y);

        const steps = 8;
        for (let i = 1; i <= steps; i++) {
            mouseMove(testCase, start.x + dx * (i / steps), start.y + dy * (i / steps));
            wait(10);
        }

        mouseRelease(testCase, start.x + dx, start.y + dy);
    }

    function test_rightHandleResizesColSpan() {
        freshSite("right-handle");
        const tileId = TileLayoutModel.addTile();
        compare(TileLayoutModel.tileById(tileId).colSpan, 2);

        const tile = findChild(appUnderTest, "matrixTile_" + tileId);
        verify(tile !== null, "matrix tile not found");
        wait(50);

        const handle = findChild(tile, "resizeHandleRight_" + tileId);
        verify(handle !== null, "right resize handle not found");

        const colWidth = findChild(appUnderTest, "matrixGridArea").width / 8;
        dragBy(handle, colWidth * 2, 0);

        tryVerify(function() { return TileLayoutModel.tileById(tileId).colSpan === 4; });
        compare(TileLayoutModel.tileById(tileId).rowSpan, 2, "row span must be unaffected");
    }

    function test_rightHandleResizePushesAdjacentTileRight() {
        freshSite("push-neighbor");
        const leftId = TileLayoutModel.addTile();
        TileLayoutModel.moveTile(leftId, 0, 0);
        const rightId = TileLayoutModel.addTile();
        TileLayoutModel.moveTile(rightId, 2, 0);
        compare(TileLayoutModel.tileById(rightId).col, 2);

        const tile = findChild(appUnderTest, "matrixTile_" + leftId);
        verify(tile !== null, "left tile not found");
        // Let both tiles' slide-into-place Behavior (triggered by moveTile
        // above) settle before computing drag positions off their geometry.
        wait(200);

        const handle = findChild(tile, "resizeHandleRight_" + leftId);
        verify(handle !== null, "right resize handle not found");

        const colWidth = findChild(appUnderTest, "matrixGridArea").width / 8;
        // Grow the left tile (col 0, span 2) by 2 columns. Its new right
        // edge (col 4) would land squarely on the right tile (col 2, span 2),
        // which must get pushed out of the way instead of blocking the resize.
        dragBy(handle, colWidth * 2, 0);

        tryVerify(function() { return TileLayoutModel.tileById(leftId).colSpan === 4; });
        compare(TileLayoutModel.tileById(rightId).col, 4,
                "pushed tile must shift right by exactly the growth amount");
    }

    function test_rightHandleResizeClampsAtGridEdgeWhenPushWouldOverflow() {
        freshSite("push-clamp");
        const leftId = TileLayoutModel.addTile();
        TileLayoutModel.moveTile(leftId, 0, 0);
        const rightId = TileLayoutModel.addTile();
        TileLayoutModel.moveTile(rightId, 2, 0);
        TileLayoutModel.resizeTile(rightId, 6, 2); // occupies cols 2-7, flush with the grid edge

        const tile = findChild(appUnderTest, "matrixTile_" + leftId);
        verify(tile !== null, "left tile not found");
        wait(200);

        const handle = findChild(tile, "resizeHandleRight_" + leftId);
        verify(handle !== null, "right resize handle not found");

        const colWidth = findChild(appUnderTest, "matrixGridArea").width / 8;
        // Ask for way more growth than fits. The right tile is already
        // flush against column 8, so pushing it anywhere would overflow.
        dragBy(handle, colWidth * 6, 0);
        wait(150);

        compare(TileLayoutModel.tileById(leftId).colSpan, 2,
                "growth must be fully clamped: the neighbor has zero room to be pushed into");
        compare(TileLayoutModel.tileById(rightId).col, 2, "unpushable neighbor must stay put");
    }

    function test_bottomHandleResizesRowSpan() {
        freshSite("bottom-handle");
        const tileId = TileLayoutModel.addTile();
        compare(TileLayoutModel.tileById(tileId).rowSpan, 2);

        const tile = findChild(appUnderTest, "matrixTile_" + tileId);
        verify(tile !== null, "matrix tile not found");
        wait(50);

        const handle = findChild(tile, "resizeHandleBottom_" + tileId);
        verify(handle !== null, "bottom resize handle not found");

        const rowHeight = findChild(appUnderTest, "matrixGridArea").rowHeight;
        dragBy(handle, 0, rowHeight * 2);

        tryVerify(function() { return TileLayoutModel.tileById(tileId).rowSpan === 4; });
        compare(TileLayoutModel.tileById(tileId).colSpan, 2, "col span must be unaffected");
    }

    function test_dragRepositionsTileToNewCell() {
        freshSite("reposition");
        const tileId = TileLayoutModel.addTile();
        compare(TileLayoutModel.tileById(tileId).col, 0);
        compare(TileLayoutModel.tileById(tileId).row, 0);

        const tile = findChild(appUnderTest, "matrixTile_" + tileId);
        verify(tile !== null, "matrix tile not found");
        // Let the tile's slide-into-place Behavior settle before reading its
        // geometry, same reasoning as tst_CameraDragDrop.qml.
        wait(200);

        const grid = findChild(appUnderTest, "matrixGridArea");
        const colWidth = grid.width / 8;
        // Only 1 row down: gridArea.rowHeight grows to fit the drag ghost
        // once it's dragged past the layout's current occupied rows (see
        // MatrixView.qml's rowHeight binding), which would make a
        // precomputed pixel-per-row distance drift mid-drag. This tile's
        // own rowSpan (2) already occupies rows 0-1, so row 1 is reachable
        // without triggering that expansion.
        const rowHeight = grid.rowHeight;

        dragBy(tile, colWidth * 2, rowHeight * 1);

        tryVerify(function() { return TileLayoutModel.tileById(tileId).col === 2; });
        compare(TileLayoutModel.tileById(tileId).row, 1);
    }

    function test_dragIntoOverlapIsRejected() {
        freshSite("overlap");
        const stationaryId = TileLayoutModel.addTile();
        TileLayoutModel.moveTile(stationaryId, 4, 0);
        const movingId = TileLayoutModel.addTile();
        TileLayoutModel.moveTile(movingId, 0, 0);
        compare(TileLayoutModel.tileById(movingId).col, 0);

        const tile = findChild(appUnderTest, "matrixTile_" + movingId);
        verify(tile !== null, "moving tile not found");
        wait(200);

        const grid = findChild(appUnderTest, "matrixGridArea");
        const colWidth = grid.width / 8;

        // Drag squarely onto the stationary tile's cell. TileLayoutModel.moveTile
        // silently rejects moves that would overlap another tile, so the
        // model position must be unchanged even though the drag gesture itself
        // completed normally.
        dragBy(tile, colWidth * 4, 0);
        wait(150);

        compare(TileLayoutModel.tileById(movingId).col, 0,
                "overlapping drop must be rejected, leaving the tile at its original cell");
        compare(TileLayoutModel.tileById(stationaryId).col, 4, "stationary tile must be untouched");
    }

    // moveTileWithPush is exercised directly (bypassing MatrixView's drag
    // gesture). It's what the grid drop handler for a brand-new tile calls,
    // distinct from moveTile()'s reject-and-snap-back used everywhere else.
    function test_droppingNewTileOnLeftPushesExistingTileRight() {
        freshSite("insert-left");
        const existingId = TileLayoutModel.addTile();
        TileLayoutModel.moveTile(existingId, 0, 0);

        const newId = TileLayoutModel.addTile(); // lands below existingId by default
        TileLayoutModel.moveTileWithPush(newId, 0, 0);

        compare(TileLayoutModel.tileById(newId).col, 0, "new tile takes the requested spot");
        compare(TileLayoutModel.tileById(existingId).col, 2,
                "existing tile must be pushed right by exactly the new tile's width");
    }

    function test_droppingNewTileBetweenTwoExistingTilesPushesTheRightOneOver() {
        freshSite("insert-between");
        const leftId = TileLayoutModel.addTile();
        TileLayoutModel.moveTile(leftId, 0, 0);
        const rightId = TileLayoutModel.addTile();
        TileLayoutModel.moveTile(rightId, 2, 0);

        const newId = TileLayoutModel.addTile();
        // Land squarely on the right tile's cell. It (and anything beyond
        // it) must shift right; the left tile is untouched since the new
        // tile's rect never overlaps it.
        TileLayoutModel.moveTileWithPush(newId, 2, 0);

        compare(TileLayoutModel.tileById(newId).col, 2);
        compare(TileLayoutModel.tileById(leftId).col, 0, "left tile must be untouched");
        compare(TileLayoutModel.tileById(rightId).col, 4,
                "right tile must be pushed right by exactly the new tile's width");
    }

    function test_droppingNewTileRefusedWhenCascadingWouldOverflowGrid() {
        freshSite("insert-no-room");
        const blockerId = TileLayoutModel.addTile();
        TileLayoutModel.moveTile(blockerId, 2, 0);
        TileLayoutModel.resizeTile(blockerId, 6, 2); // flush against the grid's right edge

        const newId = TileLayoutModel.addTile();
        TileLayoutModel.moveTileWithPush(newId, 2, 0);

        compare(TileLayoutModel.tileById(newId).col, 0,
                "refused insert must leave the new tile at addTile()'s original spot");
        compare(TileLayoutModel.tileById(blockerId).col, 2, "unpushable tile must stay put");
    }
}
