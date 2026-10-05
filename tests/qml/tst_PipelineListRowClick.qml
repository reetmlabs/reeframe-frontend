// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// A bare "StackView.view" reference resolves to null from anywhere but a
// pushed page's own root item (even a page's direct child sees null), so a
// nested MouseArea using the unqualified form silently no-ops on the
// resulting TypeError. The pipeline views use the qualified
// "root.StackView.view" form instead; see PipelineListView.qml's "Edit
// graph" button.
TestCase {
    id: testCase
    name: "PipelineListRowClick"
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

    function test_clickingRowExpandsItInPlace() {
        const id = "qmltest-pipeline-rowclick-" + Date.now();
        PipelineModel.insertTestPipeline(id, "Row Click Pipeline");
        wait(50);

        const stack = findChild(appUnderTest, "overlayStack");
        verify(stack !== null, "overlay stack not found");
        stack.clear();

        const palette = findChild(appUnderTest, "commandPalette");
        verify(palette !== null, "command palette not found");
        palette.pipelineActivated(id);
        wait(50);

        const listView = stack.currentItem;
        verify(listView !== null, "pipeline list view not on top of the stack");
        listView.expandedId = "";

        const listRow = findChild(appUnderTest, "pipelineRow_" + id);
        verify(listRow !== null, "pipeline row not found");
        verify(listRow.visible, "pipeline row not visible");

        const stackDepthBefore = stack.depth;
        mouseClick(listRow, listRow.width / 2, 26);
        wait(50);
        compare(stack.depth, stackDepthBefore, "clicking the row must expand it in place, not push a new page");
        compare(listView.expandedId, id, "clicking the row must expand it");

        // Regression target: "Edit graph" lives deep inside the expanded
        // row and must still reach the page's own StackView via a qualified
        // "root.StackView.view.push(...)".
        // The panel opens with a clipped height animation, and a click on a
        // part of the button that is still clipped never reaches it.
        const detailPanel = findChild(appUnderTest, "pipelineDetailPanel_" + id);
        verify(detailPanel !== null, "pipeline detail panel not found");
        tryVerify(function() { return detailPanel.fullyExpanded; }, 2000,
                  "the detail panel never finished expanding");

        const graphButton = findChild(appUnderTest, "pipelineEditGraphButton_" + id);
        verify(graphButton !== null, "Edit graph button not found in the expanded row");
        mouseClick(graphButton, graphButton.width / 2, graphButton.height / 2);
        // A fixed wait() here is flaky under CI's slower/more loaded runner:
        // the pushed PipelineEditorView also kicks off a real network load in
        // its own Component.onCompleted, so how long the push actually takes
        // to settle isn't fixed. Poll instead of guessing a duration.
        tryVerify(function() { return stack.depth > stackDepthBefore; }, 5000,
                  "clicking Edit graph did not push the pipeline editor");
        compare(stack.currentItem.pipelineId, id);
    }
}
