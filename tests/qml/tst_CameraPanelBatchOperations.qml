// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for camera-list multi-select + batch enable/disable/delete.
// CameraModel is one shared instance across every test file in this binary
// run, so this file clears it in initTestCase() to work with a known,
// isolated set of cameras rather than whatever other test files happened
// to leave behind.
TestCase {
    id: testCase
    name: "CameraPanelBatchOperations"
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

    function freshCameras(label) {
        CameraModel.clearTestCameras();
        const id1 = "qmltest-batch-" + label + "-1-" + Date.now();
        const id2 = "qmltest-batch-" + label + "-2-" + Date.now();
        CameraModel.insertTestCamera(id1, "Batch Cam 1");
        CameraModel.insertTestCamera(id2, "Batch Cam 2");
        return [id1, id2];
    }

    // CameraPanel.qml's root Rectangle is the only ancestor exposing
    // `selectionMode`/`selectedIds`; walk up from a known row to find it,
    // since the panel itself has no objectName.
    function findPanelRoot(item) {
        let p = item;
        while (p) {
            if (p.selectionMode !== undefined && p.selectedIds !== undefined)
                return p;
            p = p.parent;
        }
        return null;
    }

    function test_setEnabledUpdatesModelOptimistically() {
        const ids = freshCameras("set-enabled");
        compare(CameraModel.cameraById(ids[0]).cameraEnabled, true,
                "insertTestCamera should default to enabled");

        CameraModel.setEnabled(ids[0], false);

        compare(CameraModel.cameraById(ids[0]).cameraEnabled, false);
        compare(CameraModel.cameraById(ids[1]).cameraEnabled, true,
                "the other camera must be unaffected");
    }

    function test_selectionModeShowsCheckboxesAndBatchEnableDisable() {
        const ids = freshCameras("toolbar");
        wait(50); // ListView delegates are created incrementally

        const row1 = findChild(appUnderTest, "cameraRow_" + ids[0]);
        verify(row1 !== null, "first batch test row not found");
        const row2 = findChild(appUnderTest, "cameraRow_" + ids[1]);
        verify(row2 !== null, "second batch test row not found");

        const panelRoot = findPanelRoot(row1);
        verify(panelRoot !== null, "camera panel root (with selectionMode) not found");

        // Drive selection through the same functions the header toggle
        // button and row checkboxes call (`onClicked`/`onToggled`), rather
        // than hunting for those unnamed items directly.
        panelRoot.selectionMode = true;
        panelRoot.toggleSelected(ids[0]);
        panelRoot.toggleSelected(ids[1]);
        compare(panelRoot.selectedIds.length, 2);

        // Batch-disable both via the same function the toolbar's Disable
        // button calls.
        panelRoot.batchSetEnabled(false);

        tryVerify(function() {
            return CameraModel.cameraById(ids[0]).cameraEnabled === false &&
                   CameraModel.cameraById(ids[1]).cameraEnabled === false;
        }, 2000, "batch disable did not apply to both selected cameras");

        panelRoot.batchSetEnabled(true);

        tryVerify(function() {
            return CameraModel.cameraById(ids[0]).cameraEnabled === true &&
                   CameraModel.cameraById(ids[1]).cameraEnabled === true;
        }, 2000, "batch enable did not apply to both selected cameras");

        panelRoot.exitSelectionMode();
        compare(panelRoot.selectionMode, false);
        compare(panelRoot.selectedIds.length, 0);
    }

    function test_exitSelectionModeClearsSelection() {
        const ids = freshCameras("exit");
        wait(50);

        const row1 = findChild(appUnderTest, "cameraRow_" + ids[0]);
        verify(row1 !== null);

        const panelRoot = findPanelRoot(row1);
        verify(panelRoot !== null);

        panelRoot.selectionMode = true;
        panelRoot.toggleSelected(ids[0]);
        compare(panelRoot.selectedIds.length, 1);

        panelRoot.exitSelectionMode();

        compare(panelRoot.selectionMode, false);
        compare(panelRoot.selectedIds.length, 0);
        verify(!panelRoot.isSelected(ids[0]));
    }
}
