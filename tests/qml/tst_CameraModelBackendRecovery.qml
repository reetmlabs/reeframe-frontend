// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// CameraModel.backendRecovered() fires on every Error-to-Online transition
// of the active site's client, with no minimum outage duration, since a
// backend restart kills an on-demand relay no matter how briefly it was down.
TestCase {
    id: testCase
    name: "CameraModelBackendRecovery"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    SiteManagerView { id: siteView; anchors.fill: parent }

    SignalSpy {
        id: recoveredSpy
        target: CameraModel
        signalName: "backendRecovered"
    }

    function clearAllConnections() {
        const urls = CoordinatorManager.urls();
        for (let i = 0; i < urls.length; i++)
            CoordinatorManager.removeConnection(urls[i]);
    }

    function initTestCase() {
        clearAllConnections();
    }

    function cleanup() {
        SiteManager.clearRemoteSitesForTest();
        clearAllConnections();
        recoveredSpy.clear();
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

    function test_firesOnEveryRecoveryFromError() {
        const client = setUpFreshCoordinatorSite("Recovers From Error");
        tryCompare(CameraModel, "loading", false, 2000);

        client.setStatusForTest(3); // Error
        client.setStatusForTest(2); // Online

        tryCompare(recoveredSpy, "count", 1, 1000,
                   "any recovery from Error to Online must fire backendRecovered");
    }

    function test_doesNotFireAgainWithoutAnInterveningError() {
        const client = setUpFreshCoordinatorSite("Already Online");
        tryCompare(CameraModel, "loading", false, 2000);

        client.setStatusForTest(3); // Error
        client.setStatusForTest(2); // Online
        tryCompare(recoveredSpy, "count", 1, 1000);

        client.setStatusForTest(2); // Online again, no error in between
        wait(50);

        compare(recoveredSpy.count, 1,
                "reasserting Online without a new outage must not fire backendRecovered again");
    }
}
