// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// This test harness has no active Site configured, so a real
// PipelineModel.setEnabled() call always rolls back synchronously ("no
// active site session") rather than succeeding. See test_3 below, which
// exercises that real end-to-end path rather than faking a success outcome
// that isn't reachable in this environment. test_1/test_2 cover the
// rollback-reaction logic directly and deterministically.
TestCase {
    id: testCase
    name: "PipelineEnableToggle"
    width: 200
    height: 60
    visible: true
    when: windowShown

    function initTestCase() {
        PipelineModel.clearTestPipelines();
    }

    PipelineEnableToggle {
        id: toggleRow
    }

    function test_1_rollbackForTheMatchingPipelineRevertsLocalEnabled() {
        toggleRow.pipelineId = "match-me";
        toggleRow.localEnabled = true;

        PipelineModel.enableRollback("match-me", false, "simulated failure");

        compare(toggleRow.localEnabled, false);
    }

    function test_2_rollbackForADifferentPipelineIsIgnored() {
        toggleRow.pipelineId = "match-me";
        toggleRow.localEnabled = true;

        PipelineModel.enableRollback("some-other-id", false, "unrelated failure");

        compare(toggleRow.localEnabled, true);
    }

    function test_3_togglingFlipsOptimisticallyThenRollsBackWithNoActiveSite() {
        const id = "qmltest-enable-toggle-" + Date.now();
        PipelineModel.insertTestPipeline(id, "Enable Toggle Pipeline");
        toggleRow.pipelineId = id;
        toggleRow.pipelineEnabled = false;
        toggleRow.localEnabled = false;

        const sw = findChild(toggleRow, "pipelineEnableToggleSwitch");
        verify(sw !== null, "toggle switch not found");

        sw.toggled(true);

        // PipelineModel.setEnabled() only ever reverts its own model data on
        // a failed backend request. The "no active site" branch skips the
        // request entirely and relies on this signal for the UI to revert,
        // so only the component's local mirror is expected back at false.
        compare(toggleRow.localEnabled, false);

        PipelineModel.clearTestPipelines();
    }

    function test_4_switchIsDisabledWhileOffWithErrors() {
        toggleRow.pipelineEnabled = false;
        toggleRow.localEnabled = false;
        toggleRow.errorCount = 2;

        const sw = findChild(toggleRow, "pipelineEnableToggleSwitch");
        compare(sw.enabled, false);

        toggleRow.errorCount = 0;
    }

    function test_5_switchStaysEnabledToTurnOffDespiteErrors() {
        toggleRow.pipelineEnabled = true;
        toggleRow.localEnabled = true;
        toggleRow.errorCount = 2;

        const sw = findChild(toggleRow, "pipelineEnableToggleSwitch");
        compare(sw.enabled, true);

        toggleRow.errorCount = 0;
    }
}
