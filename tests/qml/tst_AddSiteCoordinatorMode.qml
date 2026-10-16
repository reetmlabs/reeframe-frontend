// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// In Coordinator mode sites come only from GET /me/sites, so SiteManager must
// refuse local sites and SiteManagerView's empty state must not offer one.
TestCase {
    id: testCase
    name: "AddSiteCoordinatorMode"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    SiteManagerView { id: siteView; anchors.fill: parent }

    Instantiator {
        id: siteRows
        model: SiteManager
        delegate: QtObject { required property int siteNodeCount }
    }

    property string _createdSiteId: ""

    function clearAllConnections() {
        const urls = CoordinatorManager.urls();
        for (let i = 0; i < urls.length; i++)
            CoordinatorManager.removeConnection(urls[i]);
    }

    function enterCoordinatorMode() {
        const url = "https://coord-" + Date.now() + "-" + Math.random() + ".test";
        CoordinatorManager.addConnection(url);
        tryCompare(CoordinatorManager, "isCoordinatorMode", true);
        return url;
    }

    function initTestCase() { clearAllConnections(); }

    function cleanup() {
        SiteManager.clearRemoteSitesForTest();
        clearAllConnections();
        if (testCase._createdSiteId.length > 0) {
            SiteManager.removeSite(testCase._createdSiteId);
            testCase._createdSiteId = "";
        }
        wait(50);
    }

    function test_addSiteIsRefused() {
        enterCoordinatorMode();
        const before = SiteManager.count;

        testCase._createdSiteId = SiteManager.addSite("Refused Site " + Date.now());

        compare(testCase._createdSiteId, "");
        compare(SiteManager.count, before);
    }

    function test_addNodeIsRefusedOnARemoteSite() {
        const url = enterCoordinatorMode();
        SiteManager.seedRemoteSiteForTest(url, "qmltest-be-addnode", "Remote", "http://127.0.0.1:1");
        tryCompare(siteRows, "count", 1);
        compare(siteRows.objectAt(0).siteNodeCount, 1);

        SiteManager.addNode("qmltest-be-addnode", "http://127.0.0.1:2");

        compare(siteRows.objectAt(0).siteNodeCount, 1);
    }

    function test_emptyStateOffersNoAddSiteAction() {
        enterCoordinatorMode();
        tryCompare(SiteManager, "count", 0);

        const empty = findChild(siteView, "sitesEmptyState");
        verify(empty !== null, "sites empty state not found");
        tryCompare(empty, "visible", true);
        const action = findChild(empty, "emptyStateActionButton");
        verify(action !== null, "empty state action button not found");
        compare(action.visible, false);
    }
}
