// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Covers the sign-in path when a Coordinator connection has no session:
// App.qml must pop the Coordinator sign-in dialog on top of the still-usable
// shell, driven purely by CoordinatorManager's connection state (SiteManager
// can't be the trigger: it only learns about a site via a Coordinator-
// authenticated request in the first place).
TestCase {
    id: testCase
    name: "CoordinatorSignInGate"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    App { id: appUnderTest; anchors.fill: parent }

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

    function test_unsignedCoordinatorConnectionPopsSignInDialogWithoutBlockingTheShell() {
        const url = "https://coord-" + Date.now() + "-" + Math.random() + ".test";
        CoordinatorManager.addConnection(url);

        const loginView = findChild(appUnderTest, "loginView");
        verify(loginView !== null, "loginView not found");
        compare(loginView.visible, false, "per-BE LoginView must not show for Coordinator mode");

        const topBar = findChild(appUnderTest, "topBar");
        verify(topBar !== null, "topBar not found");
        compare(topBar.visible, true, "TopBar must stay visible (no full-screen gate)");

        const dialog = findChild(appUnderTest, "coordinatorSignInDialog");
        verify(dialog !== null, "coordinator sign-in dialog not found");
        tryCompare(dialog, "opened", true);
        compare(dialog.coordinatorUrl, url);
        verify(dialog.client !== null, "dialog.client was null");
    }

    // Guards against CoordinatorManager.logout() only clearing its own
    // mirrored copy while leaving the live CoordinatorClient's session
    // (the authoritative one) intact, which would make hasSession() keep
    // reporting true and this dialog would never come back after sign-out.
    function test_signOutOfCoordinatorRetriggersTheSignInDialog() {
        const url = "https://coord-" + Date.now() + "-" + Math.random() + ".test";
        CoordinatorManager.addConnection(url);

        const dialog = findChild(appUnderTest, "coordinatorSignInDialog");
        tryCompare(dialog, "opened", true);
        dialog.client.restoreSession("bob", "faketoken", "fakerefresh");
        tryCompare(dialog, "opened", false);
        verify(CoordinatorManager.hasSession(url), "sign-in simulation didn't take");

        CoordinatorManager.logout(url);

        compare(CoordinatorManager.hasSession(url), false,
                "CoordinatorManager.hasSession() must reflect the sign-out immediately");
        tryCompare(dialog, "opened", true);
        compare(dialog.coordinatorUrl, url);
    }

    // Once the auto-popped dialog is cancelled, nothing re-triggers it on
    // its own (by design, see the Connections block in App.qml), so there
    // must be a manual way back in without restarting the app.
    function test_cancellingTheDialogLeavesASignInButtonToReopenIt() {
        const url = "https://coord-" + Date.now() + "-" + Math.random() + ".test";
        CoordinatorManager.addConnection(url);
        const beId = "qmltest-be-" + Date.now();
        SiteManager.seedRemoteSiteForTest(url, beId, "Gated Remote Site", "http://127.0.0.1:1");
        SiteManager.activeSiteIndex = SiteManager.siteIndexById(beId);
        wait(50);

        const dialog = findChild(appUnderTest, "coordinatorSignInDialog");
        tryCompare(dialog, "opened", true);
        dialog.close();
        tryCompare(dialog, "opened", false);

        const profilePopup = findChild(appUnderTest, "profilePopup");
        verify(profilePopup !== null, "profile popup not found");
        profilePopup.open();

        const signInBtn = findChild(appUnderTest, "profileSignInButton");
        verify(signInBtn !== null, "sign-in button not found");
        verify(signInBtn.visible, "sign-in button should be visible while signed out");
        // Direct signal invocation, not a simulated click, since a Popup
        // opened programmatically the same frame has unsettled geometry
        // (see tst_SiteAuthDisplay.qml's own note on this exact issue).
        signInBtn.clicked();

        tryCompare(dialog, "opened", true);
        compare(dialog.coordinatorUrl, url);
    }

    // The sign-in button's visibility must not depend on
    // SiteManager.activeSiteCoordinatorUrl: signing out prunes the active site
    // away entirely (see SiteManager::rebuildForModeChange), so that property
    // goes empty right when the button is needed most, hiding the only way
    // back in without a restart.
    function test_signInButtonStaysAvailableAfterSignOutPrunesTheActiveSite() {
        const url = "https://coord-" + Date.now() + "-" + Math.random() + ".test";
        CoordinatorManager.addConnection(url);
        const beId = "qmltest-be-" + Date.now();
        SiteManager.seedRemoteSiteForTest(url, beId, "Gated Remote Site", "http://127.0.0.1:1");
        SiteManager.activeSiteIndex = SiteManager.siteIndexById(beId);
        wait(50);

        const dialog = findChild(appUnderTest, "coordinatorSignInDialog");
        tryCompare(dialog, "opened", true);
        dialog.client.restoreSession("bob", "faketoken", "fakerefresh");
        tryCompare(dialog, "opened", false);
        wait(50);

        CoordinatorManager.logout(url);
        wait(50);
        compare(SiteManager.activeSiteCoordinatorUrl, "",
                "signing out should prune the active site entirely");

        // The sign-out itself may already auto-reopen the dialog. Cancel
        // it to simulate the user dismissing it once, same as the scenario
        // this guards.
        if (dialog.opened)
            dialog.close();
        tryCompare(dialog, "opened", false);

        const profilePopup = findChild(appUnderTest, "profilePopup");
        profilePopup.open();
        const signInBtn = findChild(appUnderTest, "profileSignInButton");
        verify(signInBtn !== null, "sign-in button not found");
        verify(signInBtn.visible,
               "sign-in button must stay visible even though sign-out pruned the active site");
        signInBtn.clicked();

        tryCompare(dialog, "opened", true);
        compare(dialog.coordinatorUrl, url);
    }
}
