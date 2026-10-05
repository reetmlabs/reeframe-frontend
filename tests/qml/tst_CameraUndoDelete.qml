// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// End-to-end coverage for the camera panel's undoable delete: confirming a
// delete hides the row immediately but doesn't touch CameraModel yet, and
// clicking "Undo" within the grace window brings the row back with the
// camera never actually deleted.
TestCase {
    id: testCase
    name: "CameraUndoDelete"
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
    }

    function findPanelRoot(item) {
        let node = item;
        while (node) {
            if (node.undoWindowMs !== undefined)
                return node;
            node = node.parent;
        }
        return null;
    }

    function test_requestDeleteHidesRowWithoutDeletingModel() {
        const id = "qmltest-undo-" + Date.now();
        CameraModel.insertTestCamera(id, "Undo Target");
        wait(50);

        const row = findChild(appUnderTest, "cameraRow_" + id);
        verify(row !== null, "camera row not found before delete");
        const panel = findPanelRoot(row);
        verify(panel !== null, "camera panel root not found");

        panel.requestDeleteCamera(id, "Undo Target");

        tryCompare(row, "visible", false);
        // Not actually deleted yet: still present in the model.
        verify(CameraModel.cameraById(id).cameraId !== undefined,
               "camera must still exist in the model during the undo window");
    }

    function test_undoRestoresRowAndCancelsDelete() {
        const id = "qmltest-undo-restore-" + Date.now();
        CameraModel.insertTestCamera(id, "Undo Restore Target");
        wait(50);

        const row = findChild(appUnderTest, "cameraRow_" + id);
        verify(row !== null);
        const panel = findPanelRoot(row);
        verify(panel !== null);

        panel.requestDeleteCamera(id, "Undo Restore Target");
        tryCompare(row, "visible", false);

        panel.undoDelete([id]);

        tryCompare(row, "visible", true);
        verify(!panel.isCameraPendingDelete(id));
        compare(CameraModel.cameraById(id).cameraId, id,
                "undone delete must leave the camera exactly as it was");
    }

    function test_batchDeleteHidesAllSelectedRows() {
        const id1 = "qmltest-undo-batch-1-" + Date.now();
        const id2 = "qmltest-undo-batch-2-" + Date.now();
        CameraModel.insertTestCamera(id1, "Batch Undo 1");
        CameraModel.insertTestCamera(id2, "Batch Undo 2");
        wait(50);

        const row1 = findChild(appUnderTest, "cameraRow_" + id1);
        const row2 = findChild(appUnderTest, "cameraRow_" + id2);
        verify(row1 !== null && row2 !== null);
        const panel = findPanelRoot(row1);
        verify(panel !== null);

        panel.requestBatchDeleteCameras([id1, id2], ["Batch Undo 1", "Batch Undo 2"]);

        tryCompare(row1, "visible", false);
        tryCompare(row2, "visible", false);

        // Undo both via the same function the toast's "Undo" click uses.
        panel.undoDelete([id1, id2]);

        tryCompare(row1, "visible", true);
        tryCompare(row2, "visible", true);
    }

    // Drives a real mouseClick instead of calling undoDelete() directly like
    // the other tests here: anything stacked above the Toast in z-order (e.g.
    // visualLayer) would swallow clicks on its "Undo" button even with
    // undoDelete() itself working.
    function test_clickingUndoButtonOnRealToastRestoresRow() {
        const id = "qmltest-undo-realclick-" + Date.now();
        CameraModel.insertTestCamera(id, "Real Click Undo Target");
        wait(50);

        const row = findChild(appUnderTest, "cameraRow_" + id);
        verify(row !== null);
        const panel = findPanelRoot(row);
        verify(panel !== null);

        panel.requestDeleteCamera(id, "Real Click Undo Target");
        tryCompare(row, "visible", false);

        const undoButton = findChild(appUnderTest, "toastActionButton");
        verify(undoButton !== null, "toast undo button not found");
        verify(undoButton.width > 0 && undoButton.height > 0,
               "toast undo button has no size — likely not actually visible");

        mouseClick(undoButton, undoButton.width / 2, undoButton.height / 2);

        tryCompare(row, "visible", true);
        verify(!panel.isCameraPendingDelete(id));
    }
}
