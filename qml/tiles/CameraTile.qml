// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtMultimedia

Item {
    id: root

    property string cameraId: ""
    property string cameraName: ""
    property string cameraLocation: ""
    property string relayUrl: ""
    property bool isRecording: false
    // A relay request for this tile is pending a retry, so an empty
    // relayUrl still reads as "Connecting…" rather than "No live view".
    property bool awaitingRelay: false

    signal openFullScreen(string cameraId)
    // The live stream stopped delivering frames or failed, so its relay
    // should be requested again.
    signal liveStreamStalled()
    signal closeRequested(string cameraId)

    property string connectionState: "idle"
    property string thumbnailUrl: ThumbnailCache.hasThumbnail(root.cameraId)
        ? ("file://" + ThumbnailCache.thumbnailPath(root.cameraId)) : ""

    property string currentTime: ""

    // idle | resolving | ready | gap | error, only meaningful while
    // !TimelineController.isLive. The live sink below keeps its own
    // independent connectionState regardless of which one is on screen, so
    // switching back to live is instant rather than a fresh reconnect.
    property string playbackState: "idle"
    property real _pendingOffsetMs: 0
    property bool _awaitingSeek: false
    // Which recording attachAuthenticatedPlayback() last attached. A seek
    // within the same recording only needs playbackPlayer.setPosition(),
    // not a full source reload (see onPlaybackResolved below).
    property string _currentRecordingId: ""

    // The instant startPlaybackAt() most recently asked resolvePlayback()
    // for. A rapid seek can have an older response arrive after a newer
    // one, so responses are only accepted if they still match this.
    property string _lastRequestedInstant: ""

    // False while TimelineController's playback is scoped to a different
    // camera (see TimelineController.qml's scopeCameraId). This tile then
    // stays live instead of following along.
    readonly property bool _inScope: TimelineController.scopeCameraId.length === 0
                                     || TimelineController.scopeCameraId === root.cameraId
    readonly property bool _showingLive: TimelineController.isLive || !root._inScope

    function startPlaybackAt(instant) {
        if (root.cameraId.length === 0)
            return
        root.playbackState = "resolving"
        root._lastRequestedInstant = instant
        RecordingModel.resolvePlayback(root.cameraId, instant)
    }

    Connections {
        target: TimelineController
        function onIsLiveChanged() {
            if (TimelineController.isLive) {
                playbackPlayer.stop()
                root.playbackState = "idle"
                root._currentRecordingId = ""
                // Reclaims this tile's live sink immediately rather than
                // waiting on FullCameraView's teardown to notify
                // VideoSinkRegistry, since that teardown can be deferred
                // relative to this minimize click.
                sink.setVideoOutput(videoOutput.videoSink)
            } else if (root._inScope)
                root.startPlaybackAt(TimelineController.currentInstant)
        }
        function onCurrentInstantChanged() {
            if (!TimelineController.isLive && root._inScope)
                root.startPlaybackAt(TimelineController.currentInstant)
        }
        function onScopeCameraIdChanged() {
            if (TimelineController.isLive)
                return
            if (root._inScope)
                root.startPlaybackAt(TimelineController.currentInstant)
            else {
                playbackPlayer.stop()
                root.playbackState = "idle"
                root._currentRecordingId = ""
            }
        }
        function onIsPlayingChanged() {
            if (TimelineController.isLive || !root._inScope)
                return
            if (TimelineController.isPlaying)
                playbackPlayer.play()
            else
                playbackPlayer.pause()
        }
    }

    Connections {
        target: RecordingModel
        function onPlaybackResolved(camId, recordingId, streamUrl, offsetSecs, at) {
            if (camId !== root.cameraId || at !== root._lastRequestedInstant) return
            root.playbackState = "ready"
            if (recordingId === root._currentRecordingId) {
                // Same recording, so just move the playhead. Guarded against
                // an offsetSecs beyond the media's actual duration, which
                // would silently stop playback with a black picture.
                const targetMs = offsetSecs * 1000
                if (playbackPlayer.duration > 0 && targetMs > playbackPlayer.duration) {
                    root.playbackState = "gap"
                    return
                }
                playbackPlayer.setPosition(targetMs)
                if (TimelineController.isPlaying)
                    playbackPlayer.play()
                return
            }
            root._currentRecordingId = recordingId
            root._pendingOffsetMs = offsetSecs * 1000
            root._awaitingSeek = true
            // Stop before swapping sources: setSourceDevice() on an
            // actively-playing pipeline leaves the picture black.
            playbackPlayer.stop()
            // streamUrl is a Bearer-authenticated backend path, not a
            // directly-playable URL (see RecordingModel::attachAuthenticatedPlayback()).
            RecordingModel.attachAuthenticatedPlayback(playbackPlayer, streamUrl)
        }
        function onPlaybackGap(camId, nearestBefore, nearestAfter, at) {
            if (camId !== root.cameraId || at !== root._lastRequestedInstant) return
            root.playbackState = "gap"
        }
        function onPlaybackFailed(camId, message, at) {
            if (camId !== root.cameraId || at !== root._lastRequestedInstant) return
            root.playbackState = "error"
        }
    }

    function captureThumbnail() {
        if (root.connectionState !== "connected" || root.cameraId.length === 0)
            return
        videoOutput.grabToImage(function(result) {
            result.saveToFile(ThumbnailCache.thumbnailPath(root.cameraId))
            ThumbnailCache.notifyUpdated(root.cameraId)
        })
    }

    onConnectionStateChanged: {
        if (root.connectionState === "connected")
            root.captureThumbnail()
    }

    onCameraIdChanged: {
        root.thumbnailUrl = ThumbnailCache.hasThumbnail(root.cameraId)
            ? ("file://" + ThumbnailCache.thumbnailPath(root.cameraId)) : ""
        root.syncSinkRegistration()
    }

    // Registers `sink` under the current cameraId so FullCameraView can
    // borrow this tile's already-open connection instead of starting a
    // second one when maximized, and reclaims it back (see the Connections
    // block below) once FullCameraView releases it.
    property string _registeredCameraId: ""
    function syncSinkRegistration() {
        if (root._registeredCameraId === root.cameraId)
            return
        if (root._registeredCameraId.length > 0)
            VideoSinkRegistry.unregisterSink(root._registeredCameraId, sink)
        root._registeredCameraId = root.cameraId
        if (root.cameraId.length > 0)
            VideoSinkRegistry.registerSink(root.cameraId, sink)
    }

    Connections {
        target: VideoSinkRegistry
        function onReleased(camId) {
            if (camId === root.cameraId)
                sink.setVideoOutput(videoOutput.videoSink)
        }
    }

    Connections {
        target: ThumbnailCache
        function onThumbnailUpdated(camId) {
            if (camId !== root.cameraId) return
            root.thumbnailUrl = ""
            root.thumbnailUrl = "file://" + ThumbnailCache.thumbnailPath(root.cameraId)
        }
    }

    Timer {
        interval: 60000
        running: root.connectionState === "connected"
        repeat: true
        onTriggered: root.captureThumbnail()
    }

    readonly property bool needsTimestamp: OverlayPrefs.slotTl === "timestamp"
        || OverlayPrefs.slotTc === "timestamp"
        || OverlayPrefs.slotTr === "timestamp"
        || OverlayPrefs.slotBl === "timestamp"
        || OverlayPrefs.slotBc === "timestamp"
        || OverlayPrefs.slotBr === "timestamp"

    Timer {
        interval: 1000
        running: root.needsTimestamp
        repeat: true
        onTriggered: root.currentTime = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
        Component.onCompleted: root.currentTime = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
    }

    function updateStream() {
        if (relayUrl.length > 0) {
            root.connectionState = "connecting"
            sink.open(relayUrl)
        } else {
            sink.close()
            root.connectionState = "idle"
        }
    }

    Component.onCompleted: {
        updateStream()
        syncSinkRegistration()
        if (!TimelineController.isLive)
            root.startPlaybackAt(TimelineController.currentInstant)
    }
    Component.onDestruction: {
        if (root._registeredCameraId.length > 0)
            VideoSinkRegistry.unregisterSink(root._registeredCameraId, sink)
        sink.close()
    }

    onRelayUrlChanged: updateStream()

    /* ----- Video sink ----- */
    QtMultimediaVideoSink {
        id: sink
        objectName: "cameraTileLiveSink"
        onConnectedChanged: {
            if (connected)
                root.connectionState = "connected"
            else if (root.relayUrl.length > 0)
                root.connectionState = "connecting"
            else
                root.connectionState = "idle"
        }
        // Errors also end in stalled(), so the tile keeps showing
        // "Connecting…" while a fresh relay is requested.
        onStalled: {
            root.connectionState = "connecting"
            root.liveStreamStalled()
        }
    }

    /* ----- Black background (visible before stream loads) ----- */
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    /* ----- Last-known-state thumbnail (shown when stream is not connected) ----- */
    Image {
        anchors.fill: parent
        source: root.thumbnailUrl
        fillMode: Image.PreserveAspectCrop
        cache: false
    }

    /* ----- Live video ----- */
    VideoOutput {
        id: videoOutput
        objectName: "cameraTileLiveVideoOutput"
        anchors.fill: parent
        visible: root._showingLive
        Component.onCompleted: sink.setVideoOutput(videoOutput.videoSink)
    }

    /* ----- Overlay when not streaming (live mode only) ----- */
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: root._showingLive && root.connectionState !== "connected"

        Text {
            anchors.centerIn: parent
            readonly property bool _noLiveView: root.connectionState === "idle" && !root.awaitingRelay
            text: _noLiveView ? "No live view" : "Connecting…"
            font.pixelSize: Theme.fontS
            color: _noLiveView ? Theme.textDisabled : "white"
        }
    }

    /* ----- Playback video (recorded footage, shown while not live) ----- */
    VideoOutput {
        id: playbackVideoOutput
        objectName: "cameraTilePlaybackVideoOutput"
        anchors.fill: parent
        visible: !root._showingLive
    }

    MediaPlayer {
        id: playbackPlayer
        videoOutput: playbackVideoOutput

        onMediaStatusChanged: {
            if (!root._awaitingSeek)
                return
            if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) {
                root._awaitingSeek = false
                // See the same-recording branch above for why this guard exists.
                if (playbackPlayer.duration > 0 && root._pendingOffsetMs > playbackPlayer.duration) {
                    root.playbackState = "gap"
                    return
                }
                playbackPlayer.setPosition(root._pendingOffsetMs)
                if (TimelineController.isPlaying)
                    playbackPlayer.play()
            }
        }

        onErrorOccurred: (error, errorString) => { root.playbackState = "error" }
    }

    /* ----- Overlay while recorded footage isn't ready (playback mode only) ----- */
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: !root._showingLive && root.playbackState !== "ready"

        Text {
            anchors.centerIn: parent
            text: root.playbackState === "error" ? qsTr("Playback error")
                : root.playbackState === "gap"   ? qsTr("No footage at this time")
                :                                   qsTr("Loading…")
            font.pixelSize: Theme.fontS
            color: "white"
        }
    }

    /* ----- Header bar ----- */
    CameraTileHeader {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        cameraName: root.cameraName
        connectionState: root.connectionState
        backendReachable: SiteManager.activeSiteStatus === 2
        isRecording: root.isRecording
        showClose: OverlayPrefs.headerShowClose
        showExpand: OverlayPrefs.headerShowExpand
        onExpandClicked: root.openFullScreen(root.cameraId)
        onCloseClicked: root.closeRequested(root.cameraId)
    }

    /* ----- 6-slot video overlay ----- */
    CameraTileOverlay {
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        visible: OverlayPrefs.excludedCameras.indexOf(root.cameraId) === -1
        textTL: OverlayPrefs.slotTl === "timestamp" ? root.currentTime
              : OverlayPrefs.slotTl === "location"  ? root.cameraLocation
              : OverlayPrefs.slotTl === "custom"    ? OverlayPrefs.customTl : ""
        textTC: OverlayPrefs.slotTc === "timestamp" ? root.currentTime
              : OverlayPrefs.slotTc === "location"  ? root.cameraLocation
              : OverlayPrefs.slotTc === "custom"    ? OverlayPrefs.customTc : ""
        textTR: OverlayPrefs.slotTr === "timestamp" ? root.currentTime
              : OverlayPrefs.slotTr === "location"  ? root.cameraLocation
              : OverlayPrefs.slotTr === "custom"    ? OverlayPrefs.customTr : ""
        textBL: OverlayPrefs.slotBl === "timestamp" ? root.currentTime
              : OverlayPrefs.slotBl === "location"  ? root.cameraLocation
              : OverlayPrefs.slotBl === "custom"    ? OverlayPrefs.customBl : ""
        textBC: OverlayPrefs.slotBc === "timestamp" ? root.currentTime
              : OverlayPrefs.slotBc === "location"  ? root.cameraLocation
              : OverlayPrefs.slotBc === "custom"    ? OverlayPrefs.customBc : ""
        textBR: OverlayPrefs.slotBr === "timestamp" ? root.currentTime
              : OverlayPrefs.slotBr === "location"  ? root.cameraLocation
              : OverlayPrefs.slotBr === "custom"    ? OverlayPrefs.customBr : ""
        fontSize: OverlayPrefs.fontSize
        textColor: OverlayPrefs.textColor
        bgOpacity: OverlayPrefs.bgOpacity
    }

    /* ----- Double-click → full-screen ----- */
    TapHandler {
        onDoubleTapped: root.openFullScreen(root.cameraId)
    }
}
