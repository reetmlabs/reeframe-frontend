// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for RecordingModel::parseDailySummary()'s field-name mapping
// (backend snake_case, oldest-first -> panel's camelCase, newest-first),
// exercised via the parseDailySummaryForTest() test-only seam.
TestCase {
    id: testCase
    name: "RecordingDailySummaryParsing"
    when: true

    function test_mapsBackendFieldNamesToTheExpectedShape() {
        const json = JSON.stringify([
            {
                camera_id: "cam-1", date: "2026-07-23", coverage_seconds: 600,
                session_ranges: [
                    { start: "2026-07-23T10:00:00Z", end: "2026-07-23T10:10:00Z",
                      chunk_count: 2, size_bytes: 3000 }
                ],
                chunk_count: 2, total_size_bytes: 3000,
                is_finalized: true, purged_by_retention: false
            }
        ])

        const days = RecordingModel.parseDailySummaryForTest(json)
        compare(days.length, 1)
        compare(days[0].date, "2026-07-23")
        compare(days[0].totalCoverageSecs, 600)
        compare(days[0].firstSessionStart, "2026-07-23T10:00:00Z")
        compare(days[0].sessions.length, 1)
        compare(days[0].sessions[0].startTime, "2026-07-23T10:00:00Z")
        compare(days[0].sessions[0].endTime, "2026-07-23T10:10:00Z")
        compare(days[0].sessions[0].sizeBytes, 3000)
        compare(days[0].sessions[0].chunkCount, 2)
    }

    function test_stillOpenSessionHasEmptyEndTime() {
        const json = JSON.stringify([
            {
                camera_id: "cam-1", date: "2026-07-23", coverage_seconds: 0,
                session_ranges: [
                    { start: "2026-07-23T10:00:00Z", end: null, chunk_count: 1, size_bytes: null }
                ],
                chunk_count: 1, total_size_bytes: null,
                is_finalized: false, purged_by_retention: false
            }
        ])

        const days = RecordingModel.parseDailySummaryForTest(json)
        compare(days[0].sessions[0].endTime, "")
        compare(days[0].sessions[0].sizeBytes, -1, "a null size_bytes must map to -1, not 0 or null")
    }

    function test_reordersOldestFirstResponseToNewestFirst() {
        const json = JSON.stringify([
            { camera_id: "cam-1", date: "2026-07-22", coverage_seconds: 0, session_ranges: [],
              chunk_count: 0, total_size_bytes: null, is_finalized: true, purged_by_retention: false },
            { camera_id: "cam-1", date: "2026-07-23", coverage_seconds: 0, session_ranges: [],
              chunk_count: 0, total_size_bytes: null, is_finalized: true, purged_by_retention: false }
        ])

        const days = RecordingModel.parseDailySummaryForTest(json)
        compare(days.length, 2)
        // Backend returns oldest-first; the panel expects most-recent-first.
        compare(days[0].date, "2026-07-23")
        compare(days[1].date, "2026-07-22")
    }

    function test_emptyArrayProducesNoDays() {
        compare(RecordingModel.parseDailySummaryForTest("[]").length, 0)
    }
}
