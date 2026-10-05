// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// BackendClient polls /health on a timer so Status recovers on its own (BE
// came up after the FE did, or came back after dying mid-session). These
// tests simulate a poll outcome via setStatusForTest() rather than waiting on
// the real interval or standing up a real backend.
TestCase {
    id: testCase
    name: "BackendStatusRecovery"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    SiteManagerView { id: siteView; anchors.fill: parent }

    function clearAllConnections() {
        const urls = CoordinatorManager.urls();
        for (let i = 0; i < urls.length; i++)
            CoordinatorManager.removeConnection(urls[i]);
    }

    function initTestCase() { clearAllConnections(); }

    function cleanup() {
        SiteManager.clearRemoteSitesForTest();
        clearAllConnections();
        wait(50);
    }

    function setUpFreshCoordinatorSite(siteName) {
        const url = "https://coord-" + Date.now() + "-" + Math.random() + ".test";
        CoordinatorManager.addConnection(url);
        const beId = "qmltest-be-" + Date.now() + "-" + Math.random();
        SiteManager.seedRemoteSiteForTest(url, beId, siteName, "http://127.0.0.1:1");
        SiteManager.activeSiteIndex = SiteManager.siteIndexById(beId);
        wait(50);

        const client = SiteManager.clientForSite(beId);
        verify(client !== null, "site client not found");
        return client;
    }

    function test_activeSiteStatusFlipsToErrorOnSimulatedPollFailure() {
        const client = setUpFreshCoordinatorSite("Poll Failure");
        client.setStatusForTest(3); // Error
        compare(SiteManager.activeSiteStatus, 3);
    }

    function test_activeSiteStatusFlipsBackToOnlineOnSimulatedPollSuccess() {
        const client = setUpFreshCoordinatorSite("Poll Recovery");
        client.setStatusForTest(3); // Error
        compare(SiteManager.activeSiteStatus, 3);
        client.setStatusForTest(2); // Online
        compare(SiteManager.activeSiteStatus, 2);
    }

    function test_cameraModelRefreshesWhenActiveSiteRecoversToOnline() {
        const client = setUpFreshCoordinatorSite("Camera Recovery");

        // Let the initial (necessarily failed, no real backend here) refresh
        // settle before triggering the one we actually want to observe.
        tryCompare(CameraModel, "loading", false, 2000);

        client.setStatusForTest(3); // Error
        client.setStatusForTest(2); // Online
        tryCompare(CameraModel, "loading", true, 2000,
                   "CameraModel must refresh() when the active site's client recovers to Online");
    }
}
