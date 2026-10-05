// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick

// One merged recording session: time range + duration/size, click to preview
// (seeks the global TimelineController, which every live camera tile and
// FullCameraView reacts to), plus an export/download button.
Rectangle {
    id: root

    required property string cameraId
    required property string startTime
    required property string endTime
    required property var sizeBytes
    required property int index

    // True while ExportModel is tracking an export THIS row started.
    // The caller decides this (by comparing its own "which range is
    // exporting" tracker against this row's startTime) since ExportModel
    // itself only ever tracks one export job at a time, app-wide.
    property bool exportBusy: false
    // True while some OTHER row's export is in flight. Disables this
    // row's button rather than letting two exports race.
    property bool exportBlocked: false

    // Emitted right before this row calls ExportModel.requestExport().
    // The caller uses this to start tracking this row as the busy one.
    signal exportRequested()

    objectName: "recordingSessionRow_" + index
    height: 36
    color: hoverHandler.hovered ? Theme.surfaceHover
         : index % 2 === 0 ? "transparent" : Qt.rgba(1, 1, 1, 0.02)

    function formatTime(iso) {
        return iso ? Qt.formatDateTime(new Date(iso), "hh:mm:ss") : "—"
    }

    function formatDuration(startIso, endIso) {
        if (!endIso)
            return qsTr("recording…")
        const secs = Math.max(0, (new Date(endIso).getTime() - new Date(startIso).getTime()) / 1000)
        if (secs < 60)
            return Math.round(secs) + qsTr("s")
        return Math.floor(secs / 60) + qsTr("m ") + Math.round(secs % 60) + qsTr("s")
    }

    function formatSize(bytes) {
        if (bytes < 0)
            return "—"
        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(0) + " KB"
        return (bytes / (1024 * 1024)).toFixed(1) + " MB"
    }

    Column {
        anchors {
            left: parent.left; leftMargin: Theme.spaceS
            right: exportArea.left; rightMargin: Theme.spaceS
            verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.formatTime(root.startTime) + " – " + root.formatTime(root.endTime)
            font.pixelSize: Theme.fontXs
            color: Theme.textPrimary
            elide: Text.ElideRight
            width: parent.width
        }

        Text {
            text: root.formatDuration(root.startTime, root.endTime) + " · " + root.formatSize(root.sizeBytes)
            font.pixelSize: Theme.fontXs - 1
            color: Theme.textDisabled
            elide: Text.ElideRight
            width: parent.width
        }
    }

    HoverHandler { id: hoverHandler }

    TapHandler {
        // Global: every camera tile (and FullCameraView, if maximized)
        // reacts to this same instant, not just whichever camera this
        // session belongs to.
        onTapped: TimelineController.seekTo(root.startTime)
    }

    /* ----- Export action ----- */
    Item {
        id: exportArea
        width: root.exportBusy ? 70 : 24
        height: 24
        anchors { right: parent.right; rightMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }

        TblIcon {
            objectName: "recordingSessionRowExportButton_" + root.index
            visible: !root.exportBusy
            source: "qrc:/tb/download.svg"
            size: 16
            color: root.exportBlocked ? Theme.textDisabled
                 : (exportMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary)
            anchors.centerIn: parent

            MouseArea {
                id: exportMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.exportBlocked
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.exportRequested()
                    const endIso = root.endTime || new Date().toISOString()
                    ExportModel.requestExport(root.cameraId, root.startTime, endIso)
                }
            }
        }

        Text {
            objectName: "recordingSessionRowExportStatus_" + root.index
            visible: root.exportBusy && ExportModel.status !== "completed"
            anchors.centerIn: parent
            text: ExportModel.status === "failed" ? qsTr("Failed") : qsTr("Exporting…")
            font.pixelSize: Theme.fontXs - 1
            color: ExportModel.status === "failed" ? Theme.error : Theme.textSecondary
        }

        Text {
            objectName: "recordingSessionRowExportSaveButton_" + root.index
            visible: root.exportBusy && ExportModel.status === "completed"
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
