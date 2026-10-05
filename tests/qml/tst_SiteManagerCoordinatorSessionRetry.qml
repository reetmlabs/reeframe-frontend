// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for a startup delay: refreshCoordinatorSites() itself never
// retries a failed GET /me/sites (e.g. a 401 from a stale persisted
// Coordinator token at launch), and the unrelated
// kCoordinatorRefreshIntervalMs "list still empty" timer can take up to 5s
// to fire. So SiteManager must also retry immediately when a Coordinator
// connection's own session actually changes (sign-in, or a silent
// background token refresh), and not just on an explicit sign-in/out.
// CoordinatorManager.sessionsChanged deliberately doesn't fire for a silent
// refresh, to avoid an unrelated full rebuild on every routine one.
TestCase {
    id: testCase
    name: "SiteManagerCoordinatorSessionRetry"
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

    function test_coordinatorSessionChangeRetriesRefreshCoordinatorSites() {
        const url = "https://coord-retry-" + Date.now() + "-" + Math.random() + ".test";
        CoordinatorManager.addConnection(url);
        wait(50);

        const coordClient = CoordinatorManager.clientFor(url);
        verify(coordClient !== null, "coordinator client not found");
        compare(coordClient.hasSession, false, "fresh connection shouldn't have a session yet");

        const before = SiteManager.coordinatorRefreshAttemptCountForTest();

        // A simulated session gain/refresh (same convention as
        // tst_SiteModelsSessionRetry.qml) is exactly what a real sign-in or
        // a silent background token refresh achieves.
        coordClient.restoreSession("bob", "faketoken", "fakerefresh");

        tryVerify(function() { return SiteManager.coordinatorRefreshAttemptCountForTest() >= before + 1 },
                  2000,
                  "SiteManager must retry refreshCoordinatorSites() when a Coordinator " +
                  "connection's session changes, not just wait for the unrelated timer")
    }

    function test_newlyAddedConnectionAlsoGetsRetryWiring() {
        // wireCoordinatorSessionRetries() must also run for a connection
        // added AFTER SiteManager was constructed (via
        // rebuildForModeChange(), triggered by CoordinatorManager.countChanged),
        // not just ones present at startup.
        const url = "https://coord-retry-late-" + Date.now() + "-" + Math.random() + ".test";
        CoordinatorManager.addConnection(url)
        wait(50)

        const coordClient = CoordinatorManager.clientFor(url)
        verify(coordClient !== null, "coordinator client not found")

        const before = SiteManager.coordinatorRefreshAttemptCountForTest()
        coordClient.restoreSession("bob", "faketoken", "fakerefresh")

        tryVerify(function() { return SiteManager.coordinatorRefreshAttemptCountForTest() >= before + 1 },
                  2000,
                  "a connection added after startup must still get retry wiring")
    }
}
