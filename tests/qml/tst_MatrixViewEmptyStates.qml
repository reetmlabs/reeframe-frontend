// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Covers MatrixView's two "no profile" empty states: with no site connected
// the "+ New Profile" button must be hidden (profiles require an active
// site), but it must still work once a site's auto-created default profile
// is deleted.
TestCase {
    id: testCase
    name: "MatrixViewEmptyStates"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    MatrixView {
        id: matrixView
        anchors.fill: parent
    }

    property string _siteId: ""
    property int _previousActiveIndex: 0

    function cleanup() {
        SiteManager.activeSiteIndex = testCase._previousActiveIndex;
        if (testCase._siteId.length > 0) {
            SiteManager.removeSite(testCase._siteId);
            testCase._siteId = "";
        }
    }

    function test_noSiteShowsMessageWithoutAnActionableButton() {
        compare(TileLayoutModel.activeSiteId, "", "expected no active site for this test");

        const noSiteState = findChild(matrixView, "matrixNoSiteEmptyState");
        verify(noSiteState !== null, "no-site empty state not found");
        verify(noSiteState.visible, "no-site empty state should be visible with no site");

        const btn = findChild(noSiteState, "emptyStateActionButton");
        verify(btn === null || !btn.visible,
               "no actionable button should be offered without a site");
    }

    function test_deletingOnlyProfileThenCreatingANewOneWorks() {
        testCase._previousActiveIndex = SiteManager.activeSiteIndex;
        const id = SiteManager.addSite("Matrix Empty State Test " + Date.now());
        SiteManager.addNode(id, "http://127.0.0.1:1");
        SiteManager.activeSiteIndex = SiteManager.siteIndexById(id);
        testCase._siteId = id;

        tryVerify(function() { return TileLayoutModel.activeProfileId.length > 0; },
                  2000, "a default profile should be auto-created for the new site");

        TileLayoutModel.deleteProfile(TileLayoutModel.activeProfileId);
        compare(TileLayoutModel.activeProfileId, "", "profile should be cleared after deleting it");

        const noProfileState = findChild(matrixView, "matrixNoProfileEmptyState");
        verify(noProfileState !== null, "no-profile empty state not found");
        tryVerify(function() { return noProfileState.visible; },
                  2000, "no-profile empty state should be visible with a site but no profile");

        const btn = findChild(noProfileState, "emptyStateActionButton");
        verify(btn !== null, "new-profile button not found");
        verify(btn.visible, "new-profile button should be visible with a site connected");

        mouseClick(btn, btn.width / 2, btn.height / 2);

        const dialog = findChild(matrixView, "saveProfileDialog");
        verify(dialog !== null, "save profile dialog not found");
        tryCompare(dialog, "opened", true);
    }
}
