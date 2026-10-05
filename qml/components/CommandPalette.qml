// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

// Global "jump to" overlay. Ctrl+K opens this and searches cameras,
// pipelines, and sources by name at once. Declared at App.qml's root so it
// overlays every view regardless of what's on the content stack.
Item {
    id: root
    anchors.fill: parent
    visible: opened
    z: 2000

    property bool opened: false
    property string query: ""
    property int highlightedIndex: 0

    signal cameraActivated(string cameraId)
    signal pipelineActivated(string pipelineId)
    signal sourceActivated(string sourceId)

    function open() {
        root.query = ""
        root.highlightedIndex = 0
        root.opened = true
        searchField.forceActiveFocus()
    }

    function close() {
        root.opened = false
    }

    // Recomputed on every query change rather than kept reactively in sync:
    // searchableEntries() are plain Q_INVOKABLE calls with no change
    // notification, but every keystroke already re-evaluates this anyway.
    readonly property var results: {
        const q = root.query.trim().toLowerCase()
        if (q.length === 0)
            return []
        const out = []
        for (const c of CameraModel.searchableEntries())
            if (c.name.toLowerCase().includes(q))
                out.push({ type: "camera", id: c.id, name: c.name, subtitle: c.subtitle })
        for (const p of PipelineModel.searchableEntries())
            if (p.name.toLowerCase().includes(q))
                out.push({ type: "pipeline", id: p.id, name: p.name, subtitle: p.subtitle })
        for (const s of SourceModel.searchableEntries())
            if (s.name.toLowerCase().includes(q))
                out.push({ type: "source", id: s.id, name: s.name, subtitle: s.subtitle })
        return out
    }

    onResultsChanged: root.highlightedIndex = root.results.length > 0 ? 0 : -1

    function activateResult(idx) {
        if (idx < 0 || idx >= root.results.length)
            return
        const r = root.results[idx]
        root.close()
        if (r.type === "camera")
            root.cameraActivated(r.id)
        else if (r.type === "pipeline")
            root.pipelineActivated(r.id)
        else if (r.type === "source")
            root.sourceActivated(r.id)
    }

    function typeIcon(type) {
        if (type === "camera") return "qrc:/tb/camera-filled.svg"
        return "qrc:/tb/git-merge.svg"
    }

    function typeLabel(type) {
        if (type === "camera") return qsTr("Camera")
        if (type === "pipeline") return qsTr("Pipeline")
        return qsTr("Source")
    }

    /* ----- Scrim ----- */
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    /* ----- Palette box ----- */
    Rectangle {
        id: box
        width: 480
        radius: Theme.radiusM
        color: Theme.surfaceCard
        border.color: Theme.border
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 120 }
        height: contentColumn.implicitHeight + Theme.spaceM * 2

        // Swallow clicks so they don't fall through to the scrim behind.
        MouseArea { anchors.fill: parent }

        Column {
            id: contentColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spaceM }
            spacing: Theme.spaceS

            SearchBar {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Jump to a camera, pipeline, or source…")

                onTextChanged: root.query = text

                Keys.onDownPressed: root.highlightedIndex =
                    Math.min(root.highlightedIndex + 1, root.results.length - 1)
                Keys.onUpPressed: root.highlightedIndex =
                    Math.max(root.highlightedIndex - 1, 0)
                Keys.onReturnPressed: root.activateResult(root.highlightedIndex)
                Keys.onEnterPressed: root.activateResult(root.highlightedIndex)
                Keys.onEscapePressed: root.close()
            }

            Text {
                visible: root.query.length > 0 && root.results.length === 0
                text: qsTr("No matches")
                font.pixelSize: Theme.fontS
                color: Theme.textDisabled
                topPadding: Theme.spaceXs
                bottomPadding: Theme.spaceXs
            }

            ListView {
                id: resultsList
                width: parent.width
                height: Math.min(320, contentHeight)
                visible: root.results.length > 0
                clip: true
                model: root.results
                currentIndex: root.highlightedIndex
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: resultsList.width
                    height: 40
                    radius: Theme.radiusS
                    color: index === root.highlightedIndex ? Theme.surfaceHover : "transparent"

                    TblIcon {
                        id: resultIcon
                        source: root.typeIcon(modelData.type)
                        size: 16
                        color: Theme.textSecondary
                        anchors { left: parent.left; leftMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }
                    }

                    Text {
                        id: typeLabel
                        text: root.typeLabel(modelData.type)
                        font.pixelSize: Theme.fontXs
                        color: Theme.textDisabled
                        anchors { right: parent.right; rightMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }
                    }

                    Column {
                        anchors {
                            left: resultIcon.right; leftMargin: Theme.spaceS
                            right: typeLabel.left; rightMargin: Theme.spaceS
                            verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: modelData.name
                            font.pixelSize: Theme.fontS
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            visible: modelData.subtitle.length > 0
                            text: modelData.subtitle
                            font.pixelSize: Theme.fontXs
                            color: Theme.textDisabled
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.highlightedIndex = index
                        onClicked: root.activateResult(index)
                    }
                }
            }
        }
    }
}
