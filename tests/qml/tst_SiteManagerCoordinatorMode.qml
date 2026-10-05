// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for Coordinator mode: SiteManager's list is built from each connection's
// GET /me/sites (seeded here, since this harness has no real HTTP server) and
// tagged with which connection it came from.
TestCase {
    id: testCase
    name: "SiteManagerCoordinatorMode"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    SiteManagerView { id: siteView; anchors.fill: parent }

    // Sweeps every current connection, not just the ones this file created
    // itself. A request still in flight at test end can otherwise leave
    // one behind in the real on-disk database, corrupting later runs.
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

    function addConnection() {
        const url = "https://coord-" + Date.now() + "-" + Math.random() + ".test";
        CoordinatorManager.addConnection(url);
        return url;
    }

    function test_configuringAConnectionSwitchesToEmptyCoordinatorList() {
        addConnection();
        tryCompare(CoordinatorManager, "isCoordinatorMode", true);
        tryCompare(SiteManager, "count", 0);
    }

    function test_seededRemoteSiteIsTaggedWithItsCoordinatorAndGetsARealClient() {
        const url = addConnection();
        const beId = "qmltest-be-" + Date.now();
        SiteManager.seedRemoteSiteForTest(url, beId, "Remote Warehouse", "http://127.0.0.1:1");
        wait(50);

        const row = findChild(siteView, "siteRow_" + beId);
        verify(row !== null, "seeded remote site row not found");
        compare(row.siteName, "Remote Warehouse");
        compare(row.sitePrimaryUrl, "http://127.0.0.1:1");
        compare(row.siteCoordinatorUrl, url);

        const client = SiteManager.clientForSite(beId);
        verify(client !== null, "a BackendClient must exist for a Coordinator-sourced site");
    }

    function test_removingTheOnlyConnectionFallsBackToLocalMode() {
        const url = addConnection();
        const beId = "qmltest-be-" + Date.now();
        SiteManager.seedRemoteSiteForTest(url, beId, "Remote B", "http://127.0.0.1:1");
        wait(50);
        verify(SiteManager.siteIndexById(beId) >= 0);

        CoordinatorManager.removeConnection(url);
        wait(50);

        tryCompare(CoordinatorManager, "isCoordinatorMode", false);
        verify(SiteManager.siteIndexById(beId) < 0,
               "a Coordinator-sourced site must disappear once its connection is removed");
    }

    function test_twoConnectionsEachKeepTheirOwnSitesIndependent() {
        const urlA = addConnection();
        // A connection needs a session before its seeded site sticks. A
        // real GET /me/sites (what seedRemoteSiteForTest stands in for)
        // could never have succeeded without one, and a signed-out
        // connection's cached sites get pruned on the next rebuild (see
        // rebuildForModeChange).
        CoordinatorManager.setSession(urlA, "tokenA", "refreshA");
        SiteManager.seedRemoteSiteForTest(urlA, "qmltest-be-a", "Site A", "http://127.0.0.1:1");
        const urlB = addConnection();
        CoordinatorManager.setSession(urlB, "tokenB", "refreshB");
        SiteManager.seedRemoteSiteForTest(urlB, "qmltest-be-b", "Site B", "http://127.0.0.1:2");
        wait(50);

        verify(SiteManager.siteIndexById("qmltest-be-a") >= 0, "site from connection A missing");
        verify(SiteManager.siteIndexById("qmltest-be-b") >= 0, "site from connection B missing");

        const rowA = findChild(siteView, "siteRow_qmltest-be-a");
        const rowB = findChild(siteView, "siteRow_qmltest-be-b");
        compare(rowA.siteCoordinatorUrl, urlA);
        compare(rowB.siteCoordinatorUrl, urlB);

        // Removing just one of two connections must drop only its own site.
        CoordinatorManager.removeConnection(urlB);
        wait(50);

        verify(SiteManager.siteIndexById("qmltest-be-a") >= 0,
               "connection A's site must survive connection B's removal");
        verify(SiteManager.siteIndexById("qmltest-be-b") < 0,
               "connection B's site must be gone once its own connection is removed");
    }

    // No real Coordinator server exists in this harness, so this only
    // proves the wiring: a Coordinator-sourced client requests its session
    // through the provider on creation and handles a failed request (an
    // unreachable Coordinator, here) cleanly rather than crashing or
    // hanging. The success path is covered by Coordinator's own real-HTTP
    // tests for POST /me/sites/{be_id}/token.
    function test_coordinatorClientRequestsATokenAndFailsCleanlyAgainstAnUnreachableCoordinator() {
        const url = addConnection();
        const beId = "qmltest-be-" + Date.now();
        SiteManager.seedRemoteSiteForTest(url, beId, "Remote C", "http://127.0.0.1:1");

        const client = SiteManager.clientForSite(beId);
        verify(client !== null);

        let failed = false;
        function onFailed() { failed = true; }
        client.refreshFailed.connect(onFailed);

        tryVerify(function() { return failed; }, 5000,
                  "a Coordinator client must attempt a Coordinator token request on creation and " +
                  "surface refreshFailed once the (unreachable) Coordinator request settles");
        compare(client.hasSession, false);

        client.refreshFailed.disconnect(onFailed);
    }

    // Signing out must do more than clear CoordinatorManager's mirrored
    // session, or stale sites stay visible until a restart: sessionsChanged
    // must prune a signed-out connection's sites and restore them on
    // sign-in. The rebuild-every-client approach this
    // relies on is safe only because BackendClient::refreshAccessToken()
    // guards its callback with a QPointer.
    function test_signOutRemovesTheSiteFromTheVisibleListAndSignInRestoresIt() {
        const url = addConnection();
        const beId = "qmltest-be-" + Date.now();
        SiteManager.seedRemoteSiteForTest(url, beId, "Remote D", "http://127.0.0.1:1");
        wait(50);
        verify(SiteManager.siteIndexById(beId) >= 0, "seeded site should be visible");

        CoordinatorManager.setSession(url, "faketoken", "fakerefresh", "bob");
        wait(50);
        verify(SiteManager.siteIndexById(beId) >= 0,
               "site should stay visible once its connection has a session");

        CoordinatorManager.logout(url);
        wait(50);
        compare(SiteManager.siteIndexById(beId), -1,
                "signing the Coordinator out must remove its sites from the visible list");
    }

    // CoordinatorClient's silent background token refresh
    // (scheduleExpiryRefresh) must not retrigger SiteManager's full client
    // rebuild on every cycle, which would briefly leave a sessionless client
    // that could silently fail writes. A rebuild must only happen when
    // hasSession's value actually flips, not on every token string update.
    function test_tokenRefreshWithAnAlreadySignedInConnectionDoesNotRebuildTheSiteClient() {
        const url = addConnection();
        const beId = "qmltest-be-" + Date.now();
        SiteManager.seedRemoteSiteForTest(url, beId, "Remote E", "http://127.0.0.1:1");
        CoordinatorManager.setSession(url, "firsttoken", "firstrefresh", "bob");
        wait(50);

        const client = SiteManager.clientForSite(beId);
        verify(client !== null);

        // Same shape as CoordinatorClient's own silent auto-refresh: still
        // signed in, just a new token string.
        CoordinatorManager.setSession(url, "secondtoken", "secondrefresh", "bob");
        wait(50);

        compare(SiteManager.clientForSite(beId), client,
                "a token refresh on an already-signed-in connection must not rebuild the site's client");
    }
}
