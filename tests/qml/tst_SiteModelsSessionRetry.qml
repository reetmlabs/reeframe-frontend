// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Guards a race shared by CameraModel, SourceModel, and DestinationModel:
// activeSiteChanged fires before a Coordinator site's coordinator-token exchange
// completes, so the first refresh() 401's. These models must retry once
// the client actually gains a session, or their lists stay empty forever.
TestCase {
    id: testCase
    name: "SiteModelsSessionRetry"
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
        compare(client.hasSession, false, "fresh Coordinator client shouldn't have a session yet");
        return client;
    }

    function test_cameraModelRetriesRefreshOnceTheActiveSiteGainsASession() {
        const client = setUpFreshCoordinatorSite("Remote Camera Retry");

        // Let the initial (necessarily failed, no real backend here) refresh
        // settle before triggering the one we actually want to observe.
        tryCompare(CameraModel, "loading", false, 2000);

        // A simulated session gain (same convention as tst_LoginView.qml) is
        // exactly what BackendClient::requestCoordinatorToken achieves for
        // real once its async token exchange succeeds.
        client.restoreSession("bob", "faketoken", "fakerefresh");

        tryCompare(CameraModel, "loading", true, 2000,
                   "CameraModel must retry refresh() once the active site's client gains a session");
    }

    function test_sourceModelRetriesRefreshOnceTheActiveSiteGainsASession() {
        const client = setUpFreshCoordinatorSite("Remote Source Retry");

        tryCompare(SourceModel, "loading", false, 2000);
        client.restoreSession("bob", "faketoken", "fakerefresh");
        tryCompare(SourceModel, "loading", true, 2000,
                   "SourceModel must retry refresh() once the active site's client gains a session");
    }

    function test_destinationModelRetriesRefreshOnceTheActiveSiteGainsASession() {
        const client = setUpFreshCoordinatorSite("Remote Destination Retry");

        tryCompare(DestinationModel, "loading", false, 2000);
        client.restoreSession("bob", "faketoken", "fakerefresh");
        tryCompare(DestinationModel, "loading", true, 2000,
                   "DestinationModel must retry refresh() once the active site's client gains a session");
    }
}
