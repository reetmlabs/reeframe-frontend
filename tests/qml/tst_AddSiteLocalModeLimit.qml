// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for the single-site limit in local mode: SiteManagerView's header
// "+ Add Site" button hides once a site already exists in local mode, and a
// Coordinator connection lifts that limit entirely regardless of count.
TestCase {
    id: testCase
    name: "AddSiteLocalModeLimit"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    SiteManagerView { id: siteView; anchors.fill: parent }

    property string _localSiteId: ""

    function clearAllConnections() {
        const urls = CoordinatorManager.urls();
        for (let i = 0; i < urls.length; i++)
            CoordinatorManager.removeConnection(urls[i]);
    }

    function initTestCase() { clearAllConnections(); }

    function cleanup() {
        SiteManager.clearRemoteSitesForTest();
        clearAllConnections();
        if (testCase._localSiteId.length > 0) {
            SiteManager.removeSite(testCase._localSiteId);
            testCase._localSiteId = "";
        }
        wait(50);
    }

    function test_buttonVisibleInLocalModeWithNoSites() {
        const btn = findChild(siteView, "addSiteButton");
        verify(btn !== null, "add site button not found");
        tryCompare(btn, "visible", true);
    }

    function test_buttonHidesInLocalModeOnceOneSiteExists() {
        testCase._localSiteId = SiteManager.addSite("Local Limit Site " + Date.now());

        const btn = findChild(siteView, "addSiteButton");
        tryCompare(btn, "visible", false);
    }

    function test_coordinatorConnectionLiftsTheLimitRegardlessOfCount() {
        testCase._localSiteId = SiteManager.addSite("Local Limit Site " + Date.now());
        const btn = findChild(siteView, "addSiteButton");
        tryCompare(btn, "visible", false);

        const url = "https://coord-" + Date.now() + "-" + Math.random() + ".test";
        CoordinatorManager.addConnection(url);
        tryCompare(CoordinatorManager, "isCoordinatorMode", true);

        // Still visible: Coordinator mode has no local site-count limit, even
        // though the count that would have blocked it in local mode hasn't
        // changed (the local site is simply not shown while in Coordinator mode).
        tryCompare(btn, "visible", true);

        // Seeding a remote site (a nonzero Coordinator site count) must not bring
        // the limit back either.
        SiteManager.seedRemoteSiteForTest(url, "qmltest-be-limit", "Remote", "http://127.0.0.1:1");
        wait(50);
        compare(btn.visible, true);
    }
}
