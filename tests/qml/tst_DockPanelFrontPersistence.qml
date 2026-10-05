// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// DockController itself never persists which panel was
// frontmost (see DockController.qml's own header comment); only each
// panel's open/closed flag is saved via OverlayPrefs. Without explicitly
// restoring the front panel, App.qml's fixed startup call order (cameras'
// setOpen() always runs before recordings') would leave recordings
// frontmost on every launch whenever both panels are open, regardless of
// what the user actually had in front when they quit.
//
// Each test creates a fresh App instance to actually re-run that startup
// sequence, the same way a real app relaunch would. Reading
// appUnderTest.dockController after the fact (as tst_RightDock.qml does)
// wouldn't exercise Component.onCompleted at all, since it already ran once
// when that shared instance was first created.
TestCase {
    id: testCase
    name: "DockPanelFrontPersistence"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    Component {
        id: appComponent
        App {}
    }

    function cleanup() {
        OverlayPrefs.cameraPanelOpen = false
        OverlayPrefs.recordingsPanelOpen = false
        OverlayPrefs.frontDockPanel = "cameras"
    }

    function test_camerasStaysFrontOnNextLaunchAfterBeingBroughtForwardLast() {
        // Simulate the end of a previous session: both panels open,
        // cameras was the one the user last brought to front.
        OverlayPrefs.cameraPanelOpen = true
        OverlayPrefs.recordingsPanelOpen = true
        OverlayPrefs.frontDockPanel = "cameras"

        const app = appComponent.createObject(testCase, {})
        verify(app !== null, "failed to create App instance")

        const controller = findChild(app, "rightDockController")
        verify(controller !== null, "dock controller not found")

        compare(controller.isFront("cameras"), true,
                "cameras must still be front on the next launch, not recordings")

        app.destroy()
    }

    function test_recordingsStaysFrontOnNextLaunchAfterBeingBroughtForwardLast() {
        OverlayPrefs.cameraPanelOpen = true
        OverlayPrefs.recordingsPanelOpen = true
        OverlayPrefs.frontDockPanel = "recordings"

        const app = appComponent.createObject(testCase, {})
        verify(app !== null, "failed to create App instance")

        const controller = findChild(app, "rightDockController")
        verify(controller !== null, "dock controller not found")

        compare(controller.isFront("recordings"), true,
                "recordings must still be front on the next launch")

        app.destroy()
    }

    function test_bringingCamerasToFrontPersistsItAsTheNewFrontPanel() {
        OverlayPrefs.cameraPanelOpen = true
        OverlayPrefs.recordingsPanelOpen = true
        OverlayPrefs.frontDockPanel = "recordings"

        const app = appComponent.createObject(testCase, {})
        verify(app !== null, "failed to create App instance")

        const controller = findChild(app, "rightDockController")
        verify(controller !== null, "dock controller not found")
        compare(controller.isFront("recordings"), true)

        controller.bringToFront("cameras")

        compare(OverlayPrefs.frontDockPanel, "cameras",
                "bringing a panel forward must persist it as the new front panel")

        app.destroy()
    }
}
