// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

// A small month-grid popup for picking a date range. First click sets a
// single-day range (start === end); any further click while the popup
// stays open moves the range's end (swapping if clicked before the current
// start), so the user can refine their pick with repeated clicks before
// dismissing it. Applies live on every click rather than needing a separate
// "confirm" step, since a range fetch is one cheap request, not one per day.
Popup {
    id: root
    objectName: "dateRangeCalendar"

    padding: Theme.spaceS
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // "yyyy-MM-dd", local, both inclusive. Callers seed these with the
    // currently-active range so reopening the picker reflects it.
    property string rangeStart: ""
    property string rangeEnd: ""
    // Selection is clamped to [minDate, maxDate]. maxDate is normally
    // today, minDate is today minus the retention window (no point letting
    // the user pick a day whose footage the backend has already deleted).
    required property string minDate
    required property string maxDate

    signal rangeApplied(string startDate, string endDate)

    // The month currently displayed, as the 1st of that month.
    property date viewMonth: new Date(new Date(root.rangeEnd || root.maxDate).getFullYear(),
                                       new Date(root.rangeEnd || root.maxDate).getMonth(), 1)

    function toKey(d) {
        return Qt.formatDate(d, "yyyy-MM-dd")
    }
    function inRange(key) {
        return root.rangeStart.length > 0 && key >= root.rangeStart && key <= root.rangeEnd
    }
    function isEndpoint(key) {
        return key === root.rangeStart || key === root.rangeEnd
    }
    function isSelectable(key) {
        return key >= root.minDate && key <= root.maxDate
    }

    function selectDay(key) {
        if (!isSelectable(key))
            return
        if (root.rangeStart.length === 0) {
            root.rangeStart = key
            root.rangeEnd = key
        } else if (key < root.rangeStart) {
            root.rangeStart = key
        } else {
            root.rangeEnd = key
        }
        root.rangeApplied(root.rangeStart, root.rangeEnd)
    }

    background: Rectangle {
        color: Theme.surfaceCard
        border.color: Theme.border
        radius: Theme.radiusM
    }

    contentItem: Column {
        spacing: Theme.spaceS
        width: 220

        /* ----- Month header ----- */
        Row {
            width: parent.width
            height: 24

            TblIcon {
                objectName: "dateRangeCalendarPrevMonth"
                source: "qrc:/tb/chevron-left.svg"
                size: 14
                color: prevMonthMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    id: prevMonthMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.viewMonth = new Date(root.viewMonth.getFullYear(),
                                                         root.viewMonth.getMonth() - 1, 1)
                }
            }

            Text {
                width: parent.width - 28 * 2
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(root.viewMonth, "MMMM yyyy")
                font.pixelSize: Theme.fontXs
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }

            TblIcon {
                objectName: "dateRangeCalendarNextMonth"
                source: "qrc:/tb/chevron-right.svg"
                size: 14
                color: nextMonthMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    id: nextMonthMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.viewMonth = new Date(root.viewMonth.getFullYear(),
                                                         root.viewMonth.getMonth() + 1, 1)
                }
            }
        }

        /* ----- Weekday labels ----- */
        Row {
            width: parent.width
            Repeater {
                model: [qsTr("Su"), qsTr("Mo"), qsTr("Tu"), qsTr("We"), qsTr("Th"), qsTr("Fr"), qsTr("Sa")]
                delegate: Text {
                    required property string modelData
                    width: 220 / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pixelSize: Theme.fontXs - 1
                    color: Theme.textDisabled
                }
            }
        }

        /* ----- Day grid: 6 rows x 7 columns, including leading/trailing
           days from adjacent months so the grid is always fully populated. */
        Grid {
            columns: 7
            width: parent.width

            readonly property date firstOfMonth: new Date(root.viewMonth.getFullYear(), root.viewMonth.getMonth(), 1)
            readonly property int leadingDays: firstOfMonth.getDay()
            readonly property date gridStart: new Date(firstOfMonth.getFullYear(), firstOfMonth.getMonth(),
                                                        firstOfMonth.getDate() - leadingDays)

            Repeater {
                model: 42
                delegate: Rectangle {
                    id: cell
                    required property int index
                    readonly property date cellDate: new Date(parent.gridStart.getFullYear(),
                        parent.gridStart.getMonth(), parent.gridStart.getDate() + index)
                    readonly property string cellKey: root.toKey(cellDate)
                    readonly property bool inCurrentMonth: cellDate.getMonth() === root.viewMonth.getMonth()
                    readonly property bool selectable: root.isSelectable(cellKey)

                    width: 220 / 7
                    height: width
                    radius: width / 2
                    color: root.isEndpoint(cellKey) ? Theme.accent
                         : root.inRange(cellKey) ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                         : cellHover.containsMouse && cell.selectable ? Theme.surfaceHover
                         : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: cell.cellDate.getDate()
                        font.pixelSize: Theme.fontXs
                        color: !cell.selectable ? Theme.textDisabled
                             : root.isEndpoint(cell.cellKey) ? Theme.textOnAccent
                             : !cell.inCurrentMonth ? Theme.textDisabled
                             : Theme.textPrimary
                    }

                    MouseArea {
                        id: cellHover
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: cell.selectable
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectDay(cell.cellKey)
                    }
                }
            }
        }
    }
}
