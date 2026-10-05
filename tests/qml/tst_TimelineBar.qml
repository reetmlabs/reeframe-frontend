// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Covers TimelineBar's own range/zoom/pan logic and TimelineController's
// state machine. Actual media decoding isn't available in this sandbox;
// see tst_CameraTilePlayback.qml for how camera tiles react to the state
// this bar drives.
TestCase {
    id: testCase
    name: "TimelineBar"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    TimelineBar {
        id: bar
        objectName: "barUnderTest"
        width: 800
    }

    function cleanup() {
        TimelineController.goLive()
        OverlayPrefs.timelineOpen = true
        bar.retentionDays = 30
        bar.applyRange(bar.maxSelectableDate, bar.maxSelectableDate)
        bar._events = []
        bar._hiddenEventTypes = ({})
    }

    function test_startsLiveAndExpanded() {
        compare(TimelineController.isLive, true)
        compare(OverlayPrefs.timelineOpen, true)
        compare(bar.formatValueAsTime(bar.sliderValue), "LIVE")
    }

    function test_collapseAndExpand() {
        const collapseBtn = findChild(bar, "timelineCollapseButton")
        verify(collapseBtn !== null, "collapse button not found")
        mouseClick(collapseBtn, collapseBtn.width / 2, collapseBtn.height / 2)
        compare(OverlayPrefs.timelineOpen, false)

        const expandStrip = findChild(bar, "timelineExpandStrip")
        verify(expandStrip !== null, "expand strip not found")
        mouseClick(expandStrip, expandStrip.width / 2, expandStrip.height / 2)
        compare(OverlayPrefs.timelineOpen, true)
    }

    function test_releasingNearRightEdgeGoesLive() {
        // Seeking within today's own (default) view, unlike seeking to a
        // past instant directly, which narrows the view to that historical
        // day instead (see test_seekingToADayOutsideTheCurrentViewExpandsRangeAndPans).
        bar.applyScrubRelease(0.5)
        compare(TimelineController.isLive, false)
        compare(bar.viewIncludesToday, true)

        bar.applyScrubRelease(0.99)

        compare(TimelineController.isLive, true)
    }

    function test_releasingElsewhereSeeksToComputedInstant() {
        bar.applyScrubRelease(0.5)

        compare(TimelineController.isLive, false)
        verify(TimelineController.currentInstant.length > 0, "currentInstant should be set")

        // 0.5 within the default single-day view should land at that day's
        // local noon.
        const instantMs = new Date(TimelineController.currentInstant).getTime()
        const noonMs = new Date(bar.rangeStart + "T12:00:00").getTime()
        verify(Math.abs(instantMs - noonMs) < 5000, "seeked instant should be today's local noon")
    }

    function test_playPauseTogglesOnlyWhenNotLive() {
        const playPauseBtn = findChild(bar, "timelinePlayPauseButton")
        verify(playPauseBtn !== null, "play/pause button not found")

        // Live: TimelineController.isPlaying is irrelevant, but the click
        // handler itself is a no-op guarded inside togglePlayPause().
        compare(TimelineController.isPlaying, true)
        mouseClick(playPauseBtn, playPauseBtn.width / 2, playPauseBtn.height / 2)
        compare(TimelineController.isPlaying, true)

        TimelineController.seekTo("2026-07-23T10:00:00.000Z")
        compare(TimelineController.isPlaying, true)
        mouseClick(playPauseBtn, playPauseBtn.width / 2, playPauseBtn.height / 2)
        compare(TimelineController.isPlaying, false)
    }

    function test_liveBadgeClickReturnsToLive() {
        TimelineController.seekTo("2026-07-23T10:00:00.000Z")
        compare(TimelineController.isLive, false)

        // Synthetic clicks aren't reliable under the offscreen test platform
        // (see RecordingsPanel.qml's activateDayPlayback() for the same
        // note), so this only confirms the badge exists, then calls the
        // click handler's own target directly.
        const liveBadge = findChild(bar, "timelineLiveBadge")
        verify(liveBadge !== null, "live badge not found")
        bar.goLive()

        compare(TimelineController.isLive, true)
        compare(bar.rangeStart, bar.maxSelectableDate)
        compare(bar.rangeEnd, bar.maxSelectableDate)
        compare(bar.visibleDays, 1)
    }

    function test_applyRangeResetsZoomAndShowsTheMostRecentSlice() {
        bar.retentionDays = 30
        const from = bar.addDays(bar.maxSelectableDate, -14)
        bar.applyRange(from, bar.maxSelectableDate)

        compare(bar.rangeStart, from)
        compare(bar.rangeEnd, bar.maxSelectableDate)
        // viewStart defaults to showing the range's most recent slice.
        compare(bar.viewStart, bar.addDays(bar.rangeEnd, -(bar.visibleDays - 1)))
        compare(bar.viewEnd, bar.rangeEnd)
    }

    function test_zoomInAndOutAdjustVisibleDaysByOneWithinBounds() {
        bar.retentionDays = 30
        bar.applyRange(bar.addDays(bar.maxSelectableDate, -14), bar.maxSelectableDate)
        compare(bar.visibleDays, 1)

        bar.zoomOut()
        compare(bar.visibleDays, 2)
        bar.zoomOut()
        compare(bar.visibleDays, 3)

        bar.zoomIn()
        compare(bar.visibleDays, 2)

        // Can't zoom below 1 day.
        bar.zoomIn()
        bar.zoomIn()
        compare(bar.visibleDays, 1)
    }

    function test_zoomOutCannotExceedTheSelectedRangeSpan() {
        bar.retentionDays = 30
        bar.applyRange(bar.addDays(bar.maxSelectableDate, -2), bar.maxSelectableDate)
        compare(bar.rangeSpanDays, 3)

        bar.zoomOut(); bar.zoomOut(); bar.zoomOut(); bar.zoomOut()
        compare(bar.visibleDays, 3)
    }

    function test_zoomOutCannotExceedTheRetentionCap() {
        bar.retentionDays = 3
        bar.applyRange(bar.addDays(bar.maxSelectableDate, -10), bar.maxSelectableDate)
        compare(bar.rangeSpanDays, 11)

        bar.zoomOut(); bar.zoomOut(); bar.zoomOut(); bar.zoomOut(); bar.zoomOut()
        compare(bar.visibleDays, 3)
    }

    function test_panButtonsMoveTheViewWithinTheSelectedRangeAndClampAtEdges() {
        bar.retentionDays = 30
        bar.applyRange(bar.addDays(bar.maxSelectableDate, -5), bar.maxSelectableDate)
        bar.zoomOut(); bar.zoomOut() // visibleDays = 3, viewStart defaults to the last 3 days

        compare(bar.canPanLater, false)
        verify(bar.canPanEarlier, "should be able to pan toward the range's earlier days")

        const panEarlierBtn = findChild(bar, "timelinePanEarlierButton")
        verify(panEarlierBtn !== null, "pan-earlier button not found")
        const viewStartBefore = bar.viewStart
        mouseClick(panEarlierBtn, panEarlierBtn.width / 2, panEarlierBtn.height / 2)
        compare(bar.viewStart, bar.rangeStart, "a 6-day range with a 3-day window pans exactly one window")
        compare(bar.canPanEarlier, false)

        const panLaterBtn = findChild(bar, "timelinePanLaterButton")
        verify(panLaterBtn !== null, "pan-later button not found")
        mouseClick(panLaterBtn, panLaterBtn.width / 2, panLaterBtn.height / 2)
        compare(bar.viewStart, viewStartBefore)
    }

    function test_seekingToADayOutsideTheCurrentViewExpandsRangeAndPans() {
        bar.applyRange(bar.maxSelectableDate, bar.maxSelectableDate)
        compare(bar.visibleDays, 1)

        const oldDay = bar.addDays(bar.maxSelectableDate, -10)
        TimelineController.seekTo(oldDay + "T08:00:00.000Z", "some-camera")

        compare(bar.rangeStart, oldDay,
                "range must expand to include a day seeked from outside it")
        compare(bar.viewStart, oldDay)
        compare(bar.visibleDays, 1, "zoom level itself must not change from an external seek")
    }

    function test_dateRangeButtonOpensCalendarPickerAndApplyingChangesTheRange() {
        const label = findChild(bar, "timelineRangeLabel")
        verify(label !== null, "range label not found")

        const calendar = findChild(bar, "timelineDateRangeCalendar")
        verify(calendar !== null, "calendar not found")
        compare(calendar.visible, false)

        mouseClick(label, label.width / 2, label.height / 2)
        tryCompare(calendar, "visible", true)

        calendar.selectDay(calendar.minDate)
        compare(bar.rangeStart, calendar.minDate)
    }

    // CameraModel is shared across every QML test file in this binary, so
    // these test the accumulation/commit mechanics directly (seeding
    // _pending* as refreshEvents() itself would) rather than asserting an
    // exact camera count, which other test files' leftover state makes
    // unreliable.
    function test_eventsFromEveryExpectedCameraAggregateOnlyOnceAllArrive() {
        bar._pendingEvents = []
        bar._pendingEventsExpected = 2
        bar._pendingEventsReceived = 0
        bar._events = []

        EventModel.eventsFetched("qmltest-tl-cam-1",
            [{ id: "e1", eventType: "motion_started", occurredAt: bar.rangeStart + "T10:00:00Z" }])
        compare(bar._events.length, 0, "must wait for every camera before committing")

        EventModel.eventsFetched("qmltest-tl-cam-2", [])
        compare(bar._events.length, 1)
    }

    function test_refreshEventsOnlyFetchesTheScopedCameraWhenScoped() {
        TimelineController.seekTo(bar.rangeStart + "T08:00:00Z", "qmltest-tl-cam-1")
        compare(bar._pendingEventsExpected, 1)
    }

    function test_aFailedFetchStillLetsTheRemainingResultsCommit() {
        bar._pendingEvents = []
        bar._pendingEventsExpected = 2
        bar._pendingEventsReceived = 0
        bar._events = []

        EventModel.eventsFetchFailed("qmltest-tl-cam-1", "boom")
        EventModel.eventsFetched("qmltest-tl-cam-2",
            [{ id: "e1", eventType: "motion_started", occurredAt: bar.rangeStart + "T10:00:00Z" }])
        compare(bar._events.length, 1)
    }

    function test_legendTogglesMarkerVisibilityForAKnownType() {
        compare(bar.isEventVisible("motion_started"), true)
        bar.toggleEventTypeVisible("motion_started")
        compare(bar.isEventVisible("motion_started"), false)
        bar.toggleEventTypeVisible("motion_started")
        compare(bar.isEventVisible("motion_started"), true)
    }

    function test_unknownEventTypesShareTheOtherBucketToggle() {
        compare(bar.isEventVisible("some_unknown_type"), true)
        bar.toggleEventTypeVisible("_other")
        compare(bar.isEventVisible("some_unknown_type"), false)
        compare(bar.isEventVisible("motion_started"), true,
                "toggling _other must not affect a known type")
        bar.toggleEventTypeVisible("_other")
    }

    function test_seekToEventStaysScopedToTheCurrentlyMaximizedCamera() {
        TimelineController.seekTo(bar.rangeStart + "T08:00:00Z", "qmltest-tl-cam-1")

        bar.seekToEvent(bar.rangeStart + "T09:30:00Z")

        compare(TimelineController.scopeCameraId, "qmltest-tl-cam-1")
        compare(TimelineController.currentInstant, bar.rangeStart + "T09:30:00Z")
    }

    function test_seekToEventIsUnscopedWhenNothingIsMaximized() {
        bar.seekToEvent(bar.rangeStart + "T09:30:00Z")

        compare(TimelineController.scopeCameraId, "")
        compare(TimelineController.currentInstant, bar.rangeStart + "T09:30:00Z")
    }
}
