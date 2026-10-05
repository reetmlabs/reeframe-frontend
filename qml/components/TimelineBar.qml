// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

// Persistent bottom bar shared by tile mode (MatrixView) and maximized mode
// (FullCameraView): the single control that drives TimelineController's state,
// which every camera tile reads to choose live vs. resolved recording playback.
// The visible window is a zoomable/pannable slice of a user-selected date range,
// so scrubbing behaves the same whether isLive covers every camera or (via
// scopeCameraId) just one maximized camera's day.
Rectangle {
    id: root

    readonly property int collapsedHeight: 24
    readonly property int expandedHeight: 64

    // ----- Selected date range, "yyyy-MM-dd" local, both inclusive -----
    property string rangeStart: Qt.formatDate(new Date(), "yyyy-MM-dd")
    property string rangeEnd: Qt.formatDate(new Date(), "yyyy-MM-dd")

    // Capped by the backend's recordings.retention_days; no point letting the
    // user pick further back than footage already purged. Same source RecordingsPanel reads.
    property int retentionDays: 30
    readonly property string minSelectableDate:
        Qt.formatDate(new Date(Date.now() - root.retentionDays * 86400000), "yyyy-MM-dd")
    readonly property string maxSelectableDate: Qt.formatDate(new Date(), "yyyy-MM-dd")

    Component.onCompleted: RecordingModel.fetchRetentionDays()
    Connections {
        target: RecordingModel
        function onRetentionDaysFetched(days) { root.retentionDays = days }
    }

    function daysBetween(a, b) {
        return Math.round((new Date(b + "T00:00:00").getTime()
                          - new Date(a + "T00:00:00").getTime()) / 86400000)
    }
    function addDays(day, n) {
        return Qt.formatDate(new Date(new Date(day + "T00:00:00").getTime() + n * 86400000),
                             "yyyy-MM-dd")
    }

    readonly property int rangeSpanDays: root.daysBetween(root.rangeStart, root.rangeEnd) + 1

    // ----- Zoom (how many whole days are visible at once) and pan (which
    // slice of the selected range that window currently shows) -----
    property int visibleDays: 1
    // Defaults to the most recent slice of the range, so "today" stays visible without panning.
    property string viewStart: root.addDays(root.rangeEnd, -(root.visibleDays - 1))
    readonly property string viewEnd: root.addDays(root.viewStart, root.visibleDays - 1)

    function clampVisibleDays(v) {
        return Math.max(1, Math.min(root.retentionDays, root.rangeSpanDays, v))
    }
    function clampViewStart(v) {
        const earliest = root.rangeStart
        const latest = root.addDays(root.rangeEnd, -(root.visibleDays - 1))
        return v < earliest ? earliest : (v > latest ? latest : v)
    }

    function zoomIn() {
        root.visibleDays = root.clampVisibleDays(root.visibleDays - 1)
        root.viewStart = root.clampViewStart(root.viewStart)
    }
    function zoomOut() {
        root.visibleDays = root.clampVisibleDays(root.visibleDays + 1)
        root.viewStart = root.clampViewStart(root.viewStart)
    }
    function panByWindows(n) {
        root.viewStart = root.clampViewStart(root.addDays(root.viewStart, n * root.visibleDays))
    }

    readonly property bool canPanEarlier: root.viewStart > root.rangeStart
    readonly property bool canPanLater: root.viewEnd < root.rangeEnd

    function applyRange(startDate, endDate) {
        root.rangeStart = startDate
        root.rangeEnd = endDate
        root.visibleDays = root.clampVisibleDays(root.visibleDays)
        root.viewStart = root.addDays(root.rangeEnd, -(root.visibleDays - 1))
    }

    function formatRangeLabel() {
        if (root.rangeStart === root.rangeEnd)
            return Qt.formatDate(new Date(root.rangeStart + "T00:00:00"), "d MMM yyyy")
        return Qt.formatDate(new Date(root.rangeStart + "T00:00:00"), "d MMM")
            + " – " + Qt.formatDate(new Date(root.rangeEnd + "T00:00:00"), "d MMM yyyy")
    }

    // ----- Mapping between the visible window and an absolute instant -----
    readonly property double viewStartMs: new Date(root.viewStart + "T00:00:00").getTime()
    readonly property double viewEndMs: new Date(root.viewEnd + "T00:00:00").getTime() + 86400000

    function instantToValue(iso) {
        if (!iso)
            return 1.0
        const ms = new Date(iso).getTime()
        return Math.max(0, Math.min(1, (ms - root.viewStartMs) / (root.viewEndMs - root.viewStartMs)))
    }
    function valueToInstant(v) {
        return new Date(root.viewStartMs + v * (root.viewEndMs - root.viewStartMs)).toISOString()
    }

    // The live edge ("now") is only reachable at the slider's right edge when the
    // visible window's last day is actually today. An older day has no such affordance.
    readonly property bool viewIncludesToday: root.viewEnd === root.maxSelectableDate

    // Local, user-facing slider position. Only reassigned by dragging or by the
    // Connections block below, never recomputed continuously against the wall clock.
    property real sliderValue: 1.0

    function formatValueAsTime(v) {
        if (root.viewIncludesToday && v > 0.985)
            return qsTr("LIVE")
        const instant = new Date(root.valueToInstant(v))
        return root.visibleDays === 1 ? Qt.formatDateTime(instant, "hh:mm:ss")
                                       : Qt.formatDateTime(instant, "d MMM hh:mm")
    }

    // Called when the scrub handle is released. Separated from Slider's
    // onPressedChanged so it's directly callable from tests without a real drag.
    function applyScrubRelease(v) {
        if (root.viewIncludesToday && v > 0.985)
            root.goLive()
        // Preserves whatever camera playback is currently scoped to, same as
        // seekToEvent() below. Otherwise scrubbing would reset scope to matrix-wide.
        else if (TimelineController.scopeCameraId.length > 0)
            TimelineController.seekTo(root.valueToInstant(v), TimelineController.scopeCameraId)
        else
            TimelineController.seekTo(root.valueToInstant(v))
    }

    // Resets the range/zoom/pan back to "today" too. Otherwise clicking Live
    // while browsing an older day would flip isLive but leave the slider on that day.
    function goLive() {
        TimelineController.goLive()
        root.rangeStart = root.maxSelectableDate
        root.rangeEnd = root.maxSelectableDate
        root.visibleDays = 1
        root.viewStart = root.rangeStart
    }

    Connections {
        target: TimelineController
        function onIsLiveChanged() {
            if (TimelineController.isLive)
                root.sliderValue = 1.0
        }
        function onCurrentInstantChanged() {
            // Empty only when goLive() just cleared it. seekTo() always sets a non-empty
            // value, and isLive flips false right after (not before), so it can't guard here.
            if (TimelineController.currentInstant.length === 0)
                return
            // A seek from elsewhere (e.g. a daily-summary row double-click) may land
            // outside the selected range/view, so expand and pan just enough to show it.
            const day = TimelineController.currentInstant.slice(0, 10)
            if (day < root.rangeStart)
                root.rangeStart = day
            else if (day > root.rangeEnd)
                root.rangeEnd = day
            if (day < root.viewStart)
                root.viewStart = root.clampViewStart(day)
            else if (day > root.viewEnd)
                root.viewStart = root.clampViewStart(root.addDays(day, -(root.visibleDays - 1)))
            root.sliderValue = root.instantToValue(TimelineController.currentInstant)
        }
        function onScopeCameraIdChanged() { root.refreshEvents() }
    }

    // ----- Event markers (motion/tamper/signal-loss/etc, see the backend's
    // events table) for the currently visible window -----
    property var _events: []
    // Types explicitly toggled off via the legend popup; absent = visible.
    property var _hiddenEventTypes: ({})

    function isEventVisible(eventType) {
        const key = EventTypeColors.knownTypes.indexOf(eventType) >= 0 ? eventType : "_other"
        return !root._hiddenEventTypes[key]
    }
    function toggleEventTypeVisible(key) {
        const hidden = Object.assign({}, root._hiddenEventTypes)
        if (hidden[key])
            delete hidden[key]
        else
            hidden[key] = true
        root._hiddenEventTypes = hidden
    }

    property int _pendingEventsExpected: 0
    property int _pendingEventsReceived: 0
    property var _pendingEvents: []

    // Scoped to one camera while a day-playback session is maximized (see
    // TimelineController.scopeCameraId); otherwise fans out one fetch per known
    // camera, since there's no bulk multi-camera events endpoint. A late response
    // from a superseded refresh may land after a newer one, but a briefly lagging
    // marker self-corrects on the next refresh.
    function refreshEvents() {
        const cameraIds = TimelineController.scopeCameraId.length > 0
            ? [TimelineController.scopeCameraId]
            : CameraModel.searchableEntries().map(function(e) { return e.id })

        root._pendingEvents = []
        root._pendingEventsExpected = cameraIds.length
        root._pendingEventsReceived = 0

        if (cameraIds.length === 0) {
            root._events = []
            return
        }

        const viewStartMs = new Date(root.viewStart + "T00:00:00").getTime()
        const viewEndMs = new Date(root.viewEnd + "T00:00:00").getTime()
        // Guards a transient construction-order state where this fires (via
        // onViewStartChanged/onVisibleDaysChanged) before rangeStart/rangeEnd settle.
        if (isNaN(viewStartMs) || isNaN(viewEndMs))
            return
        const fromIso = new Date(viewStartMs).toISOString()
        const toIso = new Date(viewEndMs + 86400000).toISOString()
        for (const camId of cameraIds)
            EventModel.fetchEvents(camId, fromIso, toIso)
    }

    onViewStartChanged: root.refreshEvents()
    onVisibleDaysChanged: root.refreshEvents()

    // Scoped to whatever camera (if any) playback is currently scoped to.
    // Shared by every event marker's click handler and directly testable.
    function seekToEvent(at) {
        if (TimelineController.scopeCameraId.length > 0)
            TimelineController.seekTo(at, TimelineController.scopeCameraId)
        else
            TimelineController.seekTo(at)
    }

    Connections {
        target: EventModel
        function onEventsFetched(cameraId, events) {
            for (const e of events)
                root._pendingEvents.push(e)
            root._pendingEventsReceived++
            if (root._pendingEventsReceived >= root._pendingEventsExpected)
                root._events = root._pendingEvents
        }
        function onEventsFetchFailed(cameraId, message) {
            root._pendingEventsReceived++
            if (root._pendingEventsReceived >= root._pendingEventsExpected)
                root._events = root._pendingEvents
        }
    }

    color: Theme.surfaceAlt
    height: OverlayPrefs.timelineOpen ? expandedHeight : collapsedHeight

    Behavior on height {
        NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic }
    }

    Rectangle {
        height: 1
        color: Theme.border
        anchors { left: parent.left; right: parent.right; top: parent.top }
    }

    Item {
        visible: !OverlayPrefs.timelineOpen
        anchors.fill: parent

        RecordingDot {
            recording: TimelineController.isLive
            anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
        }

        Text {
            text: root.formatValueAsTime(root.sliderValue)
            font.pixelSize: Theme.fontXs
            color: Theme.textSecondary
            anchors.centerIn: parent
        }

        MouseArea {
            objectName: "timelineExpandStrip"
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: OverlayPrefs.timelineOpen = true
        }
    }

    Item {
        visible: OverlayPrefs.timelineOpen
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 1; bottom: parent.bottom }

        Item {
            id: playPauseButton
            objectName: "timelinePlayPauseButton"
            width: 28; height: 28
            enabled: !TimelineController.isLive
            opacity: enabled ? 1.0 : 0.4
            anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }

            TblIcon {
                source: TimelineController.isPlaying ? "qrc:/tb/player-pause.svg" : "qrc:/tb/player-play.svg"
                color: Theme.textPrimary
                size: 18
                anchors.centerIn: parent
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: TimelineController.togglePlayPause()
            }
        }

        /* A drag-to-pan gesture on the slider would compete with its own click-to-scrub
           hit area, so panning within a wider selected range uses explicit step
           buttons instead, one window (visibleDays) per click. */
        Row {
            id: navButtons
            spacing: Theme.spaceXs
            anchors { left: playPauseButton.right; leftMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }

            TblIcon {
                objectName: "timelineZoomOutButton"
                source: "qrc:/tb/minus.svg"
                size: 14
                color: zoomOutMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                opacity: root.visibleDays < Math.min(root.retentionDays, root.rangeSpanDays) ? 1.0 : 0.35
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    id: zoomOutMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.zoomOut()
                }
            }

            TblIcon {
                objectName: "timelinePanEarlierButton"
                source: "qrc:/tb/chevron-left.svg"
                size: 14
                color: panEarlierMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                opacity: root.canPanEarlier ? 1.0 : 0.35
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    id: panEarlierMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.canPanEarlier
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.panByWindows(-1)
                }
            }

            TblIcon {
                objectName: "timelinePanLaterButton"
                source: "qrc:/tb/chevron-right.svg"
                size: 14
                color: panLaterMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                opacity: root.canPanLater ? 1.0 : 0.35
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    id: panLaterMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.canPanLater
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.panByWindows(1)
                }
            }

            TblIcon {
                objectName: "timelineZoomInButton"
                source: "qrc:/tb/plus.svg"
                size: 14
                color: zoomInMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                opacity: root.visibleDays > 1 ? 1.0 : 0.35
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    id: zoomInMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.visibleDays > 1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.zoomIn()
                }
            }
        }

        Slider {
            id: scrubSlider
            objectName: "timelineScrubSlider"
            from: 0; to: 1
            value: root.sliderValue
            anchors {
                left: navButtons.right; leftMargin: Theme.spaceM
                right: rangeLabel.left; rightMargin: Theme.spaceM
                verticalCenter: parent.verticalCenter
            }

            onMoved: root.sliderValue = value

            onPressedChanged: {
                if (!scrubSlider.pressed)
                    root.applyScrubRelease(scrubSlider.value)
            }

            background: Rectangle {
                x: scrubSlider.leftPadding
                y: scrubSlider.topPadding + scrubSlider.availableHeight / 2 - height / 2
                width: scrubSlider.availableWidth
                height: 4
                radius: 2
                color: Theme.border

                Rectangle {
                    width: scrubSlider.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: Theme.accent
                }

                Repeater {
                    id: eventMarkers
                    objectName: "timelineEventMarkers"
                    model: root._events.filter(function(e) { return root.isEventVisible(e.eventType) })
                    delegate: Rectangle {
                        id: marker
                        required property var modelData
                        readonly property double frac: root.instantToValue(modelData.occurredAt)
                        objectName: "timelineEventMarker"
                        x: frac * parent.width - width / 2
                        y: -2
                        width: 3
                        height: parent.height + 4
                        radius: 1
                        color: EventTypeColors.colorFor(modelData.eventType)

                        TapHandler {
                            onTapped: root.seekToEvent(marker.modelData.occurredAt)
                        }
                    }
                }
            }

            handle: Rectangle {
                x: scrubSlider.leftPadding + scrubSlider.visualPosition * (scrubSlider.availableWidth - width)
                y: scrubSlider.topPadding + scrubSlider.availableHeight / 2 - height / 2
                width: 16
                height: 16
                radius: 8
                color: scrubSlider.pressed ? Qt.darker(Theme.accent, 1.1) : "white"
                border.color: Theme.accent
                border.width: 2
            }
        }

        Item {
            id: rangeLabel
            objectName: "timelineRangeLabel"
            width: rangeLabelRow.width
            height: rangeLabelRow.height
            anchors { right: legendButton.left; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }

            Row {
                id: rangeLabelRow
                spacing: Theme.spaceXs

                Text {
                    text: root.formatValueAsTime(root.sliderValue)
                    font.pixelSize: Theme.fontS
                    font.weight: Font.Medium
                    color: TimelineController.isLive ? Theme.textPrimary : Theme.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "(" + root.formatRangeLabel() + ")"
                    font.pixelSize: Theme.fontXs
                    color: Theme.textDisabled
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    dateRangeCalendar.rangeStart = root.rangeStart
                    dateRangeCalendar.rangeEnd = root.rangeEnd
                    dateRangeCalendar.open()
                }
            }
        }

        DateRangeCalendar {
            id: dateRangeCalendar
            objectName: "timelineDateRangeCalendar"
            x: rangeLabel.x + rangeLabel.width - width
            y: -height - Theme.spaceXs
            minDate: root.minSelectableDate
            maxDate: root.maxSelectableDate
            onRangeApplied: (startDate, endDate) => root.applyRange(startDate, endDate)
        }

        Item {
            id: legendButton
            objectName: "timelineLegendButton"
            width: 20; height: 20
            anchors { right: liveBadge.left; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }

            TblIcon {
                source: "qrc:/tb/eye.svg"
                size: 16
                color: legendHover.containsMouse ? Theme.textPrimary : Theme.textSecondary
                anchors.centerIn: parent
            }

            MouseArea {
                id: legendHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: eventLegend.visible ? eventLegend.close() : eventLegend.open()
            }
        }

        Popup {
            id: eventLegend
            objectName: "timelineEventLegend"
            x: legendButton.x + legendButton.width - width
            y: -height - Theme.spaceXs
            padding: Theme.spaceS
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            background: Rectangle {
                color: Theme.surfaceCard
                border.color: Theme.border
                radius: Theme.radiusM
            }

            contentItem: Column {
                spacing: Theme.spaceXs

                Repeater {
                    model: EventTypeColors.knownTypes.concat(["_other"])
                    delegate: Row {
                        id: legendRow
                        required property string modelData
                        objectName: "timelineLegendRow_" + modelData
                        spacing: Theme.spaceXs

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: legendRow.modelData === "_other" ? EventTypeColors.fallbackColor
                                 : EventTypeColors.colorFor(legendRow.modelData)
                            opacity: root.isEventVisible(legendRow.modelData === "_other" ? "" : legendRow.modelData) ? 1.0 : 0.3
                        }

                        Text {
                            text: legendRow.modelData === "_other" ? qsTr("Other") : legendRow.modelData
                            font.pixelSize: Theme.fontXs
                            color: Theme.textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        TapHandler {
                            onTapped: root.toggleEventTypeVisible(legendRow.modelData)
                        }
                    }
                }
            }
        }

        Item {
            id: liveBadge
            objectName: "timelineLiveBadge"
            width: 10
            height: 10
            anchors { right: collapseButton.left; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }

            RecordingDot { recording: TimelineController.isLive; anchors.centerIn: parent }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: root.goLive()
            }
        }

        Item {
            id: collapseButton
            objectName: "timelineCollapseButton"
            width: 28; height: 28
            anchors { right: parent.right; rightMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }

            TblIcon {
                source: "qrc:/tb/chevron-down.svg"
                rotation: 180
                color: collapseHover.containsMouse ? Theme.textPrimary : Theme.textSecondary
                size: 14
                anchors.centerIn: parent
            }

            MouseArea {
                id: collapseHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: OverlayPrefs.timelineOpen = false
            }
        }
    }
}
