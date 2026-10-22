// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// The backend is polled on /health every few seconds. A poll that reports
// nothing new must not re-fetch or reset the camera list, since a reset makes
// every tile re-sync its stream. The list is instead re-fetched on its own
// timer while the site is Online and signed in, and only reset when the
// fetched list actually differs.
TestCase {
    id: testCase
    name: "CameraListBackgroundRefresh"
    visible: true
    when: windowShown

    property var client: null

    SignalSpy { id: versionSpy; signalName: "versionChanged" }
    SignalSpy { id: activeSiteSpy; target: SiteManager; signalName: "activeSiteChanged" }
    SignalSpy { id: resetSpy; target: CameraModel; signalName: "modelReset" }

    function clearAllConnections() {
        const urls = CoordinatorManager.urls();
        for (let i = 0; i < urls.length; i++)
            CoordinatorManager.removeConnection(urls[i]);
    }

    function init() {
        clearAllConnections();
        const url = "https://coord-" + Date.now() + "-" + Math.random() + ".test";
        CoordinatorManager.addConnection(url);
        const beId = "qmltest-be-" + Date.now() + "-" + Math.random();
        SiteManager.seedRemoteSiteForTest(url, beId, "Background Refresh", EmptyBackend.url);
        SiteManager.activeSiteIndex = SiteManager.siteIndexById(beId);
        client = SiteManager.clientForSite(beId);
        verify(client !== null, "site client not found");

        tryCompare(SiteManager, "activeSiteStatus", 2, 3000);
        tryCompare(CameraModel, "loading", false, 2000);
        // Selecting the site and its first Online status each fetch the
        // camera list, and the second reply can land after loading clears.
        // Wait for the request count to settle before tests read it.
        let settled = EmptyBackend.requestCount;
        do {
            settled = EmptyBackend.requestCount;
            wait(300);
        } while (EmptyBackend.requestCount !== settled);

        versionSpy.target = client;
        versionSpy.clear();
        activeSiteSpy.clear();
        resetSpy.clear();
    }

    function cleanup() {
        CameraModel.refreshIntervalMs = 30000;
        EmptyBackend.version = "";
        versionSpy.target = null;
        client = null;
        SiteManager.clearRemoteSitesForTest();
        clearAllConnections();
        CameraModel.clearTestCameras();
        wait(50);
    }

    function pollHealth() {
        const before = EmptyBackend.requestCountFor("/health");
        client.pollHealthForTest();
        tryVerify(() => EmptyBackend.requestCountFor("/health") > before, 2000);
        wait(100);
    }

    function test_unchangedHealthPollDoesNotReloadCameras() {
        const camerasBefore = EmptyBackend.requestCountFor("/cameras");

        pollHealth();
        pollHealth();

        compare(versionSpy.count, 0, "an unchanged version must not emit versionChanged");
        compare(activeSiteSpy.count, 0, "an unchanged health poll must not re-emit activeSiteChanged");
        compare(EmptyBackend.requestCountFor("/cameras"), camerasBefore,
                "an unchanged health poll must not re-fetch the camera list");
        compare(resetSpy.count, 0);
    }

    function test_versionChangeEmitsOnce() {
        EmptyBackend.version = "1.2.3";
        pollHealth();
        compare(client.version, "1.2.3");
        compare(versionSpy.count, 1);

        pollHealth();
        compare(versionSpy.count, 1, "polling the same version again must not emit");
    }

    function test_unchangedListSkipsReset() {
        compare(CameraModel.count, 0);
        const camerasBefore = EmptyBackend.requestCountFor("/cameras");

        CameraModel.refresh();
        tryVerify(() => EmptyBackend.requestCountFor("/cameras") > camerasBefore, 2000);
        wait(100);
        compare(resetSpy.count, 0, "re-fetching an identical list must not reset the model");

        CameraModel.insertTestCamera("bgRefreshCam", "Gone Camera");
        resetSpy.clear();
        CameraModel.refresh();
        tryCompare(resetSpy, "count", 1, 2000);
        compare(CameraModel.count, 0, "a changed list must still replace the model");
    }

    function test_timerRefreshesOnlyWhileSignedIn() {
        verify(!client.hasSession, "the seeded site should start without a session");
        CameraModel.refreshIntervalMs = 100;

        let before = EmptyBackend.requestCountFor("/cameras");
        wait(500);
        compare(EmptyBackend.requestCountFor("/cameras"), before,
                "the timer must stay idle while the site has no session");

        client.restoreSession("bob", "faketoken", "fakerefresh");
        wait(100);
        before = EmptyBackend.requestCountFor("/cameras");
        tryVerify(() => EmptyBackend.requestCountFor("/cameras") >= before + 2, 3000,
                  "the timer must re-fetch the camera list while signed in");
    }
}
