// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Once the camera list has settled empty, a background refresh (a session
// renewal, a status reassertion, a site re-emit) must leave the "No cameras"
// empty state on screen instead of swapping it for "Loading…" and back.
TestCase {
    id: testCase
    name: "CameraPanelRefreshFlicker"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    App {
        id: appUnderTest
        anchors.fill: parent
    }

    property int emptyStateHides: 0

    Connections {
        id: emptyStateWatch
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (!emptyStateWatch.target.visible)
                testCase.emptyStateHides++;
        }
    }

    function clearAllConnections() {
        const urls = CoordinatorManager.urls();
        for (let i = 0; i < urls.length; i++)
            CoordinatorManager.removeConnection(urls[i]);
    }

    function initTestCase() {
        OverlayPrefs.cameraPanelOpen = true;
        clearAllConnections();
    }

    function cleanup() {
        emptyStateWatch.target = null;
        SiteManager.clearRemoteSitesForTest();
        clearAllConnections();
        wait(50);
    }

    function test_backgroundRefreshKeepsEmptyStateVisible() {
        const url = "https://coord-" + Date.now() + "-" + Math.random() + ".test";
        CoordinatorManager.addConnection(url);
        const beId = "qmltest-be-" + Date.now() + "-" + Math.random();
        SiteManager.seedRemoteSiteForTest(url, beId, "No Cameras Here", EmptyBackend.url);
        SiteManager.activeSiteIndex = SiteManager.siteIndexById(beId);
        const client = SiteManager.clientForSite(beId);
        verify(client !== null, "site client not found");

        tryCompare(CameraModel, "loading", false, 2000);
        compare(CameraModel.count, 0);

        const emptyState = findChild(appUnderTest, "cameraListEmptyState");
        verify(emptyState !== null, "camera list empty state not found");
        tryCompare(emptyState, "visible", true);

        emptyStateHides = 0;
        emptyStateWatch.target = emptyState;

        for (let i = 0; i < 3; i++) {
            CameraModel.refresh();
            client.setStatusForTest(2); // Online, which also triggers a refresh
            wait(100);
        }

        compare(emptyStateHides, 0,
                "a background refresh must not hide the empty state behind \"Loading…\"");
        verify(emptyState.visible);
    }
}
