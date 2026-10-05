// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Item {
    id: root

    /* MatrixView sits outside the overlay StackView (see App.qml), so
       CameraTile's fullscreen request is bubbled up via signal instead of
       StackView.view, which would resolve to null here. */
    signal requestFullScreen(var params)

    // Clicking a tile selects its camera in CameraPanel's list (and, through
    // that panel's own selectedCameraId, whatever else is synced to it,
    // e.g. RecordingsPanel loading that camera's recordings). Bubbled up via
    // signal for the same StackView-scoping reason as requestFullScreen
    // above: CameraPanel lives outside this view entirely.
    signal cameraTileSelected(string cameraId, string cameraName)

    // Set by App.qml from CameraPanel.selectedCameraId, so a tile can show
    // itself as selected when the same camera is selected from the list.
    // This is the reverse direction of cameraTileSelected above.
    property string selectedCameraId: ""

    /* ----- Header (profile management bar) ----- */
    Rectangle {
        id: header
        height: 44
        color: "transparent"
        anchors { left: parent.left; right: parent.right; top: parent.top }

        /* Profile label + ComboBox */
        Row {
            spacing: Theme.spaceS
            anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }

            Text {
                text: qsTr("Profile:")
                font.pixelSize: Theme.fontXs
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }

            ComboBox {
                id: profileCombo
                width: 160
                height: 28

                readonly property var profileList: {
                    TileLayoutModel.activeProfileId
                    TileLayoutModel.activeSiteId
                    const ids = TileLayoutModel.profileIds()
                    return ids.map(id => ({ id: id, name: TileLayoutModel.profileName(id) }))
                }

                model: profileList
                textRole: "name"
                currentIndex: profileList.findIndex(p => p.id === TileLayoutModel.activeProfileId)
                displayText: currentIndex >= 0 ? profileList[currentIndex].name : qsTr("(no profile)")

                onActivated: (idx) => {
                    if (idx >= 0 && idx < profileList.length)
                        TileLayoutModel.setActiveProfileId(profileList[idx].id)
                }

                background: Rectangle {
                    color: "transparent"
                    border.color: profileCombo.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radiusS
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                }

                contentItem: Text {
                    leftPadding: Theme.spaceS
                    rightPadding: profileCombo.indicator.width + Theme.spaceS
                    text: profileCombo.displayText
                    font.pixelSize: Theme.fontS
                    color: profileCombo.currentIndex >= 0 ? Theme.textPrimary : Theme.textDisabled
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                indicator: TblIcon {
                    x: profileCombo.width - width - Theme.spaceS
                    y: (profileCombo.height - height) / 2
                    source: "qrc:/tb/chevron-down.svg"
                    size: 14
                    color: Theme.textSecondary
                }

                popup: Popup {
                    y: profileCombo.height + 2
                    width: profileCombo.width
                    padding: 4
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                    background: Rectangle {
                        color: Theme.surfaceCard
                        border.color: Theme.border
                        radius: Theme.radiusS
                    }

                    contentItem: ListView {
                        implicitHeight: Math.min(contentHeight, 200)
                        model: profileCombo.delegateModel
                        clip: true
                        ScrollIndicator.vertical: ScrollIndicator {}
                    }
                }

                delegate: ItemDelegate {
                    required property var modelData
                    required property int index
                    width: profileCombo.width - 8
                    height: 32
                    padding: 0

                    background: Rectangle {
                        color: parent.highlighted ? Theme.surfaceHover : "transparent"
                        radius: Theme.radiusS
                    }

                    contentItem: Text {
                        leftPadding: Theme.spaceS
                        text: parent.modelData.name
                        font.pixelSize: Theme.fontS
                        color: Theme.textPrimary
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    highlighted: profileCombo.highlightedIndex === index
                }
            }
        }

        /* Action buttons */
        Row {
            spacing: Theme.spaceS
            anchors { right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }

            /* New */
            HoverButton {
                width: 52; height: 28
                enabled: TileLayoutModel.activeSiteId.length > 0
                text: qsTr("+ New")
                onClicked: profileDialog.openForCreate()
            }

            HoverButton {
                width: 60; height: 28
                enabled: TileLayoutModel.activeProfileId.length > 0
                text: qsTr("Rename")
                onClicked: profileDialog.openForRename()
            }

            HoverButton {
                width: 52; height: 28
                variant: "destructive"
                enabled: TileLayoutModel.activeProfileId.length > 0
                text: qsTr("Delete")
                onClicked: profileDeleteDialog.open()
            }

            HoverButton {
                width: 52; height: 28
                enabled: TileLayoutModel.activeProfileId.length > 0
                text: qsTr("Share")
                onClicked: sitePicker.open()
            }
        }

        Rectangle {
            height: 1
            color: Theme.border
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        }
    }

    /* ----- Grid ----- */
    Item {
        id: gridArea
        objectName: "matrixGridArea"
        clip: true
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }

        // Target row height a lightly-occupied grid settles on. Keeps rows a
        // sane size on a short window instead of always cramming into at
        // least 3 rows regardless of how little vertical space exists.
        readonly property int targetRowHeight: 170
        readonly property int minRowCount: Math.max(1, Math.round(height / targetRowHeight))

        /* Divides by at least minRowCount so a lightly-occupied layout keeps
           a sane tile height, but expands to fit the ghost row during drag
           so the ghost and dragged tile are never clipped outside gridArea.
           Rows compress below the target once tiles occupy more rows than
           minRowCount, since there's no scrolling to fall back on. */
        readonly property real rowHeight: {
            const maxRow = _dragActive
                ? Math.max(TileLayoutModel.maxOccupiedRow, _ghostRow)
                : TileLayoutModel.maxOccupiedRow
            return height / Math.max(minRowCount, maxRow + 1)
        }

        property bool _dragActive: false
        property int  _dragOrigCol: 0
        property int  _dragOrigRow: 0
        property int  _ghostCol: 0
        property int  _ghostRow: 0
        property int  _ghostColSpan: 1
        property int  _ghostRowSpan: 1

        /* Empty state: no site connected at all. Profiles belong to a site
           (see TileLayoutModel::createProfile), so there is nothing to
           create yet; the header's "+ New" is disabled for the same
           reason. */
        EmptyState {
            objectName: "matrixNoSiteEmptyState"
            anchors.centerIn: parent
            visible: TileLayoutModel.activeSiteId.length === 0
            icon: "qrc:/tb/layout-grid.svg"
            title: qsTr("No site connected")
            message: qsTr("Connect a site to start building a camera view.")
        }

        /* Empty state: a site is connected but has no profile (its
           auto-created default was deleted and nothing replaced it). */
        EmptyState {
            objectName: "matrixNoProfileEmptyState"
            anchors.centerIn: parent
            visible: TileLayoutModel.maxOccupiedRow < 0 && TileLayoutModel.activeSiteId.length > 0
                     && TileLayoutModel.activeProfileId.length === 0
            icon: "qrc:/tb/layout-grid.svg"
            title: qsTr("No profile selected")
            message: qsTr("Create a tile profile to start building a camera view.")
            actionText: qsTr("+ New Profile")
            onActionClicked: profileDialog.openForCreate()
        }

        EmptyState {
            anchors.centerIn: parent
            visible: TileLayoutModel.maxOccupiedRow < 0 && TileLayoutModel.activeProfileId.length > 0
            icon: "qrc:/tb/camera-filled.svg"
            title: qsTr("No cameras added")
            message: qsTr("Use the camera panel to add cameras to this view.")
            actionText: OverlayPrefs.cameraPanelOpen ? "" : qsTr("Open Camera Panel")
            onActionClicked: OverlayPrefs.cameraPanelOpen = true
        }

        /* Drop target for an "empty space" drop, i.e. not over an existing
           tile's own DropArea below, which takes priority since tiles paint
           on top of this one. Creates a new tile and assigns the dragged
           camera to it. */
        DropArea {
            id: gridDropArea
            objectName: "gridDropArea"
            anchors.fill: parent
            keys: ["cameraId"]
            onDropped: (drop) => {
                // Read the camera id from DragSession rather than
                // drop.getDataAsString("cameraId"): Drag.mimeData set on
                // the ghost in App.qml never actually reaches the drop
                // event here (DropArea sees an empty formats list even
                // though the ghost's own Drag.mimeData reads back
                // correctly right up to the drop). DragSession is the
                // reliable channel; see DragSession.qml.
                const cameraId = DragSession.cameraId
                if (TileLayoutModel.hasCameraAssigned(cameraId))
                    return
                const newId = TileLayoutModel.addTile()
                if (newId.length === 0) return
                const col = Math.max(0, Math.min(7, Math.round(drop.x / (gridArea.width / 8))))
                const row = Math.max(0, Math.round(drop.y / gridArea.rowHeight))
                // Unlike repositioning an already-placed tile, dropping a
                // brand new one pushes whatever's in the way to the right
                // instead of silently landing wherever addTile() put it.
                TileLayoutModel.moveTileWithPush(newId, col, row)
                TileLayoutModel.assignCamera(newId, cameraId)
                CameraModel.startRelay(cameraId, true) // sub quality for a grid tile
            }
        }

        Repeater {
            id: tileRepeater
            model: TileLayoutModel

            delegate: Item {
                id: tile
                objectName: "matrixTile_" + tileId
                required property string tileId
                required property int tileCol
                required property int tileRow
                required property int tileColSpan
                required property int tileRowSpan
                required property string tileCameraId

                /* Committed (model) position */
                readonly property real baseX: (tileCol / 8) * gridArea.width
                readonly property real baseY: tileRow * gridArea.rowHeight

                x: baseX + (dragHandler.active ? dragHandler.activeTranslation.x : 0)
                y: baseY + (dragHandler.active ? dragHandler.activeTranslation.y : 0)
                width: (Math.max(1, tileColSpan + resizeColDelta) / 8) * gridArea.width
                height: Math.max(1, tileRowSpan + resizeRowDelta) * gridArea.rowHeight
                z: dragHandler.active ? 10 : 0

                /* Animate to final position on drag release */
                Behavior on x {
                    enabled: !dragHandler.active
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuart }
                }
                Behavior on y {
                    enabled: !dragHandler.active
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuart }
                }

                /* Snapped drop-target grid cell */
                readonly property int snappedCol: Math.max(0, Math.min(7,
                    Math.round(tile.x / (gridArea.width / 8))))
                readonly property int snappedRow: Math.max(0,
                    Math.round(tile.y / gridArea.rowHeight))

                /* Last valid snap saved during drag.
                   snappedCol/Row re-evaluate to tileCol/tileRow the instant
                   dragHandler.active becomes false (because tile.x snaps to baseX),
                   so onActiveChanged cannot read them directly. */
                property int _snapCol: tileCol
                property int _snapRow: tileRow
                onSnappedColChanged: {
                    if (dragHandler.active) {
                        _snapCol = snappedCol
                        gridArea._ghostCol = snappedCol
                    }
                }
                onSnappedRowChanged: {
                    if (dragHandler.active) {
                        _snapRow = snappedRow
                        gridArea._ghostRow = snappedRow
                    }
                }

                /* Live resize deltas (integer columns / rows added vs. committed span) */
                property int resizeColDelta: 0
                property int resizeRowDelta: 0
                readonly property bool resizeActive: rightHandle.pressed || bottomHandle.pressed
                    || cornerHandle.pressed

                // A plain property synced explicitly (not a binding on
                // CameraModel.cameraById(), which QML can't track as a
                // dependency, since a Q_INVOKABLE return value doesn't establish
                // one). Otherwise this freezes at whatever the camera's
                // fields were the instant the tile got this camera and never
                // reflects a later recording-state/name/location change.
                property var camData: ({})
                readonly property bool hasCam: tileCameraId.length > 0
                property string tileRelayUrl: ""
                readonly property bool isSelected: tile.hasCam
                    && tile.tileCameraId === root.selectedCameraId

                function syncCamData() {
                    camData = hasCam ? CameraModel.cameraById(tileCameraId) : ({})
                }
                function syncRelayUrl() {
                    tileRelayUrl = hasCam
                        ? (CameraModel.cameraById(tileCameraId).cameraRelayUrl || "")
                        : ""
                }

                Component.onCompleted: {
                    syncCamData()
                    syncRelayUrl()
                    // A tile restored from a saved layout at app start never
                    // went through the drag-drop handlers above (the only
                    // other callers of startRelay). Without this, live
                    // view only ever worked for a camera just dragged in
                    // during the current session.
                    if (tile.hasCam)
                        CameraModel.startRelay(tile.tileCameraId, true) // sub quality
                }
                onTileCameraIdChanged: {
                    syncCamData()
                    syncRelayUrl()
                    relayRetryTimer.stop()
                    tile._relayRetryDelayMs = 2000
                }

                // Backoff for re-requesting a failed relay/start while this
                // tile still shows the same camera: 2s, 4s, 8s, then 10s.
                property int _relayRetryDelayMs: 2000
                Timer {
                    id: relayRetryTimer
                    objectName: "matrixTileRelayRetryTimer"
                    onTriggered: {
                        if (tile.hasCam)
                            CameraModel.startRelay(tile.tileCameraId, true) // sub quality
                    }
                }

                Connections {
                    target: CameraModel
                    function onModelReset() {
                        tile.syncCamData()
                        tile.syncRelayUrl()
                        // CameraModel's own list is still loading (an async
                        // GET /cameras) when this tile's Component.onCompleted
                        // first ran, so that startRelay call found no camera
                        // yet and silently no-op'd. Retry now that the list
                        // has actually landed, but only if nothing already
                        // gave this tile a live relay.
                        if (tile.hasCam && tile.tileRelayUrl.length === 0)
                            CameraModel.startRelay(tile.tileCameraId, true) // sub quality
                    }
                    function onRelayStateChanged(camId, url, sub) {
                        if (!sub || !tile.hasCam || camId !== tile.tileCameraId)
                            return
                        relayRetryTimer.stop()
                        tile._relayRetryDelayMs = 2000
                        // Routing through empty forces a real property
                        // change even if the backend returns the same URL.
                        tile.tileRelayUrl = ""
                        tile.tileRelayUrl = url
                    }
                    function onRelayStartFailed(camId, sub) {
                        if (!sub || !tile.hasCam || camId !== tile.tileCameraId)
                            return
                        relayRetryTimer.interval = tile._relayRetryDelayMs
                        relayRetryTimer.restart()
                        tile._relayRetryDelayMs = Math.min(tile._relayRetryDelayMs * 2, 10000)
                    }
                    function onRecordingStateChanged(camId, recording) {
                        if (tile.hasCam && camId === tile.tileCameraId)
                            tile.syncCamData()
                    }
                    // The relay URL a tile already has may be left over from
                    // before the outage and silently dead, so ask for a fresh
                    // one unconditionally rather than only when it's empty.
                    function onBackendRecovered() {
                        if (tile.hasCam)
                            CameraModel.startRelay(tile.tileCameraId, true) // sub quality
                    }
                }

                opacity: dragHandler.active ? 0.82 : 1.0
                Behavior on opacity { NumberAnimation { duration: 80 } }

                /* Background + empty-slot label */
                Rectangle {
                    anchors.fill: parent
                    color: Theme.surfaceCard
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        visible: !tile.hasCam
                        text: qsTr("No camera assigned")
                        font.pixelSize: Theme.fontXs
                        color: Theme.textDisabled
                    }
                }

                /* Selecting a tile mirrors selecting its camera in
                   CameraPanel's list, including whatever else is synced to
                   that selection there (e.g. RecordingsPanel's auto-loaded
                   camera). A plain TapHandler (onTapped only, no
                   onDoubleTapped) coexists with dragHandler below the same
                   way CameraPanel's own row selection coexists with its
                   drag handler: it only commits below dragHandler's own
                   move threshold, so a real drag never also selects. */
                TapHandler {
                    enabled: tile.hasCam
                    onTapped: root.cameraTileSelected(tile.tileCameraId, tile.camData.cameraName || "")
                }

                /* Drop target: assign a dragged camera to this specific tile.
                   A camera already assigned to any tile cannot be dropped
                   anywhere (including onto a different tile, or back onto
                   its own). It must be removed from its current tile first. */
                DropArea {
                    id: tileDropArea
                    anchors.fill: parent
                    keys: ["cameraId"]
                    onDropped: (drop) => {
                        // See gridDropArea's onDropped above for why this
                        // reads DragSession instead of drop.getDataAsString.
                        const newCameraId = DragSession.cameraId
                        if (TileLayoutModel.hasCameraAssigned(newCameraId))
                            return
                        if (tile.hasCam)
                            CameraModel.stopRelay(tile.tileCameraId, true) // sub quality
                        TileLayoutModel.assignCamera(tile.tileId, newCameraId)
                        CameraModel.startRelay(newCameraId, true) // sub quality
                    }
                }

                /* Camera stream */
                CameraTile {
                    objectName: "matrixTileCameraStream"
                    anchors.fill: parent
                    visible: tile.hasCam
                    // Use tileCameraId (TileLayoutModel's own record), not
                    // camData.cameraId (a CameraModel.cameraById lookup):
                    // the lookup can transiently return {} before CameraModel
                    // has loaded, which would silently empty cameraId (and
                    // break VideoSinkRegistry registration and the id passed
                    // to openFullScreen/requestFullScreen) even though
                    // tileRelayUrl above stays correct.
                    cameraId: tile.tileCameraId
                    cameraName: tile.camData.cameraName || ""
                    cameraLocation: tile.camData.cameraLocation || ""
                    relayUrl: tile.tileRelayUrl
                    isRecording: tile.camData.cameraRecording || false
                    awaitingRelay: relayRetryTimer.running
                    onLiveStreamStalled: {
                        if (tile.hasCam)
                            CameraModel.startRelay(tile.tileCameraId, true) // sub quality
                    }
                    onOpenFullScreen: (camId) => {
                        root.requestFullScreen({
                            cameraId: camId,
                            cameraName: tile.camData.cameraName,
                            relayUrl: tile.tileRelayUrl,
                            mainRelayUrl: tile.camData.cameraMainRelayUrl || "",
                            isRecording: tile.camData.cameraRecording,
                            hasSubStream: (tile.camData.cameraSubRtspUrl || "").length > 0
                        })
                    }
                    onCloseRequested: (camId) => {
                        if (tile.hasCam)
                            CameraModel.stopRelay(camId, true) // sub quality
                        TileLayoutModel.removeTile(tile.tileId)
                    }
                }

                /* Selection highlight. Same "separate layer above
                   CameraTile" reasoning as the drop highlight below: a
                   border on the background Rectangle underneath would be
                   entirely hidden behind CameraTile's video content. */
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    visible: tile.isSelected
                    border.width: 2
                    border.color: Theme.accent
                }

                /* Drop highlight: a separate layer painted above CameraTile.
                   The video content fills the same bounds as the background
                   Rectangle above and would otherwise hide its border. */
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    visible: tileDropArea.containsDrag
                    border.width: 2
                    border.color: TileLayoutModel.hasCameraAssigned(DragSession.cameraId)
                        ? Theme.error : Theme.accent
                }

                /* Right-edge resize handle */
                MouseArea {
                    id: rightHandle
                    objectName: "resizeHandleRight_" + tile.tileId
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 6
                    hoverEnabled: true
                    cursorShape: Qt.SizeHorCursor

                    property real pressGlobalX: 0
                    property int  pressColSpan: 0

                    onPressed: (mouse) => {
                        pressGlobalX = mapToItem(gridArea, mouseX, 0).x
                        pressColSpan = tile.tileColSpan
                    }
                    // Commits on every move rather than tracking a local
                    // delta and committing once on release: TileLayoutModel
                    // pushes any tile(s) in the way out of it live (see
                    // TileLayoutModel::growColSpanWithPush), so the pushed
                    // neighbor's tileCol updates and slides over immediately
                    // as this tile grows, not just once the drag ends. Also
                    // gives the grid-edge clamp free visual feedback: the
                    // tile simply stops growing once resizeTile can't apply
                    // the full requested span.
                    onPositionChanged: (mouse) => {
                        if (!pressed) return
                        const cur = mapToItem(gridArea, mouseX, 0).x
                        const delta = Math.round((cur - pressGlobalX) / (gridArea.width / 8))
                        const newSpan = Math.max(1, pressColSpan + delta)
                        TileLayoutModel.resizeTile(tile.tileId, newSpan, tile.tileRowSpan)
                    }

                    /* Subtle accent line on hover / press */
                    Rectangle {
                        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                        width: 2
                        color: rightHandle.pressed         ? Theme.accent
                             : rightHandle.containsMouse   ? Theme.border
                             :                               "transparent"
                    }
                }

                /* Bottom-edge resize handle */
                MouseArea {
                    id: bottomHandle
                    objectName: "resizeHandleBottom_" + tile.tileId
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 6
                    hoverEnabled: true
                    cursorShape: Qt.SizeVerCursor

                    property real pressGlobalY: 0
                    property int  pressRowSpan: 0

                    onPressed: (mouse) => {
                        pressGlobalY = mapToItem(gridArea, 0, mouseY).y
                        pressRowSpan = tile.tileRowSpan
                    }
                    onPositionChanged: (mouse) => {
                        if (!pressed) return
                        const cur = mapToItem(gridArea, 0, mouseY).y
                        const delta = Math.round((cur - pressGlobalY) / gridArea.rowHeight)
                        const newSpan = Math.max(1, pressRowSpan + delta)
                        tile.resizeRowDelta = newSpan - tile.tileRowSpan
                    }
                    onReleased: {
                        const newSpan = tile.tileRowSpan + tile.resizeRowDelta
                        tile.resizeRowDelta = 0
                        TileLayoutModel.resizeTile(tile.tileId, tile.tileColSpan, newSpan)
                    }

                    /* Subtle accent line on hover / press */
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 2
                        color: bottomHandle.pressed         ? Theme.accent
                             : bottomHandle.containsMouse   ? Theme.border
                             :                                "transparent"
                    }
                }

                /* Bottom-right corner resize handle (diagonal, both axes at once) */
                MouseArea {
                    id: cornerHandle
                    objectName: "resizeHandleCorner_" + tile.tileId
                    anchors { right: parent.right; bottom: parent.bottom }
                    width: 10
                    height: 10
                    hoverEnabled: true
                    cursorShape: Qt.SizeFDiagCursor
                    z: 1

                    property real pressGlobalX: 0
                    property real pressGlobalY: 0
                    property int  pressColSpan: 0
                    property int  pressRowSpan: 0

                    onPressed: (mouse) => {
                        const p = mapToItem(gridArea, mouseX, mouseY)
                        pressGlobalX = p.x
                        pressGlobalY = p.y
                        pressColSpan = tile.tileColSpan
                        pressRowSpan = tile.tileRowSpan
                    }
                    onPositionChanged: (mouse) => {
                        if (!pressed) return
                        const p = mapToItem(gridArea, mouseX, mouseY)
                        const colDelta = Math.round((p.x - pressGlobalX) / (gridArea.width / 8))
                        const rowDelta = Math.round((p.y - pressGlobalY) / gridArea.rowHeight)
                        const newColSpan = Math.max(1,
                            Math.min(8 - tile.tileCol, pressColSpan + colDelta))
                        const newRowSpan = Math.max(1, pressRowSpan + rowDelta)
                        tile.resizeColDelta = newColSpan - tile.tileColSpan
                        tile.resizeRowDelta = newRowSpan - tile.tileRowSpan
                    }
                    onReleased: {
                        const newColSpan = tile.tileColSpan + tile.resizeColDelta
                        const newRowSpan = tile.tileRowSpan + tile.resizeRowDelta
                        tile.resizeColDelta = 0
                        tile.resizeRowDelta = 0
                        TileLayoutModel.resizeTile(tile.tileId, newColSpan, newRowSpan)
                    }

                    /* Subtle accent corner mark on hover / press */
                    Rectangle {
                        anchors { right: parent.right; bottom: parent.bottom }
                        width: 6
                        height: 2
                        color: cornerHandle.pressed         ? Theme.accent
                             : cornerHandle.containsMouse   ? Theme.border
                             :                                "transparent"
                    }
                    Rectangle {
                        anchors { right: parent.right; bottom: parent.bottom }
                        width: 2
                        height: 6
                        color: cornerHandle.pressed         ? Theme.accent
                             : cornerHandle.containsMouse   ? Theme.border
                             :                                "transparent"
                    }
                }

                /* Drag handler, disabled while a resize handle is active.
                   CanTakeOverFromItems is excluded so the handler cannot steal
                   the implicit grab from the resize MouseAreas mid-drag. */
                DragHandler {
                    id: dragHandler
                    target: null
                    enabled: !tile.resizeActive
                    grabPermissions: PointerHandler.CanTakeOverFromHandlersOfSameType
                        | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                        | PointerHandler.ApprovesTakeOverByAnything
                    onActiveChanged: {
                        if (active) {
                            tile._snapCol = tile.tileCol
                            tile._snapRow = tile.tileRow
                            gridArea._dragActive = true
                            gridArea._dragOrigCol = tile.tileCol
                            gridArea._dragOrigRow = tile.tileRow
                            gridArea._ghostCol = tile.tileCol
                            gridArea._ghostRow = tile.tileRow
                            gridArea._ghostColSpan = tile.tileColSpan
                            gridArea._ghostRowSpan = tile.tileRowSpan
                        } else {
                            gridArea._dragActive = false
                            TileLayoutModel.moveTile(tile.tileId, tile._snapCol, tile._snapRow)
                        }
                    }
                }
            }
        }

        /* Drop-target ghost at gridArea level so it renders above all tile content */
        Rectangle {
            visible: gridArea._dragActive
                && (gridArea._ghostCol !== gridArea._dragOrigCol
                    || gridArea._ghostRow !== gridArea._dragOrigRow)
            x: gridArea._ghostCol * (gridArea.width / 8)
            y: gridArea._ghostRow * gridArea.rowHeight
            width: gridArea._ghostColSpan * (gridArea.width / 8)
            height: gridArea._ghostRowSpan * gridArea.rowHeight
            z: 20
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
            border.color: Theme.accent
            border.width: 2
            radius: Theme.radiusS
        }

        /* Camera-drop highlight for empty grid space. Mirrors the per-tile
           highlight in the Repeater delegate above. */
        Rectangle {
            anchors.fill: parent
            z: 20
            color: "transparent"
            visible: gridDropArea.containsDrag
            border.width: 2
            border.color: TileLayoutModel.hasCameraAssigned(DragSession.cameraId)
                ? Theme.error : Theme.accent
        }
    }

    /* ----- Dialogs ----- */
    Loader {
        id: profileDialog
        active: false
        source: Qt.resolvedUrl("../dialogs/SaveProfileDialog.qml")

        function openForCreate() {
            active = true
            item.mode = "create"
            item.initialName = ""
            item.open()
        }

        function openForRename() {
            active = true
            item.mode = "rename"
            item.initialName = TileLayoutModel.profileName(TileLayoutModel.activeProfileId)
            item.open()
        }

        onLoaded: {
            item.confirmed.connect(function(name) {
                if (item.mode === "create") {
                    const newId = TileLayoutModel.createProfile(name)
                    if (newId.length > 0)
                        TileLayoutModel.setActiveProfileId(newId)
                } else {
                    TileLayoutModel.renameProfile(TileLayoutModel.activeProfileId, name)
                }
            })
        }
    }

    Loader {
        id: profileDeleteDialog
        active: false
        source: Qt.resolvedUrl("../components/ConfirmDialog.qml")

        function open() {
            active = true
            const name = TileLayoutModel.profileName(TileLayoutModel.activeProfileId)
            item.title = qsTr("Delete profile")
            item.message = qsTr("Delete \"%1\"? All tile formations in this profile will be permanently removed.").arg(name)
            item.confirmLabel = qsTr("Delete")
            item.open()
        }

        onLoaded: {
            item.confirmed.connect(function() {
                TileLayoutModel.deleteProfile(TileLayoutModel.activeProfileId)
            })
        }
    }

    /* Site picker popup for Share */
    Popup {
        id: sitePicker
        modal: true
        anchors.centerIn: Overlay.overlay
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surfaceCard
            border.color: Theme.border
            radius: Theme.radiusM
        }

        Overlay.modal: Rectangle {
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        contentItem: Item {
            implicitWidth: 280
            implicitHeight: sitePickerCol.implicitHeight + Theme.spaceXl * 2

            Column {
                id: sitePickerCol
                anchors {
                    left: parent.left; right: parent.right; top: parent.top
                    margins: Theme.spaceXl
                }
                spacing: Theme.spaceM

                Text {
                    text: qsTr("Share with site")
                    font.pixelSize: Theme.fontL
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                }

                Text {
                    text: qsTr("The tile formation will be visible on the selected site.")
                    font.pixelSize: Theme.fontXs
                    color: Theme.textSecondary
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Repeater {
                    model: SiteManager

                    Rectangle {
                        required property string siteId
                        required property string siteName

                        width: sitePickerCol.width
                        height: 36
                        radius: Theme.radiusS
                        color: siteItemMouse.containsMouse ? Theme.surfaceHover : "transparent"

                        Text {
                            anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                            text: siteName
                            font.pixelSize: Theme.fontS
                            color: Theme.textPrimary
                        }

                        MouseArea {
                            id: siteItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                TileLayoutModel.assignProfileToSite(TileLayoutModel.activeProfileId, siteId)
                                sitePicker.close()
                            }
                        }

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    }
                }
            }
        }
    }
}
