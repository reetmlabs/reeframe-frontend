// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

// Docked recordings browser, sharing the right-hand column with CameraPanel.
// Never full-screen/StackView-pushed, so live playback stays visible while
// browsing. See DockController.qml for visibility/column-height decisions.
Rectangle {
    id: root

    height: 260

    // Set by whatever hosts this panel when it's sharing space with other
    // dockable panels (see DockController.qml). dockShowPin is only ever
    // true when there's actually something to pin against.
    property bool dockShowPin: false
    property bool dockPinned: false
    signal pinToggled()

    // Emitted when a daily-summary row is double-clicked; App.qml pushes
    // FullCameraView for this camera, same as MatrixView's tile double-click.
    signal maximizeCameraRequested(string cameraId, string cameraName)


    // Driven by CameraPanel.cameraSelected by default (see App.qml wiring).
    property string syncedCameraId: ""
    property string syncedCameraName: ""

    property bool separateSelection: false
    property string manualCameraId: ""
    property string manualCameraName: ""

    readonly property string activeCameraId: root.separateSelection ? root.manualCameraId : root.syncedCameraId
    readonly property string activeCameraName: root.separateSelection ? root.manualCameraName : root.syncedCameraName

    // "yyyy-MM-dd", local, both inclusive. Deliberately NOT reset when
    // activeCameraId changes, so picking a range then switching cameras
    // keeps browsing the same range for the new camera.
    property string rangeStart: Qt.formatDate(new Date(Date.now() - 6 * 86400000), "yyyy-MM-dd")
    property string rangeEnd: Qt.formatDate(new Date(), "yyyy-MM-dd")

    // False once the user applies their own range from the picker, so the
    // refresh timer below stops sliding the window forward and leaves a
    // deliberately chosen range alone.
    property bool rangeIsDefault: true

    function applyDefaultRange() {
        root.rangeStart = Qt.formatDate(new Date(Date.now() - 6 * 86400000), "yyyy-MM-dd")
        root.rangeEnd = Qt.formatDate(new Date(), "yyyy-MM-dd")
    }

    // Nothing else here refetches on its own, so without this the panel goes
    // stale the moment it loads: still showing yesterday's date and missing
    // recordings from right after local midnight until the user switches
    // cameras or reapplies a range.
    Timer {
        objectName: "recordingsPanelRefreshTimer"
        interval: 60000
        running: root.visible
        repeat: true
        onTriggered: {
            if (root.rangeIsDefault)
                root.applyDefaultRange()
            root.refresh()
        }
    }

    // How far back the date-range picker allows selecting, read once from the
    // backend (recordings.retention_days) since older footage is presumably
    // already deleted. Falls back to a conservative default until it arrives.
    property int retentionDays: 30
    readonly property string minSelectableDate:
        Qt.formatDate(new Date(Date.now() - root.retentionDays * 86400000), "yyyy-MM-dd")
    readonly property string maxSelectableDate: Qt.formatDate(new Date(), "yyyy-MM-dd")

    Component.onCompleted: RecordingModel.fetchRetentionDays()

    Connections {
        target: RecordingModel
        function onRetentionDaysFetched(days) { root.retentionDays = days }
    }

    property var dailySummaries: []
    property bool dailySummaryLoading: false

    Connections {
        target: RecordingModel
        function onDailySummaryFetched(days) {
            root.dailySummaryLoading = false
            root.dailySummaries = days
        }
        function onDailySummaryFetchFailed(message) {
            root.dailySummaryLoading = false
            toast.show(qsTr("Couldn't load recordings: %1").arg(message))
        }
    }

    // Range (a day's 00:00 ISO instant, or a session's startTime) that ExportModel
    // is tracking. Only one export runs at a time, so other rows disable while set.
    property string _exportingRangeStart: ""

    Connections {
        target: ExportModel
        function onStatusChanged() {
            if (ExportModel.status === "failed") {
                toast.show(qsTr("Export failed: %1").arg(ExportModel.error))
                root._exportingRangeStart = ""
            }
        }
        function onDownloadCompleted(localPath) {
            toast.show(qsTr("Saved to %1").arg(localPath))
            root._exportingRangeStart = ""
        }
        function onDownloadFailed(message) {
            toast.show(qsTr("Save failed: %1").arg(message))
        }
    }

    // Entry point for FullCameraView's "Recordings" button: jumps straight
    // to a specific camera without touching whatever view is on screen.
    function showCamera(id, name) {
        root.separateSelection = true
        root.manualCameraId = id
        root.manualCameraName = name
        OverlayPrefs.recordingsPanelOpen = true
    }

    function refresh() {
        if (root.activeCameraId.length === 0)
            return
        // rangeEnd is inclusive; this endpoint's "to" is exclusive, so the
        // fetch window's upper bound is the day right after it.
        const toExclusive = Qt.formatDate(
            new Date(new Date(root.rangeEnd + "T00:00:00").getTime() + 24 * 60 * 60 * 1000),
            "yyyy-MM-dd")
        root.dailySummaryLoading = true
        RecordingModel.fetchDailySummary(root.activeCameraId, root.rangeStart, toExclusive)
    }

    onActiveCameraIdChanged: root.refresh()

    function formatRangeLabel() {
        if (root.rangeStart === root.rangeEnd)
            return Qt.formatDate(new Date(root.rangeStart + "T00:00:00"), "d MMM yyyy")
        return Qt.formatDate(new Date(root.rangeStart + "T00:00:00"), "d MMM")
            + " – " + Qt.formatDate(new Date(root.rangeEnd + "T00:00:00"), "d MMM yyyy")
    }

    function formatDayLabel(dateKey) {
        return Qt.formatDate(new Date(dateKey + "T00:00:00"), "ddd, d MMM yyyy")
    }

    function formatCoverage(totalSecs) {
        if (totalSecs <= 0)
            return qsTr("No recordings")
        const hours = Math.floor(totalSecs / 3600)
        const mins = Math.round((totalSecs % 3600) / 60)
        if (hours === 0)
            return qsTr("%1m recorded").arg(mins)
        return qsTr("%1h %2m recorded").arg(hours).arg(mins)
    }

    color: Theme.surfaceAlt

    // Declared before visualLayer (which contains the day list) so it
    // stacks on top, for the same ListView-swallows-clicks reasoning as
    // CameraPanel's own Toast placement.
    Toast {
        id: toast
        z: 10
    }

    Behavior on height {
        NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic }
    }

    Item {
        id: visualLayer
        anchors.fill: parent
        clip: true

        Rectangle {
            height: 1
            color: Theme.border
            anchors { left: parent.left; right: parent.right; top: parent.top }
        }

        Item {
            id: header
            height: 40
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 1 }

            TblIcon {
                id: headerIcon
                source: "qrc:/tb/player-play.svg"
                size: 16
                color: Theme.accent
                anchors { left: parent.left; leftMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }
            }

            Text {
                text: qsTr("Recordings")
                font.pixelSize: Theme.fontM
                font.weight: Font.Medium
                color: Theme.textPrimary
                anchors { left: headerIcon.right; leftMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }
            }

            /* Split/overlay toggle: only present while this panel is
               sharing the dock column with another open one. */
            Item {
                id: pinItem
                width: 24; height: 24
                visible: root.dockShowPin
                anchors { right: parent.right; rightMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }

                TblIcon {
                    objectName: "recordingsPanelPinButton"
                    source: "qrc:/tb/pin.svg"
                    color: root.dockPinned ? Theme.accent : (pinHover.containsMouse ? Theme.textPrimary : Theme.textSecondary)
                    size: 16
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: pinHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pinToggled()
                }
            }
        }

        Rectangle {
            id: headerDivider
            height: 1
            color: Theme.border
            anchors { left: parent.left; right: parent.right; top: header.bottom }
        }

        Item {
            anchors { left: parent.left; right: parent.right; top: headerDivider.bottom; bottom: parent.bottom }

            Column {
                id: controls
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spaceS }
                spacing: Theme.spaceXs

                Row {
                    spacing: Theme.spaceXs
                    width: parent.width

                    Checkbox {
                        id: separateCheckbox
                        objectName: "recordingsPanelSeparateCheckbox"
                        checked: root.separateSelection
                        anchors.verticalCenter: parent.verticalCenter
                        onToggled: (v) => {
                            root.separateSelection = v
                            if (v && root.manualCameraId.length === 0 && root.syncedCameraId.length > 0) {
                                root.manualCameraId = root.syncedCameraId
                                root.manualCameraName = root.syncedCameraName
                            }
                        }
                    }

                    Text {
                        text: qsTr("Select camera separately")
                        font.pixelSize: Theme.fontXs
                        color: Theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                ComboBox {
                    id: cameraCombo
                    objectName: "recordingsPanelCameraCombo"
                    visible: root.separateSelection
                    width: parent.width
                    height: 26

                    model: CameraModel
                    textRole: "cameraName"
                    valueRole: "cameraId"
                    currentIndex: CameraModel.cameraIndexById(root.manualCameraId)
                    displayText: currentIndex >= 0 ? CameraModel.cameraById(root.manualCameraId).cameraName || ""
                                                    : qsTr("(select a camera)")

                    onActivated: (idx) => {
                        if (idx < 0)
                            return
                        root.manualCameraId = cameraCombo.currentValue
                        root.manualCameraName = CameraModel.cameraById(cameraCombo.currentValue).cameraName || ""
                    }

                    background: Rectangle {
                        color: "transparent"
                        border.color: cameraCombo.activeFocus ? Theme.accent : Theme.border
                        radius: Theme.radiusS
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                    }

                    contentItem: Text {
                        leftPadding: Theme.spaceS
                        rightPadding: cameraCombo.indicator.width + Theme.spaceS
                        text: cameraCombo.displayText
                        font.pixelSize: Theme.fontXs
                        color: cameraCombo.currentIndex >= 0 ? Theme.textPrimary : Theme.textDisabled
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    indicator: TblIcon {
                        x: cameraCombo.width - width - Theme.spaceS
                        y: (cameraCombo.height - height) / 2
                        source: "qrc:/tb/chevron-down.svg"
                        size: 12
                        color: Theme.textSecondary
                    }

                    popup: Popup {
                        y: cameraCombo.height + 2
                        width: cameraCombo.width
                        padding: 4
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                        background: Rectangle {
                            color: Theme.surfaceCard
                            border.color: Theme.border
                            radius: Theme.radiusS
                        }

                        contentItem: ListView {
                            implicitHeight: Math.min(contentHeight, 160)
                            model: cameraCombo.delegateModel
                            clip: true
                            ScrollIndicator.vertical: ScrollIndicator {}
                        }
                    }
                }

                Text {
                    visible: !root.separateSelection
                    width: parent.width
                    text: root.syncedCameraId.length > 0 ? root.syncedCameraName : qsTr("No camera selected — click one in the list above")
                    font.pixelSize: Theme.fontXs
                    color: root.syncedCameraId.length > 0 ? Theme.textPrimary : Theme.textDisabled
                    elide: Text.ElideRight
                }

                /* The clickable Row is wrapped in a plain Item rather than putting the
                   MouseArea directly inside the Row: Row positioners forbid fill/left/
                   right/horizontalCenter/centerIn anchors on their own children (silently
                   ignored, with a runtime warning), and anchors.fill: parent on the
                   MouseArea only works against a plain Item ancestor. */
                Item {
                    id: rangeButton
                    visible: root.activeCameraId.length > 0
                    width: rangeRow.implicitWidth
                    height: rangeRow.implicitHeight

                    Row {
                        id: rangeRow
                        spacing: Theme.spaceXs

                        TblIcon {
                            source: "qrc:/tb/chevron-down.svg"
                            size: 12
                            color: rangeButtonHover.containsMouse ? Theme.textPrimary : Theme.textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            objectName: "recordingsPanelRangeLabel"
                            text: root.formatRangeLabel()
                            font.pixelSize: Theme.fontXs
                            color: rangeButtonHover.containsMouse ? Theme.textPrimary : Theme.textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: rangeButtonHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            calendar.rangeStart = root.rangeStart
                            calendar.rangeEnd = root.rangeEnd
                            calendar.x = 0
                            calendar.y = rangeButton.height + Theme.spaceXs
                            calendar.open()
                        }
                    }

                    DateRangeCalendar {
                        id: calendar
                        minDate: root.minSelectableDate
                        maxDate: root.maxSelectableDate
                        onRangeApplied: (startDate, endDate) => {
                            root.rangeIsDefault = false
                            root.rangeStart = startDate
                            root.rangeEnd = endDate
                            root.refresh()
                        }
                    }
                }
            }

            ListView {
                id: dayList
                objectName: "recordingsPanelDayList"
                visible: root.activeCameraId.length > 0
                anchors {
                    left: parent.left; right: parent.right
                    top: controls.bottom; topMargin: Theme.spaceXs
                    bottom: parent.bottom
                }
                clip: true
                model: root.dailySummaries

                delegate: Column {
                    id: dayRow
                    required property var modelData
                    required property int index
                    property bool expanded: false

                    readonly property string dayStartIso: new Date(modelData.date + "T00:00:00").toISOString()
                    readonly property string dayEndIso:
                        new Date(new Date(modelData.date + "T00:00:00").getTime() + 24 * 60 * 60 * 1000).toISOString()
                    readonly property bool exportBusy: root._exportingRangeStart === dayRow.dayStartIso
                    readonly property bool exportBlocked: root._exportingRangeStart.length > 0 && !dayRow.exportBusy

                    objectName: "recordingsPanelDayRow_" + index
                    width: dayList.width

                    // Single source of truth for double-clicking this row. Also called
                    // directly by tests: offscreen-platform double-click synthesis is
                    // unreliable, and TapHandler isn't a QQuickItem findChild() can locate.
                    function activateDayPlayback() {
                        if (dayRow.modelData.firstSessionStart.length === 0)
                            return
                        TimelineController.seekTo(dayRow.modelData.firstSessionStart,
                                                  root.activeCameraId)
                        root.maximizeCameraRequested(root.activeCameraId, root.activeCameraName)
                    }

                    Rectangle {
                        id: dayHeader
                        width: parent.width
                        height: 52
                        color: dayHeaderMouse.containsMouse ? Theme.surfaceHover
                             : dayRow.index % 2 === 0 ? "transparent" : Qt.rgba(1, 1, 1, 0.02)

                        // Double-click previews from the day's first actual recording, not
                        // local midnight, which would 404 as a gap. Scoped to this camera
                        // alone (see TimelineController's scopeCameraId) so other tiles stay live.
                        //
                        // MouseArea (not TapHandler) grabs the press immediately so a single
                        // click doesn't fall through to whatever's stacked underneath.
                        MouseArea {
                            id: dayHeaderMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onDoubleClicked: dayRow.activateDayPlayback()
                        }

                        Column {
                            anchors {
                                left: parent.left; leftMargin: Theme.spaceS
                                right: dayActions.left; rightMargin: Theme.spaceS
                                top: parent.top; topMargin: Theme.spaceXs
                            }
                            spacing: 2

                            Text {
                                text: root.formatDayLabel(dayRow.modelData.date)
                                font.pixelSize: Theme.fontXs
                                font.weight: Font.Medium
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: root.formatCoverage(dayRow.modelData.totalCoverageSecs)
                                font.pixelSize: Theme.fontXs - 1
                                color: Theme.textDisabled
                            }

                            RecordingCoverageBar {
                                width: parent.width
                                date: dayRow.modelData.date
                                sessions: dayRow.modelData.sessions
                            }
                        }

                        Row {
                            id: dayActions
                            spacing: Theme.spaceXs
                            anchors { right: parent.right; rightMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }

                            TblIcon {
                                objectName: "recordingsPanelDayExpandButton_" + dayRow.index
                                source: dayRow.expanded ? "qrc:/tb/chevron-down.svg" : "qrc:/tb/chevron-right.svg"
                                size: 14
                                color: expandMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary

                                MouseArea {
                                    id: expandMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: dayRow.expanded = !dayRow.expanded
                                }
                            }

                            Item {
                                width: dayRow.exportBusy ? 70 : 20
                                height: 20

                                TblIcon {
                                    objectName: "recordingsPanelDayDownloadButton_" + dayRow.index
                                    visible: !dayRow.exportBusy
                                    source: "qrc:/tb/download.svg"
                                    size: 16
                                    color: dayRow.exportBlocked ? Theme.textDisabled
                                         : (dayExportMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary)
                                    anchors.centerIn: parent

                                    MouseArea {
                                        id: dayExportMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !dayRow.exportBlocked
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root._exportingRangeStart = dayRow.dayStartIso
                                            ExportModel.requestExport(root.activeCameraId, dayRow.dayStartIso, dayRow.dayEndIso)
                                        }
                                    }
                                }

                                Text {
                                    objectName: "recordingsPanelDayExportStatus_" + dayRow.index
                                    visible: dayRow.exportBusy && ExportModel.status !== "completed"
                                    anchors.centerIn: parent
                                    text: ExportModel.status === "failed" ? qsTr("Failed") : qsTr("Exporting…")
                                    font.pixelSize: Theme.fontXs - 1
                                    color: ExportModel.status === "failed" ? Theme.error : Theme.textSecondary
                                }

                                Text {
                                    objectName: "recordingsPanelDayExportSaveButton_" + dayRow.index
                                    visible: dayRow.exportBusy && ExportModel.status === "completed"
                                    anchors.centerIn: parent
                                    text: qsTr("Save…")
                                    font.pixelSize: Theme.fontXs
                                    font.weight: Font.Medium
                                    color: Theme.accent

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const path = ExportModel.chooseSaveLocation()
                                            if (path.length > 0)
                                                ExportModel.downloadTo(path)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        id: expandArea
                        objectName: "recordingsPanelDaySessions_" + dayRow.index
                        visible: dayRow.expanded
                        width: parent.width

                        Repeater {
                            model: dayRow.modelData.sessions
                            delegate: RecordingSessionRow {
                                // index is already a required property on RecordingSessionRow
                                // (used for objectName/zebra striping); Repeater binds to it
                                // directly, so it must not be redeclared here.
                                required property var modelData

                                width: expandArea.width
                                cameraId: root.activeCameraId
                                startTime: modelData.startTime
                                endTime: modelData.endTime
                                sizeBytes: modelData.sizeBytes
                                exportBusy: root._exportingRangeStart === modelData.startTime
                                exportBlocked: root._exportingRangeStart.length > 0 && !exportBusy
                                onExportRequested: root._exportingRangeStart = modelData.startTime
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.activeCameraId.length === 0
                anchors.centerIn: parent
                width: parent.width - Theme.spaceL * 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Select a camera to view its recordings")
                font.pixelSize: Theme.fontXs
                color: Theme.textDisabled
            }

            EmptyState {
                objectName: "recordingsPanelEmptyState"
                visible: root.activeCameraId.length > 0 && root.dailySummaries.length === 0 && !root.dailySummaryLoading
                anchors.centerIn: parent
                width: Math.min(200, root.width - Theme.spaceL * 2)
                icon: "qrc:/tb/player-play.svg"
                iconSize: 28
                title: qsTr("No recordings in this range")
            }

            Text {
                visible: root.dailySummaryLoading
                anchors.centerIn: parent
                text: qsTr("Loading…")
                font.pixelSize: Theme.fontXs
                color: Theme.textDisabled
            }
        }
    }
}
