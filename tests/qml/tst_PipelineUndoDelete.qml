// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for pipeline delete's undo flow. PipelineListView's row is
// destroyed and recreated by App.qml's StackView on navigation just like
// Source/Destination/Site, so it defers through the same global
// PendingDeletes singleton (see PendingDeletes.qml) rather than a view-local
// PendingDeleteQueue/Toast pair.
TestCase {
    id: testCase
    name: "PipelineUndoDelete"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    App {
        id: appUnderTest
        anchors.fill: parent
    }

    function initTestCase() {
        PipelineModel.clearTestPipelines();
    }

    function test_confirmingDeleteHidesRowUntilUndone() {
        const id = "qmltest-pipeline-undo-" + Date.now();
        PipelineModel.insertTestPipeline(id, "Undo Pipeline");
        wait(50);

        const stack = findChild(appUnderTest, "overlayStack");
        verify(stack !== null, "overlay stack not found");
        stack.clear();

        // Navigate and expand the row the same way the command palette does
        // (already proven in tst_CommandPalette.qml) rather than constructing
        // view URLs by hand.
        const palette = findChild(appUnderTest, "commandPalette");
        verify(palette !== null, "command palette not found");
        palette.pipelineActivated(id);
        wait(50);

        const listRow = findChild(appUnderTest, "pipelineRow_" + id);
        verify(listRow !== null, "pipeline row not found in list view");

        const listView = stack.currentItem;
        verify(listView !== null && listView.expandedId === id,
               "row must be expanded by the command palette jump");

        // Drive the same path the "Delete" button + ConfirmDialog would;
        // simulating the ConfirmDialog's own click chain isn't the point
        // of this test.
        listView.requestDeletePipeline(id, "Undo Pipeline");

        tryCompare(listRow, "visible", false);
        verify(PendingDeletes.isPending(id));

        // Undo via the same global toast the "Undo" click uses.
        const toast = findChild(appUnderTest, "globalToast");
        verify(toast !== null, "global toast not found");
        toast.actionTriggered([id]);

        tryCompare(listRow, "visible", true);
        verify(!PendingDeletes.isPending(id));
        compare(PipelineModel.pipelineById(id).pipelineId, id,
                "undone delete must leave the pipeline exactly as it was");
    }
}
