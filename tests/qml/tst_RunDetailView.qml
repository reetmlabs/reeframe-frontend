// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for Run Detail staying live rather than a static snapshot: its
// summary and node-results list must re-read from RunModel whenever it
// refreshes (RunModel.count changes on every poll tick, even when the row
// count itself doesn't; see RunModel::refresh()'s unconditional
// beginResetModel()/endResetModel()).
TestCase {
    id: testCase
    name: "RunDetailView"
    width: 400
    height: 600
    visible: true
    when: windowShown

    RunDetailView {
        id: view
        width: 400
        height: 600
    }

    function initTestCase() {
        RunModel.clearTestRuns();
    }

    function test_1_liveNodeResultsExposeTheErrorField() {
        const runId = "qmltest-run-" + Date.now();
        RunModel.insertTestRun(runId, "failed", "top-level boom", [
            { nodeId: "n1", status: "failed", startedAt: 1000, completedAt: 1005, output: "", error: "node exploded" }
        ]);
        view.runId = runId;

        compare(view.liveNodeResults.length, 1);
        compare(view.liveNodeResults[0].error, "node exploded");
        compare(view.liveStatus, "failed");
        compare(view.liveError, "top-level boom");

        RunModel.clearTestRuns();
    }

    function test_2_liveDataUpdatesWhenTheUnderlyingRunChanges() {
        const runId = "qmltest-run-update-" + Date.now();
        RunModel.insertTestRun(runId, "running", "", []);
        view.runId = runId;

        compare(view.liveStatus, "running");
        compare(view.liveNodeResults.length, 0);

        // Simulate what a poll refresh does: the run is reloaded wholesale
        // (beginResetModel/endResetModel), now completed with a node result.
        RunModel.clearTestRuns();
        RunModel.insertTestRun(runId, "completed", "", [
            { nodeId: "n1", status: "completed", startedAt: 1000, completedAt: 1002, output: "done", error: "" }
        ]);

        compare(view.liveStatus, "completed");
        compare(view.liveNodeResults.length, 1);

        RunModel.clearTestRuns();
    }
}
