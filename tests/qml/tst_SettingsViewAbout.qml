// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Covers the About tab: FE version display, the connected-sites list
// (backed directly by SiteManager's model), and third-party license text.
TestCase {
    id: testCase
    name: "SettingsViewAbout"
    width: 800
    height: 600
    visible: true
    when: windowShown

    SettingsView {
        id: settingsView
        anchors.fill: parent
    }

    function cleanup() {
        settingsView.currentTab = 0;
    }

    function test_versionTextShowsApplicationVersion() {
        settingsView.currentTab = 2;

        const versionText = findChild(settingsView, "aboutVersionText");
        verify(versionText !== null, "version text not found");
        compare(versionText.text, Qt.application.version);
    }

    function test_noSitesTextVisibleWhenNoSitesConnected() {
        settingsView.currentTab = 2;

        const noSitesText = findChild(settingsView, "aboutNoSitesText");
        verify(noSitesText !== null, "no-sites text not found");
        compare(noSitesText.visible, SiteManager.count === 0);
    }

    function test_addedSiteAppearsInConnectedSitesList() {
        settingsView.currentTab = 2;

        const id = SiteManager.addSite("About Tab Test Site " + Date.now());
        wait(150);

        const row = findChild(settingsView, "aboutSiteRow_" + id);
        verify(row !== null, "site row not found in About tab");

        const versionText = findChild(row, "aboutSiteVersionText");
        verify(versionText !== null, "site version text not found");
        compare(versionText.text, qsTr("Not connected"));

        SiteManager.removeSite(id);
    }

    function test_licenseTextsMentionQtAndTablerIcons() {
        settingsView.currentTab = 2;

        const qtLicense = findChild(settingsView, "aboutQtLicenseText");
        verify(qtLicense !== null, "Qt license text not found");
        verify(qtLicense.text.indexOf("LGPLv3") !== -1, "Qt license text must mention LGPLv3");

        const tablerLicense = findChild(settingsView, "aboutTablerLicenseText");
        verify(tablerLicense !== null, "Tabler Icons license text not found");
        verify(tablerLicense.text.indexOf("MIT") !== -1, "Tabler Icons license text must mention MIT");
    }
}
