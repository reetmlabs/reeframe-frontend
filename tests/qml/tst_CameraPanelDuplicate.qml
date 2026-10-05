// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for the camera list's right-click "Duplicate" menu, and the
// CameraModel.nextDuplicateName() naming scheme it relies on. CameraModel is
// one shared instance across every test file in this binary run, so this
// file clears it in initTestCase() to work with a known, isolated set.
TestCase {
    id: testCase
    name: "CameraPanelDuplicate"
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

    function test_nextDuplicateNameStartsAtTwoThenSkipsTakenSuffixes() {
        CameraModel.clearTestCameras();
        const base = "Lobby-" + Date.now();
        CameraModel.insertTestCamera("qmltest-dup-a", base);
        compare(CameraModel.nextDuplicateName(base), base + " 2");

        CameraModel.insertTestCamera("qmltest-dup-b", base + " 2");
        compare(CameraModel.nextDuplicateName(base), base + " 3",
                "must skip an already-taken suffix and keep scanning");
    }

    function test_rightClickOpensDuplicateMenuAndPrefillsAddDialog() {
        CameraModel.clearTestCameras();
        const id = "qmltest-dup-rightclick-" + Date.now();
        const name = "Dup Source Camera";
        CameraModel.insertTestCamera(id, name);
        wait(50); // ListView delegates are created incrementally

        const row = findChild(appUnderTest, "cameraRow_" + id);
        verify(row !== null, "camera row not found");

        mouseClick(row, row.width / 2, row.height / 2, Qt.RightButton);
        wait(50);

        const menu = findChild(appUnderTest, "cameraRowContextMenu");
        verify(menu !== null, "context menu not found");
        compare(menu.visible, true, "right-click must open the context menu");

        const duplicateAction = findChild(menu, "duplicateCameraAction");
        verify(duplicateAction !== null, "Duplicate action not found");

        mouseClick(duplicateAction, duplicateAction.width / 2, duplicateAction.height / 2);
        wait(50);

        const dialog = findChild(appUnderTest, "addCameraDialog");
        verify(dialog !== null, "AddCameraDialog not found");
        compare(dialog.visible, true, "Duplicate must open the Add Camera dialog");
        compare(dialog.prefillName, name + " 2");
        // The dialog's form fields have no objectName, so this asserts
        // against the prefill properties onOpened() copies into them, which
        // is enough to prove the prefill reached the dialog.
        compare(dialog.prefillEnabled, true);
        compare(dialog.prefillLocation, "");
        compare(dialog.prefillRtspUrl, "");
        compare(dialog.prefillSubRtspUrl, "");
    }
}
