// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for RecordingsPanel's periodic refresh: a Timer recomputes the
// default range and refetches every 60 seconds while the panel is visible,
// but a range the user explicitly applied is left alone.
TestCase {
    id: testCase
    name: "RecordingsPanelAutoRefresh"
    width: 900
    height: 800
    visible: true
    when: windowShown

    RecordingsPanel {
        id: panel
        objectName: "panelUnderTest"
        width: 280
        syncedCameraId: "qmltest-autorefresh-cam"
        syncedCameraName: "Auto Refresh Test Camera"
    }

    function cleanup() {
        panel.rangeIsDefault = true
        panel.applyDefaultRange()
    }

    function test_refreshTimerRunsOnlyWhilePanelIsVisible() {
        const timer = findChild(panel, "recordingsPanelRefreshTimer");
        verify(timer !== null, "refresh timer not found");

        panel.visible = true;
        compare(timer.running, true, "the timer must run while the panel is visible");

        panel.visible = false;
        compare(timer.running, false, "the timer must stop while the panel is hidden");

        panel.visible = true;
    }

    function test_applyDefaultRangeRecomputesToToday() {
        panel.rangeStart = "2020-01-01";
        panel.rangeEnd = "2020-01-01";

        panel.applyDefaultRange();

        const expectedEnd = Qt.formatDate(new Date(), "yyyy-MM-dd");
        const expectedStart = Qt.formatDate(new Date(Date.now() - 6 * 86400000), "yyyy-MM-dd");
        compare(panel.rangeEnd, expectedEnd, "the range must roll forward to today");
        compare(panel.rangeStart, expectedStart, "the range must keep its 7-day span");
    }

    function test_manuallyAppliedRangeIsNoLongerDefault() {
        compare(panel.rangeIsDefault, true, "a freshly loaded panel starts on the default range");

        const calendar = findChild(panel, "dateRangeCalendar");
        verify(calendar !== null, "calendar not found");
        calendar.selectDay(calendar.minDate);

        compare(panel.rangeIsDefault, false,
                "applying a range from the picker must stop the timer from overriding it");
    }
}
