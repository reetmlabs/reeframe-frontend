// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Test functions run in alphabetical order here, not declaration order, and
// share one `panel` instance, so every test resets .problems/.expanded itself
// rather than relying on whatever the previous (alphabetically) test left.
TestCase {
    id: testCase
    name: "ProblemsPanel"
    width: 400
    height: 300
    visible: true
    when: windowShown

    ProblemsPanel {
        id: panel
        anchors.left: parent.left
        anchors.right: parent.right
    }

    function test_1_noProblemsShowsPlainSummary() {
        panel.problems = []
        const summary = findChild(panel, "problemsPanelSummary")
        compare(summary.text, "No problems")
    }

    function test_2_summaryCountsErrorsAndWarningsSeparately() {
        panel.problems = [
            { severity: "error", category: "structural", nodeId: "a", message: "x" },
            { severity: "error", category: "structural", nodeId: "b", message: "y" },
            { severity: "warning", category: "disconnected", nodeId: "c", message: "z" },
        ]
        compare(panel.errorCount, 2)
        compare(panel.warningCount, 1)
    }

    function test_3_collapsedByDefaultAtHeaderHeight() {
        panel.expanded = false
        compare(panel.height, panel.headerHeight)
    }

    function test_4_clickingHeaderTogglesExpanded() {
        panel.expanded = false
        const header = findChild(panel, "problemsPanelHeader")
        mouseClick(header, header.width / 2, header.height / 2)
        compare(panel.expanded, true)
        mouseClick(header, header.width / 2, header.height / 2)
        compare(panel.expanded, false)
    }

    function test_5_clickingANodeLevelEntryEmitsEntryActivated() {
        panel.problems = [{ severity: "error", category: "config_incomplete", nodeId: "n1", message: "needs an expression" }]
        panel.expanded = true
        wait(150)

        let activated = null
        const handler = (p) => activated = p
        panel.entryActivated.connect(handler)
        const entry = findChild(panel, "problemsPanelEntry_0")
        mouseClick(entry, entry.width / 2, entry.height / 2)
        panel.entryActivated.disconnect(handler)

        verify(activated !== null)
        compare(activated.nodeId, "n1")
    }

    function test_6_clickingAPipelineLevelEntryWithNoNodeDoesNothing() {
        panel.problems = [{ severity: "error", category: "structural", nodeId: null, nodeIds: undefined, message: "No trigger node found." }]
        panel.expanded = true
        wait(150)

        let activated = null
        const handler = (p) => activated = p
        panel.entryActivated.connect(handler)
        const entry = findChild(panel, "problemsPanelEntry_0")
        mouseClick(entry, entry.width / 2, entry.height / 2)
        panel.entryActivated.disconnect(handler)

        verify(activated === null)
    }

    function test_7_clickingACycleEntryWithNodeIdsEmitsEntryActivated() {
        panel.problems = [{ severity: "error", category: "structural", nodeId: null, nodeIds: ["a", "b"], message: "Cycle detected." }]
        panel.expanded = true
        wait(150)

        let activated = null
        const handler = (p) => activated = p
        panel.entryActivated.connect(handler)
        const entry = findChild(panel, "problemsPanelEntry_0")
        mouseClick(entry, entry.width / 2, entry.height / 2)
        panel.entryActivated.disconnect(handler)

        verify(activated !== null)
        compare(activated.nodeIds, ["a", "b"])
    }
}
