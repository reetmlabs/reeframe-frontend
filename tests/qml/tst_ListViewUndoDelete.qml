// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for the undoable-delete pattern applied to SourceListView,
// DestinationListView, and SiteManagerView, the same pattern already
// covered end-to-end for CameraPanel in tst_CameraUndoDelete.qml. Each view
// is instantiated standalone (none of them reference StackView), matching
// the pattern already used for DagCanvas.
TestCase {
    id: testCase
    name: "ListViewUndoDelete"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    SourceListView {
        id: sourceView
        anchors.fill: parent
    }

    DestinationListView {
        id: destinationView
        anchors.fill: parent
    }

    SiteManagerView {
        id: siteView
        anchors.fill: parent
    }

    function test_sourceDeleteHidesRowUntilUndone() {
        SourceModel.clearTestSources();
        const id = "qmltest-source-undo-" + Date.now();
        SourceModel.insertTestSource(id, "Undo Source");
        wait(50);

        const row = findChild(sourceView, "sourceRow_" + id);
        verify(row !== null, "source row not found");

        sourceView.requestDeleteSource(id, "Undo Source");
        tryCompare(row, "visible", false);
        verify(SourceModel.sourceIndexById(id) >= 0,
               "source must still exist in the model during the undo window");

        sourceView.undoDelete([id]);
        tryCompare(row, "visible", true);
    }

    function test_destinationDeleteHidesRowUntilUndone() {
        DestinationModel.clearTestDestinations();
        const id = "qmltest-dest-undo-" + Date.now();
        DestinationModel.insertTestDestination(id, "Undo Destination");
        wait(50);

        const row = findChild(destinationView, "destinationRow_" + id);
        verify(row !== null, "destination row not found");

        destinationView.requestDeleteDestination(id, "Undo Destination");
        tryCompare(row, "visible", false);

        destinationView.undoDelete([id]);
        tryCompare(row, "visible", true);
    }

    // SiteManager.removeSite() has no network gate (sites are purely local
    // DB rows), so this is the one case here that can verify the delete
    // actually completes for real once the undo window elapses.
    function test_siteRemoveCommitsForRealAfterWindowElapses() {
        const id = SiteManager.addSite("Undo Site " + Date.now());
        wait(150);

        const row = findChild(siteView, "siteRow_" + id);
        verify(row !== null, "site row not found");

        siteView.undoWindowMs = 80;
        siteView.requestRemoveSite(id, "Undo Site");
        tryCompare(row, "visible", false);

        tryVerify(function() { return SiteManager.siteIndexById(id) === -1; }, 2000,
                  "site must actually be removed once the undo window elapses without an undo");
    }

    function test_siteRemoveUndoneRestoresRow() {
        const id = SiteManager.addSite("Undo Restore Site " + Date.now());
        wait(150);

        const row = findChild(siteView, "siteRow_" + id);
        verify(row !== null, "site row not found");

        siteView.undoWindowMs = 5000;
        siteView.requestRemoveSite(id, "Undo Restore Site");
        tryCompare(row, "visible", false);

        siteView.undoDelete([id]);
        tryCompare(row, "visible", true);
        verify(SiteManager.siteIndexById(id) >= 0, "undone removal must leave the site intact");

        // Not exercised by this test's assertions, but left uncleaned this
        // accumulates permanently in the test app.db across every run,
        // eventually growing the ListView enough that later-added rows
        // fall outside the realized delegate range and findChild() fails.
        SiteManager.removeSite(id);
    }
}
