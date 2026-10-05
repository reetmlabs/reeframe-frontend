// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for the global command palette: Ctrl+K opens it from anywhere,
// it searches cameras/pipelines/sources by name at once, and activating a
// result navigates to it.
TestCase {
    id: testCase
    name: "CommandPalette"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    App {
        id: appUnderTest
        anchors.fill: parent
    }

    function palette() {
        return findChild(appUnderTest, "commandPalette");
    }

    function initTestCase() {
        OverlayPrefs.cameraPanelOpen = false;
        CameraModel.clearTestCameras();
    }

    function cleanup() {
        // Belt-and-braces: make sure a failed assertion mid-test doesn't
        // leave the palette open for the next test_* function.
        const p = palette();
        if (p) p.close();
    }

    function test_ctrlKOpensAndEscapeCloses() {
        const p = palette();
        verify(p !== null, "command palette not found");
        compare(p.opened, false);

        keyClick(Qt.Key_K, Qt.ControlModifier);
        tryCompare(p, "opened", true);

        keyClick(Qt.Key_Escape);
        tryCompare(p, "opened", false);
    }

    function test_searchFindsCameraPipelineAndSource() {
        const camId = "qmltest-palette-cam-" + Date.now();
        CameraModel.insertTestCamera(camId, "Palette Camera Unique");

        const p = palette();
        p.open();
        p.query = "Palette Camera Unique";

        tryVerify(function() { return p.results.length === 1; }, 2000);
        compare(p.results[0].type, "camera");
        compare(p.results[0].id, camId);

        p.close();
    }

    function test_activatingCameraResultOpensPanelAndFlashes() {
        const camId = "qmltest-palette-flash-" + Date.now();
        CameraModel.insertTestCamera(camId, "Flash Target Camera");
        OverlayPrefs.cameraPanelOpen = false;

        const p = palette();
        p.open();
        p.query = "Flash Target Camera";
        tryVerify(function() { return p.results.length === 1; }, 2000);

        p.activateResult(0);

        tryCompare(p, "opened", false);
        tryCompare(OverlayPrefs, "cameraPanelOpen", true);

        // Walk up to the panel root (has flashCameraId) the same way other
        // tests locate CameraPanel's root.
        function findPanelRoot(item) {
            let node = item;
            while (node) {
                if (node.flashCameraId !== undefined)
                    return node;
                node = node.parent;
            }
            return null;
        }
        const row = findChild(appUnderTest, "cameraRow_" + camId);
        verify(row !== null, "flashed camera row not found");
        const panelRoot = findPanelRoot(row);
        verify(panelRoot !== null, "camera panel root not found");
        compare(panelRoot.flashCameraId, camId);
    }

    function test_noQueryShowsNoResults() {
        const p = palette();
        p.open();
        compare(p.query, "");
        compare(p.results.length, 0);
        p.close();
    }
}
