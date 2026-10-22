// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// A backend that rejects every token, even freshly issued ones, must not send
// the client into a loop of fetching a new token and retrying. The camera
// panel shows a sign-in rejected message instead of cycling between
// "Loading…" and "No cameras", and recovers once the backend accepts tokens.
TestCase {
    id: testCase
    name: "CameraPanelAuthRejected"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    App {
        id: appUnderTest
        anchors.fill: parent
    }

    property string _siteId: ""

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
        RejectingBackend.acceptsTokens = false;
        if (testCase._siteId.length > 0) {
            SiteManager.removeSite(testCase._siteId);
            testCase._siteId = "";
        }
        wait(50);
    }

    // A local site whose restored access token the backend no longer accepts.
    // Its refresh token still works, so every 401 can be answered with a new
    // token that the backend rejects again.
    function setUpRejectingSite() {
        testCase._siteId = SiteManager.addSite("Rejecting Site " + Date.now());
        SiteManager.addNode(testCase._siteId, RejectingBackend.url);
        const client = SiteManager.clientForSite(testCase._siteId);
        verify(client !== null, "site client not found");
        client.restoreSession("viewer", "stale-token", "refresh-token");
        SiteManager.activeSiteIndex = SiteManager.siteIndexById(testCase._siteId);
        return client;
    }

    function test_rejectedTokenDoesNotLoop() {
        setUpRejectingSite();
        wait(1000);

        const settled = RejectingBackend.requestCount;
        wait(500);
        verify(RejectingBackend.requestCount - settled <= 2,
               "client kept fetching new tokens the backend rejects: "
               + (RejectingBackend.requestCount - settled) + " requests in 500 ms");
    }

    function test_rejectedTokenShowsMessage() {
        const client = setUpRejectingSite();

        tryCompare(client, "tokenRejected", true, 2000);
        tryCompare(CameraModel, "authRejected", true);

        const rejected = findChild(appUnderTest, "cameraListAuthRejectedState");
        verify(rejected !== null, "sign-in rejected state not found");
        verify(rejected.visible);
        const empty = findChild(appUnderTest, "cameraListEmptyState");
        verify(empty !== null, "camera list empty state not found");
        verify(!empty.visible);
    }

    function test_recoversWhenTheBackendAcceptsTokensAgain() {
        const client = setUpRejectingSite();
        tryCompare(CameraModel, "authRejected", true, 2000);

        RejectingBackend.acceptsTokens = true;
        client.setStatusForTest(3); // Error
        client.setStatusForTest(2); // Online

        tryCompare(CameraModel, "authRejected", false, 2000);
        verify(client.hasSession, "recovery must keep the session, not clear it");
        const empty = findChild(appUnderTest, "cameraListEmptyState");
        tryCompare(empty, "visible", true);
    }
}
