// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for the right-hand dock: the icon rail, and the open/front/split
// behavior CameraPanel and RecordingsPanel share through DockController.
TestCase {
    id: testCase
    name: "RightDock"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    App {
        id: appUnderTest
        anchors.fill: parent
    }

    function controller() { return findChild(appUnderTest, "rightDockController"); }
    function cameraPanel() { return findChild(appUnderTest, "cameraPanel"); }
    function recordingsPanel() { return findChild(appUnderTest, "recordingsPanel"); }
    function railButton(id) { return findChild(appUnderTest, "dockRailButton_" + id); }

    function initTestCase() {
        OverlayPrefs.cameraPanelOpen = false;
        OverlayPrefs.recordingsPanelOpen = false;
    }

    // Every test starts from both panels closed, regardless of how the
    // previous test left them.
    function cleanup() {
        OverlayPrefs.cameraPanelOpen = false;
        OverlayPrefs.recordingsPanelOpen = false;
        tryCompare(controller(), "count", 0);
    }

    function test_railButtonsAlwaysPresent() {
        verify(railButton("cameras") !== null, "cameras rail button not found");
        verify(railButton("recordings") !== null, "recordings rail button not found");
    }

    function test_singlePanelFillsFullHeightWithNoPin() {
        mouseClick(railButton("cameras"));

        tryCompare(cameraPanel(), "visible", true);
        compare(recordingsPanel().visible, false);
        compare(cameraPanel().dockShowPin, false);
        compare(controller().splitMode, false);
    }

    function test_openingSecondPanelBringsItToFrontAsOverlay() {
        mouseClick(railButton("cameras"));
        tryCompare(cameraPanel(), "visible", true);

        mouseClick(railButton("recordings"));
        tryCompare(recordingsPanel(), "visible", true);

        compare(controller().splitMode, false);
        compare(controller().isFront("recordings"), true);
        verify(recordingsPanel().z > cameraPanel().z, "recordings should stack above cameras");

        // Only the front panel offers the split/pin toggle.
        compare(recordingsPanel().dockShowPin, true);
        compare(cameraPanel().dockShowPin, false);

        // Not split yet: both panels still claim the full column height.
        compare(cameraPanel().height, recordingsPanel().height);
    }

    function test_clickingRailIconOfHiddenOpenPanelBringsItForward() {
        mouseClick(railButton("cameras"));
        mouseClick(railButton("recordings"));
        compare(controller().isFront("recordings"), true);

        // Cameras is open but currently hidden behind recordings. Clicking
        // its rail icon again should bring it forward, not close it.
        mouseClick(railButton("cameras"));

        compare(controller().isFront("cameras"), true);
        compare(cameraPanel().visible, true);
        compare(recordingsPanel().visible, true);
    }

    function test_pinSplitsHeightAndIsReversible() {
        mouseClick(railButton("cameras"));
        mouseClick(railButton("recordings"));
        tryCompare(controller(), "count", 2);

        const pinIcon = findChild(recordingsPanel(), "recordingsPanelPinButton");
        verify(pinIcon !== null, "pin button not found on front panel");

        mouseClick(pinIcon);
        tryCompare(controller(), "splitMode", true);

        const fullHeight = cameraPanel().height + recordingsPanel().height;
        compare(cameraPanel().height, recordingsPanel().height);
        verify(Math.abs(cameraPanel().height - fullHeight / 2) < 1);

        mouseClick(pinIcon);
        tryCompare(controller(), "splitMode", false);
    }

    function test_closingOnePanelWhileSplitGivesTheOtherFullHeight() {
        mouseClick(railButton("cameras"));
        mouseClick(railButton("recordings"));
        tryCompare(controller(), "count", 2);

        const pinIcon = findChild(recordingsPanel(), "recordingsPanelPinButton");
        mouseClick(pinIcon);
        tryCompare(controller(), "splitMode", true);

        // Recordings is front; clicking its rail icon closes it.
        mouseClick(railButton("recordings"));

        tryCompare(controller(), "count", 1);
        compare(controller().splitMode, false);
        compare(recordingsPanel().visible, false);
        compare(cameraPanel().visible, true);
        compare(cameraPanel().dockShowPin, false);
    }
}
