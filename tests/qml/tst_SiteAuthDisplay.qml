// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Covers sign-in-state display: SiteManagerView's per-row session label and
// TopBar's profile popover. Uses the same unreachable-node pattern as
// tst_LoginView.qml, which is known not to destabilize other tests.
TestCase {
    id: testCase
    name: "SiteAuthDisplay"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    App { id: appUnderTest; anchors.fill: parent }

    property string _siteId: ""
    property int _previousActiveIndex: 0

    function cleanup() {
        SiteManager.activeSiteIndex = testCase._previousActiveIndex;
        if (testCase._siteId.length > 0) {
            SiteManager.removeSite(testCase._siteId);
            testCase._siteId = "";
        }
    }

    function makeActiveSite(name) {
        testCase._previousActiveIndex = SiteManager.activeSiteIndex;
        const id = SiteManager.addSite(name + " " + Date.now());
        SiteManager.addNode(id, "http://127.0.0.1:1");
        SiteManager.activeSiteIndex = SiteManager.siteIndexById(id);
        testCase._siteId = id;
        return id;
    }

    // Tests the same hasSession/username expression that drives
    // SiteManagerView's session label directly, since reaching the
    // rendered label needs sidebar navigation with no existing test setup.
    function test_newSiteHasNoSessionByDefault() {
        const id = makeActiveSite("Display Test Site");
        const client = SiteManager.clientForSite(id);
        verify(client !== null, "client not found for new site");
        compare(client.hasSession, false);
    }

    function test_topBarPopoverShowsSignedInUserAndSignOutWorks() {
        const id = makeActiveSite("Popover Test Site");
        const client = SiteManager.clientForSite(id);
        client.restoreSession("opuser", "faketoken", "fakerefresh");

        const avatarMouse = findChild(appUnderTest, "profilePopup");
        verify(avatarMouse !== null, "profile popup not found");

        // Open the popover the same way a click would.
        avatarMouse.open();

        const usernameText = findChild(appUnderTest, "profileUsernameText");
        verify(usernameText !== null, "username text not found");
        tryCompare(usernameText, "text", "opuser");

        const signOutBtn = findChild(appUnderTest, "profileSignOutButton");
        verify(signOutBtn !== null, "sign out button not found");
        verify(signOutBtn.visible, "sign out button should be visible while signed in");

        // A simulated mouseClick on a button inside a Popup opened this same
        // frame is unreliable since its geometry isn't settled yet, so
        // invoke the clicked signal directly instead.
        signOutBtn.clicked();

        tryCompare(client, "hasSession", false);
    }
}
