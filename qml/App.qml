// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Item {
    id: root

    // Shared by both maximize entry points: MatrixView's own tile
    // double-click, and RecordingsPanel's daily-summary row double-click.
    function openFullCameraView(params) {
        const view = stack.push(Qt.resolvedUrl("views/FullCameraView.qml"), params)
        view.viewRecordingsRequested.connect(function(camId, camName) {
            recordingsPanel.showCamera(camId, camName)
            dockController.bringToFront("recordings")
        })
        return view
    }

    /* ----- Top bar ----- */
    TopBar {
        id: topBar
        objectName: "topBar"
        anchors { left: parent.left; right: parent.right; top: parent.top }
        sidebarCollapsed: sidebar.collapsed
        onSidebarToggleClicked: sidebar.collapsed = !sidebar.collapsed
        onSignInRequested: root._maybeShowCoordinatorSignIn()
    }

    /* ----- Status bar ----- */
    StatusBar {
        id: statusBar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    }

    /* ----- Sidebar ----- */
    Sidebar {
        id: sidebar
        anchors { left: parent.left; top: topBar.bottom; bottom: statusBar.top }
    }

    /* ----- Right dock -----
       A persistent icon rail plus a content column showing whichever
       panels are currently open. One open panel fills the whole column;
       two overlap with only the front one visible until pinned, at which
       point they split the column's height evenly. dockController tracks
       open/front/split state by panel id. This block is the only place
       that knows "cameras" and "recordings" are the two panels that exist. */
    DockController { id: dockController; objectName: "rightDockController" }

    Connections {
        target: OverlayPrefs
        function onCameraPanelOpenChanged() {
            dockController.setOpen("cameras", OverlayPrefs.cameraPanelOpen)
        }
        function onRecordingsPanelOpenChanged() {
            dockController.setOpen("recordings", OverlayPrefs.recordingsPanelOpen)
        }
    }

    // DockController itself never persists front/back order (see its own
    // header comment); only OverlayPrefs.cameraPanelOpen/recordingsPanelOpen
    // are saved. Without this, the front panel would reset on every launch
    // to whichever one rightDock.Component.onCompleted below adds last.
    Connections {
        target: dockController
        function onOrderChanged() {
            if (dockController.count > 0)
                OverlayPrefs.frontDockPanel = dockController.order[dockController.order.length - 1]
        }
    }

    Item {
        id: rightDock
        objectName: "rightDock"
        z: 1
        anchors { right: parent.right; top: topBar.bottom; bottom: statusBar.top }
        width: dockRail.width + dockContent.width

        function openPanel(id) {
            if (id === "cameras")
                OverlayPrefs.cameraPanelOpen = true
            else if (id === "recordings")
                OverlayPrefs.recordingsPanelOpen = true
        }

        function closePanel(id) {
            if (id === "cameras")
                OverlayPrefs.cameraPanelOpen = false
            else if (id === "recordings")
                OverlayPrefs.recordingsPanelOpen = false
        }

        function handleRailClick(id) {
            if (!dockController.isOpen(id))
                rightDock.openPanel(id)
            else if (dockController.isFront(id))
                rightDock.closePanel(id)
            else
                dockController.bringToFront(id)
        }

        Component.onCompleted: {
            // Captured before either setOpen() call below, since each one
            // triggers the persist-on-change Connections above and would
            // otherwise clobber this with "recordings" (the fixed call
            // order's own last-added panel) before it's ever read.
            const savedFrontPanel = OverlayPrefs.frontDockPanel
            dockController.setOpen("cameras", OverlayPrefs.cameraPanelOpen)
            dockController.setOpen("recordings", OverlayPrefs.recordingsPanelOpen)
            // The two setOpen() calls above always add "recordings" last
            // (and therefore front) whenever both are open, so restore
            // whichever panel was front last time, if it's open now.
            dockController.bringToFront(savedFrontPanel)
        }

        Item {
            id: dockContent
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: dockController.count > 0 ? 280 : 0
            clip: true

            readonly property real slotHeight: dockController.count > 0
                ? height / dockController.count : height

            CameraPanel {
                id: cameraPanel
                objectName: "cameraPanel"
                width: dockContent.width
                height: dockController.splitMode ? dockContent.slotHeight : dockContent.height
                y: 0
                visible: dockController.isOpen("cameras")
                z: dockController.indexOf("cameras")

                dockShowPin: dockController.count >= 2 && dockController.isFront("cameras")
                dockPinned: dockController.splitMode
                onPinToggled: dockController.togglePin()
            }

            RecordingsPanel {
                id: recordingsPanel
                objectName: "recordingsPanel"
                width: dockContent.width
                height: dockController.splitMode ? dockContent.slotHeight : dockContent.height
                y: dockController.splitMode ? dockContent.slotHeight : 0
                visible: dockController.isOpen("recordings")
                z: dockController.indexOf("recordings")

                syncedCameraId: cameraPanel.selectedCameraId
                syncedCameraName: cameraPanel.selectedCameraName

                dockShowPin: dockController.count >= 2 && dockController.isFront("recordings")
                dockPinned: dockController.splitMode
                onPinToggled: dockController.togglePin()
            }
        }

        DockRail {
            id: dockRail
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            controller: dockController
            entries: [
                { id: "cameras", icon: "qrc:/tb/video.svg" },
                { id: "recordings", icon: "qrc:/tb/player-play.svg" }
            ]
            onEntryClicked: (id) => rightDock.handleRailClick(id)
        }
    }

    /* ----- Timeline bar -----
       Shared by both tile mode (MatrixView) and maximized mode
       (FullCameraView). It's the one control that drives TimelineController,
       which every camera tile and FullCameraView read to decide whether to
       show live video or a resolved recording. Lives outside both of them
       so it stays put across that switch, and collapses down to a thin
       strip for more matrix space without affecting either view's own
       layout. */
    TimelineBar {
        id: timelineBar
        objectName: "timelineBar"
        anchors { left: sidebar.right; right: rightDock.left; bottom: statusBar.top }
    }

    /* ----- Content area ----- */
    Item {
        id: contentArea
        anchors { left: sidebar.right; right: rightDock.left; top: topBar.bottom; bottom: timelineBar.top }

        /* MatrixView is permanent (never destroyed), so video keeps running */
        MatrixView {
            id: matrixView
            objectName: "matrixView"
            anchors.fill: parent
            selectedCameraId: cameraPanel.selectedCameraId
            onCameraTileSelected: (cameraId, cameraName) => cameraPanel.selectCamera(cameraId, cameraName)
        }

        /* Overlay stack. Solid background prevents matrix showing through;
           views are created and destroyed normally via replace() */
        StackView {
            id: stack
            objectName: "overlayStack"
            anchors.fill: parent
            visible: depth > 0
            clip: true

            background: Rectangle { color: Theme.surface }

            replaceEnter: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast; easing.type: Easing.OutCubic }
            }
            replaceExit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durationFast; easing.type: Easing.OutCubic }
            }
        }

        Component.onCompleted: {
            sidebar.onNavigateTo.connect(function(url) {
                if (url.toString().indexOf("MatrixView") !== -1)
                    stack.clear()
                else if (stack.depth === 0)
                    stack.push(url)
                else
                    stack.replace(url)
            })
            matrixView.onRequestFullScreen.connect(function(params) {
                root.openFullCameraView(params)
            })
            // The day row itself already called TimelineController.seekTo()
            // scoped to this camera before emitting this (see
            // RecordingsPanel.qml's day-row double-click handler).
            recordingsPanel.maximizeCameraRequested.connect(function(camId, camName) {
                const cam = CameraModel.cameraById(camId)
                root.openFullCameraView({
                    cameraId: camId,
                    cameraName: camName,
                    relayUrl: cam.cameraRelayUrl || "",
                    mainRelayUrl: cam.cameraMainRelayUrl || "",
                    isRecording: cam.cameraRecording || false,
                    hasSubStream: (cam.cameraSubRtspUrl || "").length > 0
                })
            })
        }
    }

    /* ----- Camera drag ghost -----
       Root-level so its coordinate space spans the whole window, crossing
       from CameraPanel into MatrixView. Tracks DragSession's live cursor
       position and is the item DropArea.containsDrag actually checks
       against. See DragSession.qml for why this indirection exists. */
    Rectangle {
        id: dragGhost
        objectName: "dragGhost"
        visible: DragSession.active
        z: 1000
        width: 160
        height: 32
        x: DragSession.globalX - width / 2
        y: DragSession.globalY - height / 2
        radius: Theme.radiusS
        color: Theme.surfaceCard
        border.color: blocked ? Theme.error : Theme.accent
        border.width: 1
        opacity: 0.9

        // A camera already assigned to a tile cannot be dropped anywhere.
        // MatrixView.qml's DropArea handlers enforce this on the drop side;
        // this mirrors it as drag feedback.
        readonly property bool blocked: DragSession.active
            && TileLayoutModel.hasCameraAssigned(DragSession.cameraId)

        /* Drag.keys is still used for DropArea matching/highlighting
           (containsDrag), but the actual payload is read from DragSession
           directly by the DropArea handlers in MatrixView.qml, not via
           Drag.mimeData/getDataAsString. mimeData set here never reaches
           the drop event (DropArea always sees an empty formats list, even
           though Drag.mimeData read back off this item shows the right
           value right up to the drop). Both ends already share
           DragSession, so it carries the payload instead. */
        Drag.keys: ["cameraId"]
        Drag.hotSpot: Qt.point(width / 2, height / 2)

        /* Drag.start()/drop() are called imperatively rather than via a
           reactive Drag.active binding: binding active straight to
           DragSession.active tracks position/DropArea overlap fine, but
           never actually delivers a drop to the DropArea underneath when
           it goes back to false. Only an explicit Drag.drop() call does. */
        Connections {
            target: DragSession
            function onActiveChanged() {
                if (DragSession.active)
                    dragGhost.Drag.start()
                else
                    dragGhost.Drag.drop()
            }
        }

        Text {
            anchors { left: parent.left; right: errorIcon.left; verticalCenter: parent.verticalCenter }
            anchors.margins: Theme.spaceS
            text: DragSession.cameraName
            color: Theme.textPrimary
            font.pixelSize: Theme.fontXs
            elide: Text.ElideRight
        }

        TblIcon {
            id: errorIcon
            visible: dragGhost.blocked
            source: "qrc:/tb/x.svg"
            color: Theme.error
            size: 14
            anchors { right: parent.right; rightMargin: Theme.spaceXs; verticalCenter: parent.verticalCenter }
        }
    }

    /* ----- Global command palette -----
       Root-level, above dragGhost's z: 1000, so it overlays every view
       regardless of what's currently pushed on the content stack. */
    CommandPalette {
        id: commandPalette
        objectName: "commandPalette"

        onCameraActivated: (cameraId) => {
            cameraPanel.flashCamera(cameraId)
            dockController.bringToFront("cameras")
        }

        onPipelineActivated: (pipelineId) => {
            sidebar.currentIndex = 1
            sidebar.navigateTo(Qt.resolvedUrl("views/PipelineListView.qml"))
            if (stack.currentItem && stack.currentItem.expandPipeline)
                stack.currentItem.expandPipeline(pipelineId)
        }

        onSourceActivated: (sourceId) => {
            sidebar.currentIndex = 2
            sidebar.navigateTo(Qt.resolvedUrl("views/SourceListView.qml"))
            if (stack.currentItem && stack.currentItem.flashSource)
                stack.currentItem.flashSource(sourceId)
        }
    }

    Shortcut {
        sequence: "Ctrl+K"
        context: Qt.ApplicationShortcut
        onActivated: commandPalette.open()
    }

    /* ----- Global undo-delete toast -----
       Backs PendingDeletes.qml (see that file for why a global singleton is
       needed instead of the local PendingDeleteQueue + Toast pair CameraPanel
       still uses): a page-local Toast would be destroyed by App.qml's own
       StackView before a deferred delete could show anything. */
    Toast {
        id: globalToast
        objectName: "globalToast"
        z: 1500
    }

    Connections {
        target: PendingDeletes
        function onToastRequested(message, ids, durationMs) {
            globalToast.showWithAction(message, "Undo", ids, durationMs)
        }
    }

    Connections {
        target: globalToast
        function onActionTriggered(ids) {
            for (const id of ids)
                PendingDeletes.cancel(id)
        }
    }

    // The deferred delete committed above failed on the backend: un-hide the
    // row (it was never really deleted) and say why, rather than leaving it
    // hidden with no explanation until the app restarts.
    Connections {
        target: PipelineModel
        function onDeletePipelineFailed(id, message) {
            PendingDeletes.clearFailed(id)
            globalToast.show(qsTr("Couldn't delete pipeline: %1").arg(message), 5000)
        }
    }

    // Sources and Destinations defer their delete through this same global
    // singleton (see SourceListView.qml), with the same failure handling.
    Connections {
        target: SourceModel
        function onDeleteSourceFailed(id, message) {
            PendingDeletes.clearFailed(id)
            globalToast.show(qsTr("Couldn't delete source: %1").arg(message), 5000)
        }
    }

    Connections {
        target: DestinationModel
        function onDeleteDestinationFailed(id, message) {
            PendingDeletes.clearFailed(id)
            globalToast.show(qsTr("Couldn't delete destination: %1").arg(message), 5000)
        }
    }

    /* ----- Sign-in gate -----
       Every route but the health check requires a valid session, so this
       blocks the entire shell (above every other overlay) whenever the
       active site has a configured node but no session yet. Coordinator
       mode is the exception: there's nothing to enter per-BE, so it pops
       the Coordinator sign-in dialog on top of the (still usable) shell
       instead of a full-screen gate. */
    readonly property var _activeClient: SiteManager.activeSiteId.length > 0
        ? SiteManager.clientForSite(SiteManager.activeSiteId) : null
    readonly property bool needsLogin: root._activeClient !== null && !root._activeClient.hasSession
    readonly property bool _activeSiteIsCoordinator: SiteManager.activeSiteCoordinatorUrl.length > 0

    LoginView {
        id: loginView
        objectName: "loginView"
        anchors.fill: parent
        z: 2000
        visible: root.needsLogin && !root._activeSiteIsCoordinator
        siteName: SiteManager.activeSiteName
        client: root._activeClient
    }

    CoordinatorLoginDialog {
        id: coordinatorSignInDialog
        objectName: "coordinatorSignInDialog"
    }

    // Checks CoordinatorManager directly rather than SiteManager's active site:
    // SiteManager only learns about a Coordinator site via GET /me/sites, which
    // itself requires the Coordinator session that's missing here.
    function _firstUnsignedCoordinatorUrl() {
        const urls = CoordinatorManager.urls()
        for (let i = 0; i < urls.length; i++) {
            if (!CoordinatorManager.hasSession(urls[i]))
                return urls[i]
        }
        return ""
    }

    function _maybeShowCoordinatorSignIn() {
        const url = root._firstUnsignedCoordinatorUrl()
        if (url.length === 0)
            return
        coordinatorSignInDialog.coordinatorUrl = url
        coordinatorSignInDialog.client = CoordinatorManager.clientFor(url)
        // Deferred: opening a modal Popup during the initial component
        // construction pass (e.g. right from Component.onCompleted, before
        // the ApplicationWindow's Overlay has ever rendered a frame) shows
        // the dialog's content but silently drops its Overlay.modal dim.
        // Every other Popup.open() call in this app happens from a click
        // handler, after the window is already on screen.
        Qt.callLater(coordinatorSignInDialog.open)
    }

    Component.onCompleted: root._maybeShowCoordinatorSignIn()

    // countChanged/sessionsChanged fire on any connection add/remove or
    // sign-in/out; activeSiteChanged fires once SiteManager rebuilds after
    // either. Deliberately not re-checked on a plain dialog close/cancel,
    // or dismissing it would just reopen it immediately.
    Connections {
        target: CoordinatorManager
        function onCountChanged() { root._maybeShowCoordinatorSignIn() }
        function onSessionsChanged() { root._maybeShowCoordinatorSignIn() }
    }

    Connections {
        target: SiteManager
        function onActiveSiteChanged() { root._maybeShowCoordinatorSignIn() }
    }
}
