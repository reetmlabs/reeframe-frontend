// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for the pipeline list row's error/warning summary (see
// PipelineListView.qml's "pipelineRowValidationSummary_" Text), split by
// severity rather than a single merged count, since only errors block
// enabling.
TestCase {
    id: testCase
    name: "PipelineListValidationSummary"
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

    function test_1_listRowsReflectEachPipelinesValidationState() {
        const cleanId = "qmltest-validation-summary-clean-" + Date.now();
        const brokenId = "qmltest-validation-summary-issues-" + Date.now();
        PipelineModel.insertTestPipeline(cleanId, "Clean Pipeline");
        PipelineModel.insertTestPipeline(brokenId, "Broken Pipeline", 2, 1);

        const palette = findChild(appUnderTest, "commandPalette");
        verify(palette !== null, "command palette not found");
        palette.pipelineActivated(cleanId);
        wait(50);

        const cleanSummary = findChild(appUnderTest, "pipelineRowValidationSummary_" + cleanId);
        verify(cleanSummary !== null, "validation summary not found for the clean pipeline");
        compare(cleanSummary.visible, false);

        const brokenSummary = findChild(appUnderTest, "pipelineRowValidationSummary_" + brokenId);
        verify(brokenSummary !== null, "validation summary not found for the broken pipeline");
        compare(brokenSummary.visible, true);
        compare(brokenSummary.text, "2 error(s) · 1 warning(s)");
    }
}
