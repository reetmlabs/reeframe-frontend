// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Guards against a click-swallowing z-order bug: an EmptyState declared
// BEFORE the camera ListView sits BEHIND it. Even with zero delegates,
// ListView (a Flickable) captures press events across its full bounds for
// flick-gesture detection, swallowing clicks meant for the "+ Add Camera"
// button underneath. CameraPanel.qml declares EmptyState AFTER cameraList
// so it stacks (and receives events) on top.
//
// CameraModel is one shared instance across every test file in this binary
// run, so this file explicitly clears it in initTestCase() rather than
// assuming a naturally-empty list. Other test files re-seed whatever
// cameras they need in their own initTestCase() and don't depend on state
// surviving from earlier files, so this doesn't affect them.
TestCase {
    id: testCase
    name: "CameraPanelEmptyState"
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
        CameraModel.clearTestCameras();
    }

    function test_addCameraButtonOpensDialogWhenListIsEmpty() {
        compare(CameraModel.count, 0, "expected an empty camera list at test start");

        const emptyState = findChild(appUnderTest, "cameraListEmptyState");
        verify(emptyState !== null, "camera list empty state not found");
        tryCompare(emptyState, "visible", true);

        const button = findChild(emptyState, "emptyStateActionButton");
        verify(button !== null, "empty state action button not found");

        mouseClick(button, button.width / 2, button.height / 2);

        // addDialog is a private id inside CameraPanel.qml, not reachable by
        // objectName, so confirm success the same way a user would
        // observe it: the AddCameraDialog popup becomes visible on screen.
        tryVerify(function() {
            const dialog = findChild(appUnderTest, "addCameraDialog");
            return dialog !== null && dialog.opened;
        }, 2000, "add-camera dialog did not open after clicking the empty state's button");
    }
}
