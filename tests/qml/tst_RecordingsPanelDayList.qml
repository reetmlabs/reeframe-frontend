// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for RecordingsPanel's day-list UI: one row per day, preview-
// on-click, per-day download, expand-to-sessions drill-down.
//
// Seeds root.dailySummaries directly instead of a real fetch. The panel's
// dailySummaryFetched handler assigns into this same property, so seeding
// it exercises the identical rendering path.
TestCase {
    id: testCase
    name: "RecordingsPanelDayList"
    width: 900
    height: 800
    visible: true
    when: windowShown

    RecordingsPanel {
        id: panel
        objectName: "panelUnderTest"
        width: 280
        syncedCameraId: "qmltest-daylist-cam"
        syncedCameraName: "Day List Test Camera"
    }

    SignalSpy {
        id: maximizeSpy
        target: panel
        signalName: "maximizeCameraRequested"
    }

    function cleanup() {
        panel.dailySummaries = []
        panel.dailySummaryLoading = false
        panel._exportingRangeStart = ""
        maximizeSpy.clear()
        TimelineController.goLive()
    }

    function makeSession(startTime, endTime, sizeBytes) {
        return { startTime: startTime, endTime: endTime, sizeBytes: sizeBytes, chunkCount: 1 }
    }

    // Mirrors RecordingModel::parseDailySummary()'s own totalCoverageSecs/
    // firstSessionStart derivation, so tests don't have to compute them by
    // hand for every case.
    function makeDay(date, sessions) {
        let totalCoverageSecs = 0
        for (let i = 0; i < sessions.length; i++) {
            if (sessions[i].endTime)
                totalCoverageSecs += (new Date(sessions[i].endTime).getTime()
                    - new Date(sessions[i].startTime).getTime()) / 1000
        }
        return {
            date: date,
            sessions: sessions,
            totalCoverageSecs: totalCoverageSecs,
            firstSessionStart: sessions.length > 0 ? sessions[0].startTime : ""
        }
    }

    function test_oneRowPerDayIsShown() {
        panel.dailySummaries = [
            makeDay("2026-07-24", [makeSession("2026-07-24T08:00:00Z", "2026-07-24T08:10:00Z", 1000)]),
            makeDay("2026-07-23", [makeSession("2026-07-23T10:00:00Z", "2026-07-23T10:10:00Z", 1000)])
        ]

        const row0 = findChild(panel, "recordingsPanelDayRow_0")
        const row1 = findChild(panel, "recordingsPanelDayRow_1")
        verify(row0 !== null && row1 !== null, "expected two day rows")
        // Most recent day first. panel.dailySummaries is already in that
        // order here, same as RecordingModel::parseDailySummary()'s output.
        compare(row0.modelData.date, "2026-07-24")
        compare(row1.modelData.date, "2026-07-23")
    }

    function test_singleClickingADayRowDoesNotTriggerPlayback() {
        panel.dailySummaries = [
            makeDay("2026-07-23", [makeSession("2026-07-23T08:00:00Z", "2026-07-23T08:10:00Z", 1000)])
        ]

        const row = findChild(panel, "recordingsPanelDayRow_0")
        verify(row !== null, "day row not found")

        TimelineController.seekTo("1970-01-01T00:00:00Z") // known baseline before the click
        mouseClick(row, row.width / 2, 10)

        compare(TimelineController.currentInstant, "1970-01-01T00:00:00Z",
                "a single click must no longer seek anything")
        compare(maximizeSpy.count, 0)
    }

    function test_doubleClickingADayRowPreviewsFromItsFirstSessionAndMaximizes() {
        panel.dailySummaries = [
            makeDay("2026-07-23", [
                makeSession("2026-07-23T08:00:00Z", "2026-07-23T08:10:00Z", 1000),
                makeSession("2026-07-23T14:00:00Z", "2026-07-23T14:10:00Z", 1000)
            ])
        ]

        const row = findChild(panel, "recordingsPanelDayRow_0")
        verify(row !== null, "day row not found")

        TimelineController.seekTo("1970-01-01T00:00:00Z") // known baseline before the click
        // Qt's synthetic double-click detection isn't reliable under the
        // offscreen test platform (confirmed: two mouseClick()s each fire
        // onTapped but never onDoubleTapped here), and TapHandler isn't a
        // QQuickItem findChild() can locate, so this calls the same
        // activateDayPlayback() the real double-tap gesture calls.
        row.activateDayPlayback()

        compare(TimelineController.currentInstant, "2026-07-23T08:00:00Z",
                "must seek to the day's first actual recording, not literal midnight")
        compare(TimelineController.scopeCameraId, "qmltest-daylist-cam",
                "must scope playback to just this camera, not every tile")
        compare(maximizeSpy.count, 1)
        compare(maximizeSpy.signalArguments[0][0], "qmltest-daylist-cam")
    }

    function test_expandTogglesTheDaysSessionSubList() {
        panel.dailySummaries = [
            makeDay("2026-07-23", [
                makeSession("2026-07-23T08:00:00Z", "2026-07-23T08:10:00Z", 1000),
                makeSession("2026-07-23T14:00:00Z", "2026-07-23T14:10:00Z", 1000)
            ])
        ]

        const row = findChild(panel, "recordingsPanelDayRow_0")
        verify(row !== null, "day row not found")
        compare(row.expanded, false)

        const expandButton = findChild(panel, "recordingsPanelDayExpandButton_0")
        verify(expandButton !== null, "expand button not found")
        mouseClick(expandButton, expandButton.width / 2, expandButton.height / 2)

        compare(row.expanded, true)
        const sessionsColumn = findChild(panel, "recordingsPanelDaySessions_0")
        verify(sessionsColumn !== null, "expanded sessions list not found")
        compare(sessionsColumn.visible, true)

        const sessionRow0 = findChild(sessionsColumn, "recordingSessionRow_0")
        verify(sessionRow0 !== null, "expected a session row for the first of the two real gaps")
    }

    function test_dayDownloadButtonRequestsExportForTheWholeCalendarDay() {
        panel.dailySummaries = [
            makeDay("2026-07-23", [makeSession("2026-07-23T10:00:00Z", "2026-07-23T10:10:00Z", 1000)])
        ]

        const row = findChild(panel, "recordingsPanelDayRow_0")
        verify(row !== null, "day row not found")

        const downloadButton = findChild(panel, "recordingsPanelDayDownloadButton_0")
        verify(downloadButton !== null, "day download button not found")
        mouseClick(downloadButton, downloadButton.width / 2, downloadButton.height / 2)

        compare(panel._exportingRangeStart, row.dayStartIso)
        // Whole calendar day, not just the covered session's own span.
        verify(row.dayStartIso.indexOf("2026-07-23") === 0 || row.dayStartIso.indexOf("2026-07-22") === 0,
               "day bounds must be the calendar day, not the session's own start/end")
    }

    function test_dateRangeButtonOpensCalendarPickerAndApplyingChangesTheRange() {
        const label = findChild(panel, "recordingsPanelRangeLabel")
        verify(label !== null, "range label not found")

        const calendar = findChild(panel, "dateRangeCalendar")
        verify(calendar !== null, "calendar not found")
        compare(calendar.visible, false)

        // Open via the label's parent MouseArea by clicking the label itself.
        mouseClick(label, label.width / 2, label.height / 2)
        tryCompare(calendar, "visible", true)

        calendar.selectDay(calendar.minDate)
        compare(panel.rangeStart, calendar.minDate)
    }
}
