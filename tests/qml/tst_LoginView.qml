// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Covers the sign-in gate: App.qml blocks the whole shell behind LoginView
// whenever the active site has a node but no session, and clears once one
// exists. No real backend is reachable in this sandbox, so signIn() itself
// isn't exercised here.
TestCase {
    id: testCase
    name: "LoginView"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    App {
        id: appUnderTest
        anchors.fill: parent
    }

    property string _siteId: ""
    property int _previousActiveIndex: 0

    function loginView() { return findChild(appUnderTest, "loginView"); }

    function setupSiteNeedingLogin() {
        testCase._previousActiveIndex = SiteManager.activeSiteIndex;
        const id = SiteManager.addSite("Login Test Site " + Date.now());
        SiteManager.addNode(id, "http://127.0.0.1:1"); // unreachable, harmless
        SiteManager.activeSiteIndex = SiteManager.siteIndexById(id);
        testCase._siteId = id;
        return id;
    }

    function cleanup() {
        SiteManager.activeSiteIndex = testCase._previousActiveIndex;
        if (testCase._siteId.length > 0) {
            SiteManager.removeSite(testCase._siteId);
            testCase._siteId = "";
        }
    }

    function test_needsLoginShowsLoginViewForUnauthenticatedSite() {
        setupSiteNeedingLogin();
        tryCompare(appUnderTest, "needsLogin", true);
        compare(loginView().visible, true);
    }

    function test_restoringSessionHidesLoginView() {
        const id = setupSiteNeedingLogin();
        const client = SiteManager.clientForSite(id);
        client.restoreSession("admin", "faketoken", "fakerefresh");

        tryCompare(appUnderTest, "needsLogin", false);
        compare(loginView().visible, false);
    }

    function test_connectButtonDisabledUntilBothFieldsFilled() {
        setupSiteNeedingLogin();
        tryCompare(appUnderTest, "needsLogin", true);

        const view = loginView();
        const connectBtn = findChild(view, "loginConnectButton");
        const userField = findChild(view, "loginUsernameField");
        const passField = findChild(view, "loginPasswordField");
        verify(connectBtn !== null && userField !== null && passField !== null,
              "login controls not found");

        compare(connectBtn.enabled, false);
        userField.text = "admin";
        compare(connectBtn.enabled, false);
        passField.text = "secret";
        compare(connectBtn.enabled, true);
    }

    function test_signInFailedShowsErrorMessage() {
        setupSiteNeedingLogin();
        tryCompare(appUnderTest, "needsLogin", true);

        const view = loginView();
        view.client.signInFailed("invalid username or password");

        compare(view.errorMessage, "invalid username or password");
        compare(view.signingIn, false);

        const errorText = findChild(view, "loginErrorText");
        verify(errorText !== null && errorText.visible, "error text not shown");
    }
}
