// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for signing in right after adding a Coordinator connection: the
// row's client binding must be live immediately, not frozen null. No real
// Coordinator server exists in this harness, so success is simulated via
// restoreSession() (same convention as tst_LoginView.qml).
TestCase {
    id: testCase
    name: "CoordinatorLoginFlow"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    CoordinatorManagerView { id: view; anchors.fill: parent }

    function clearAllConnections() {
        const urls = CoordinatorManager.urls();
        for (let i = 0; i < urls.length; i++)
            CoordinatorManager.removeConnection(urls[i]);
    }

    function initTestCase() { clearAllConnections(); }
    function cleanup() { clearAllConnections(); }

    function test_signInRightAfterAddingAConnectionUpdatesLiveWithoutReopeningThePage() {
        const url = "https://coord-" + Date.now() + "-" + Math.random() + ".test";
        CoordinatorManager.addConnection(url);
        wait(50);

        const row = findChild(view, "coordinatorRow_" + url);
        verify(row !== null, "coordinator row not found right after addConnection");

        // The case this guards: row.client must already be a real
        // CoordinatorClient the instant the row exists, not null.
        verify(row.client !== null,
               "row.client was null right after addConnection — the delegate " +
               "captured clientFor(url) before CoordinatorManager created the client");

        const signInBtn = findChild(view, "coordinatorSignInButton_" + url);
        verify(signInBtn !== null, "sign-in button not found");
        mouseClick(signInBtn);

        const loginDialog = findChild(view, "coordinatorLoginDialog");
        verify(loginDialog !== null, "login dialog not found");
        tryCompare(loginDialog, "opened", true);
        verify(loginDialog.client !== null,
               "loginDialog.client was null — signIn() would have been a silent no-op");

        loginDialog.client.restoreSession("bob", "faketoken", "fakerefresh");

        // Reactive without recreating the view/row: hasSession flips and the
        // label updates on the same delegate instance.
        tryCompare(row, "hasSession", true);
        const sessionLabel = findChild(view, "coordinatorRowSessionLabel_" + url);
        verify(sessionLabel !== null, "session label not found");
        tryCompare(sessionLabel, "text", qsTr("Signed in as %1").arg("bob"));

        // CoordinatorLoginDialog.onSessionChanged closes the popup on success.
        tryCompare(loginDialog, "opened", false);
    }
}
