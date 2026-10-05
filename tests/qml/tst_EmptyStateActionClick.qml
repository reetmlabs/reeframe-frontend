// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Guards against a click-swallowing bug: an EmptyState's action button
// declared *before* its ListView in z-order gets its clicks silently eaten
// by the ListView (a Flickable claims mouse presses across its full bounds
// even with zero delegates). Covers SiteManagerView, SourceListView,
// DestinationListView, and PipelineListView (CameraPanel has
// tst_CameraPanelEmptyState.qml). mouseClick (not a direct .clicked() call)
// is required because it's the only thing that exercises the
// z-order/hit-testing path.
TestCase {
    id: testCase
    name: "EmptyStateActionClick"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    // Only one of these is visible at a time (see setOnly below). With all
    // four permanently on top of each other, whichever is declared last
    // would swallow every other one's clicks, which isn't what's under test
    // here.
    property var allViews: [siteView, sourceView, destinationView, pipelineView]
    function setOnly(view) {
        for (const v of testCase.allViews)
            v.visible = (v === view);
    }

    SiteManagerView { id: siteView; anchors.fill: parent; visible: false }
    SourceListView { id: sourceView; anchors.fill: parent; visible: false }
    DestinationListView { id: destinationView; anchors.fill: parent; visible: false }
    PipelineListView { id: pipelineView; anchors.fill: parent; visible: false }

    function clickEmptyStateAction(view) {
        const btn = findChild(view, "emptyStateActionButton");
        verify(btn !== null, "empty-state action button not found");
        verify(btn.visible, "empty-state action button should be visible");
        mouseClick(btn, btn.width / 2, btn.height / 2);
    }

    function test_addSiteButtonOpensDialog() {
        testCase.setOnly(siteView);
        compare(SiteManager.count, 0);
        const dialog = findChild(siteView, "addSiteDialog");
        verify(dialog !== null, "addSiteDialog not found");
        clickEmptyStateAction(siteView);
        tryCompare(dialog, "opened", true);
        dialog.close();
    }

    function test_addSourceButtonOpensDialog() {
        testCase.setOnly(sourceView);
        SourceModel.clearTestSources();
        const dialog = findChild(sourceView, "addSourceDialog");
        verify(dialog !== null, "addSourceDialog not found");
        clickEmptyStateAction(sourceView);
        tryCompare(dialog, "opened", true);
        dialog.close();
    }

    function test_addDestinationButtonOpensDialog() {
        testCase.setOnly(destinationView);
        DestinationModel.clearTestDestinations();
        const dialog = findChild(destinationView, "addDestinationDialog");
        verify(dialog !== null, "addDestinationDialog not found");
        clickEmptyStateAction(destinationView);
        tryCompare(dialog, "opened", true);
        dialog.close();
    }

    function test_addPipelineButtonOpensDialog() {
        testCase.setOnly(pipelineView);
        PipelineModel.clearTestPipelines();
        const dialog = findChild(pipelineView, "addPipelineDialog");
        verify(dialog !== null, "addPipelineDialog not found");
        clickEmptyStateAction(pipelineView);
        tryCompare(dialog, "opened", true);
        dialog.close();
    }
}
