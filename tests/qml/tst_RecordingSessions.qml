// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for RecordingModel.sessions(), which merges internal recording
// chunks into continuous ranges an operator actually cares about. The
// recordings panel's own UI (a one-row-per-day list built on
// RecordingModel.dailySummaries()) is covered by
// tst_RecordingsPanelDayList.qml.
TestCase {
    id: testCase
    name: "RecordingSessions"
    when: true

    function cleanup() {
        RecordingModel.clearTestChunks()
    }

    function test_adjacentChunksMergeIntoOneSession() {
        RecordingModel.insertTestChunk("2026-07-23T10:00:00Z", "2026-07-23T10:10:00Z", 1000)
        RecordingModel.insertTestChunk("2026-07-23T10:10:00Z", "2026-07-23T10:20:00Z", 2000)

        const sessions = RecordingModel.sessions(5)
        compare(sessions.length, 1)
        compare(sessions[0].startTime, "2026-07-23T10:00:00Z")
        compare(sessions[0].endTime, "2026-07-23T10:20:00Z")
        compare(sessions[0].sizeBytes, 3000)
        compare(sessions[0].chunkCount, 2)
    }

    function test_gapBiggerThanToleranceStartsNewSession() {
        RecordingModel.insertTestChunk("2026-07-23T10:00:00Z", "2026-07-23T10:10:00Z", 1000)
        RecordingModel.insertTestChunk("2026-07-23T11:00:00Z", "2026-07-23T11:10:00Z", 1000)

        const sessions = RecordingModel.sessions(5)
        compare(sessions.length, 2)
        compare(sessions[0].endTime, "2026-07-23T10:10:00Z")
        compare(sessions[1].startTime, "2026-07-23T11:00:00Z")
    }

    function test_stillOpenChunkProducesEmptyEndTime() {
        RecordingModel.insertTestChunk("2026-07-23T10:00:00Z", "", 1000)

        const sessions = RecordingModel.sessions(5)
        compare(sessions.length, 1)
        compare(sessions[0].endTime, "")
    }

}
