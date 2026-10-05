// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for RecordingModel.dailySummaries(), which buckets the currently
// fetched chunks by local calendar day and merges each day's chunks into
// sessions, backing the recordings panel's one-row-per-day coverage view.
TestCase {
    id: testCase
    name: "RecordingDailySummaries"
    when: true

    function cleanup() {
        RecordingModel.clearTestChunks()
    }

    function test_emptyModelProducesNoDays() {
        compare(RecordingModel.dailySummaries(5).length, 0)
    }

    function test_singleDayChunksMergeIntoOneDayWithOneSession() {
        RecordingModel.insertTestChunk("2026-07-23T10:00:00Z", "2026-07-23T10:10:00Z", 1000)
        RecordingModel.insertTestChunk("2026-07-23T10:10:00Z", "2026-07-23T10:20:00Z", 2000)

        const days = RecordingModel.dailySummaries(5)
        compare(days.length, 1)
        compare(days[0].date, "2026-07-23")
        compare(days[0].sessions.length, 1)
        compare(days[0].sessions[0].startTime, "2026-07-23T10:00:00Z")
        compare(days[0].sessions[0].endTime, "2026-07-23T10:20:00Z")
        compare(days[0].firstSessionStart, "2026-07-23T10:00:00Z")
        compare(days[0].totalCoverageSecs, 1200)
    }

    function test_chunksOnDifferentDaysProduceSeparateDaysNewestFirst() {
        RecordingModel.insertTestChunk("2026-07-23T10:00:00Z", "2026-07-23T10:10:00Z", 1000)
        RecordingModel.insertTestChunk("2026-07-24T08:00:00Z", "2026-07-24T08:10:00Z", 1000)
        RecordingModel.insertTestChunk("2026-07-25T09:00:00Z", "2026-07-25T09:10:00Z", 1000)

        const days = RecordingModel.dailySummaries(5)
        compare(days.length, 3)
        // Most recent day first.
        compare(days[0].date, "2026-07-25")
        compare(days[1].date, "2026-07-24")
        compare(days[2].date, "2026-07-23")
    }

    function test_gapWithinADayStartsANewSessionInTheSameDay() {
        RecordingModel.insertTestChunk("2026-07-23T08:00:00Z", "2026-07-23T08:10:00Z", 1000)
        RecordingModel.insertTestChunk("2026-07-23T14:00:00Z", "2026-07-23T14:10:00Z", 1000)

        const days = RecordingModel.dailySummaries(5)
        compare(days.length, 1)
        compare(days[0].sessions.length, 2,
                "a real gap within one day must produce two sessions, not merge across it")
        compare(days[0].firstSessionStart, "2026-07-23T08:00:00Z")
    }

    function test_stillOpenChunkContributesNoCoverageSecs() {
        RecordingModel.insertTestChunk("2026-07-23T10:00:00Z", "", 1000)

        const days = RecordingModel.dailySummaries(5)
        compare(days.length, 1)
        compare(days[0].sessions[0].endTime, "")
        compare(days[0].totalCoverageSecs, 0,
                "an unterminated session must not contribute a bogus coverage duration")
    }
}
