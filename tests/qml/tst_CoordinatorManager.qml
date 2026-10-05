// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Data-layer coverage for CoordinatorManager: switching on list emptiness,
// and that each connection's session state is independent of every other
// one. No network calls are involved here.
TestCase {
    id: testCase
    name: "CoordinatorManager"

    // Sweeps every current connection, not just this file's own two fixed
    // URLs, so leftovers from other test files get cleared too.
    function clearAllConnections() {
        const urls = CoordinatorManager.urls();
        for (let i = 0; i < urls.length; i++)
            CoordinatorManager.removeConnection(urls[i]);
    }

    function initTestCase() { clearAllConnections(); }
    function cleanup() { clearAllConnections(); }

    function test_emptyListIsLocalMode() {
        compare(CoordinatorManager.count, 0);
        compare(CoordinatorManager.isCoordinatorMode, false);
    }

    function test_addingConnectionSwitchesToCoordinatorMode() {
        CoordinatorManager.addConnection("https://coord-a.test");
        compare(CoordinatorManager.count, 1);
        compare(CoordinatorManager.isCoordinatorMode, true);
        compare(CoordinatorManager.hasSession("https://coord-a.test"), false);

        CoordinatorManager.removeConnection("https://coord-a.test");
        compare(CoordinatorManager.count, 0);
        compare(CoordinatorManager.isCoordinatorMode, false);
    }

    function test_connectionsAreIndependent() {
        CoordinatorManager.addConnection("https://coord-a.test");
        CoordinatorManager.addConnection("https://coord-b.test");

        CoordinatorManager.setSession("https://coord-a.test", "atoken", "arefresh");

        compare(CoordinatorManager.hasSession("https://coord-a.test"), true);
        compare(CoordinatorManager.hasSession("https://coord-b.test"), false);
        compare(CoordinatorManager.accessToken("https://coord-a.test"), "atoken");
        compare(CoordinatorManager.refreshToken("https://coord-a.test"), "arefresh");

        // Removing/logging out of one must never touch the other's session.
        CoordinatorManager.logout("https://coord-a.test");
        compare(CoordinatorManager.hasSession("https://coord-a.test"), false);

        CoordinatorManager.setSession("https://coord-b.test", "btoken", "brefresh");
        CoordinatorManager.removeConnection("https://coord-a.test");
        compare(CoordinatorManager.hasSession("https://coord-b.test"), true);
        compare(CoordinatorManager.accessToken("https://coord-b.test"), "btoken");

        CoordinatorManager.removeConnection("https://coord-b.test");
        compare(CoordinatorManager.count, 0);
    }
}
