// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic
import QtMultimedia

Item {
    id: root

    focus: true
    // clear(), not pop(): this view is always the stack's only item, and
    // StackView.pop() refuses to empty the last remaining item cleanly.
    // Minimizing always drops playback back to live. A maximized playback
    // session is self-contained, so there's no prior state to restore.
    Keys.onEscapePressed: {
        root._closing = true
        TimelineController.goLive()
        root.StackView.view.clear()
    }

    // Bubbles up to App.qml, which routes this to the docked RecordingsPanel
    // instead of pushing another view over this one.
    signal viewRecordingsRequested(string cameraId, string cameraName)

    property string cameraId: ""
    property string cameraName: ""
    property string relayUrl: ""
    // The main/full-res relay (see ApiTypes.h CameraDto::mainRelayUrl) is
    // requested fresh on every open; once it arrives, localSink connects in
    // the background and takes over from the borrowed tile sink.
    property string mainRelayUrl: ""
    property bool isRecording: false
    // When false, CameraModel.startRelay()'s "sub" requests fall back to the
    // same "main" slot requested below, so closing it would pull the tile's
    // only relay out from under it.
    property bool hasSubStream: false
    // Deferred to maybeStartMainRelay() rather than started unconditionally,
    // since this view can open straight into scoped recorded playback with
    // no live video shown at all.
    property bool _mainRelayStarted: false

    // Set before minimizing/escaping, before goLive() flips isLive true.
    // Stops maybeStartMainRelay() from starting a relay this view is about
    // to stop again on its own destruction.
    property bool _closing: false

    function maybeStartMainRelay() {
        if (root._closing || root._mainRelayStarted || !root.hasSubStream || !root._showingLive)
            return
        root._mainRelayStarted = true
        CameraModel.startRelay(root.cameraId, false)
    }

    property bool recording: root.isRecording
    property bool recordingInFlight: false
    // Optimistic: if a tile's sink is being borrowed (the normal case,
    // since full-screen is only reachable from an already-live tile), that sink
    // is presumably already connected, so start "connected" instead of
    // flashing "connecting" for a stream that isn't actually restarting.
    property string connectionState: "connected"

    // The tile's already-open IVideoSink, borrowed instead of opening a
    // second connection to the same camera. Not owned here, so never close()d.
    property var borrowedSink: null
    // True once localSink has taken over rendering from borrowedSink.
    property bool _localSinkRendering: false

    // idle | resolving | ready | gap | error. Only meaningful while
    // !TimelineController.isLive. Resolved independently of the CameraTile
    // behind this view rather than sharing state via VideoSinkRegistry,
    // which only tracks live RTSP connections.
    property string playbackState: "idle"
    property real _pendingOffsetMs: 0
    property bool _awaitingSeek: false
    // Which recording attachAuthenticatedPlayback() last actually attached.
    // A seek within the same recording only needs playbackPlayer.setPosition(),
    // not a full source reload (see onPlaybackResolved below).
    property string _currentRecordingId: ""

    // See CameraTile.qml's own _lastRequestedInstant: guards against a
    // rapid double-seek's older response arriving after a newer one.
    property string _lastRequestedInstant: ""

    // See CameraTile.qml's own _inScope: guards against this view being
    // shown while TimelineController's playback is scoped to some other
    // camera (defensive; normally can't happen since maximizing a camera
    // scopes playback to that same camera).
    readonly property bool _inScope: TimelineController.scopeCameraId.length === 0
                                     || TimelineController.scopeCameraId === root.cameraId
    readonly property bool _showingLive: TimelineController.isLive || !root._inScope

    function startPlaybackAt(instant) {
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
                root.maybeStartMainRelay()
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
                // Same recording: just move the playhead. Guarded against
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
            // directly-playable URL. See RecordingModel::attachAuthenticatedPlayback().
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

    Connections {
        target: CameraModel
        function onRecordingStateChanged(camId, isRecording) {
            if (camId !== root.cameraId) return
            root.recording = isRecording
            root.recordingInFlight = false
        }
        function onRelayStateChanged(camId, url, sub) {
            if (camId !== root.cameraId) return
            if (sub) {
                root.relayUrl = url
                return
            }
            // Routing through empty forces a real property change even
            // if the backend returns the same URL.
            root.mainRelayUrl = ""
            root.mainRelayUrl = url
        }
        // The main relay this view started may be left over from before the
        // outage and silently dead, so ask for a fresh one.
        function onBackendRecovered() {
            if (root._mainRelayStarted) {
                root._mainRelayStarted = false
                root.maybeStartMainRelay()
            }
        }
    }

    Connections {
        target: root.borrowedSink
        enabled: root.borrowedSink !== null
        function onConnectedChanged() {
            root.connectionState = root.borrowedSink.connected ? "connected" : "connecting"
        }
        // The tile that owns this sink requests the fresh relay.
        function onStalled() {
            if (!root._localSinkRendering)
                root.connectionState = "connecting"
        }
    }

    // Opens once mainRelayUrl actually arrives (the request kicked off below
    // is async, so it's essentially never already set at Component.onCompleted).
    onMainRelayUrlChanged: {
        if (mainRelayUrl.length > 0)
            localSink.open(mainRelayUrl)
    }

    Component.onCompleted: {
        borrowedSink = VideoSinkRegistry.sinkFor(root.cameraId)
        if (borrowedSink) {
            borrowedSink.setVideoOutput(videoOutput.videoSink)
            connectionState = borrowedSink.connected ? "connected" : "connecting"
            // Upgrades to the main/full-res relay in the background. The
            // borrowed sink above keeps showing the tile's sub-res stream
            // until it arrives (see onMainRelayUrlChanged).
            root.maybeStartMainRelay()
        } else if (relayUrl.length > 0) {
            // Fallback: no tile currently live for this camera (shouldn't
            // normally happen, since full-screen is only reachable from an
            // active tile's expand button). Open a direct connection
            // rather than showing a permanently blank view.
            connectionState = "connecting"
            localSink.open(relayUrl)
            root.maybeStartMainRelay()
        } else {
            connectionState = "idle"
        }
        if (!TimelineController.isLive && root._inScope)
            root.startPlaybackAt(TimelineController.currentInstant)
        root.forceActiveFocus()
    }
    Component.onDestruction: {
        localSink.close()
        // Only if this view actually started it (see maybeStartMainRelay()).
        // Otherwise it's either nothing, or the tile's own relay, and
        // stopping it here would force that tile into a full reconnect.
        if (root._mainRelayStarted)
            CameraModel.stopRelay(root.cameraId, false)
        VideoSinkRegistry.notifyReleased(root.cameraId)
    }

    /* Used only for the mainRelayUrl upgrade, or as the no-tile-found
       fallback above, never for the normal borrowed-sink path. */
    QtMultimediaVideoSink {
        id: localSink
        onConnectedChanged: {
            if (connected) {
                // Upgrade (or fallback) is live, so take over rendering.
                localSink.setVideoOutput(videoOutput.videoSink)
                root._localSinkRendering = true
                root.connectionState = "connected"
            }
        }
        onStalled: {
            if (root._localSinkRendering || root.borrowedSink === null)
                root.connectionState = "connecting"
            if (root._mainRelayStarted) {
                root._mainRelayStarted = false
                root.maybeStartMainRelay()
            }
        }
    }

    /* ----- Black background ----- */
    Rectangle { anchors.fill: parent; color: "black" }

    /* ----- Full-screen video (live) ----- */
    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        visible: root._showingLive
    }

    /* ----- Not-connected overlay (live mode only) ----- */
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: root._showingLive && root.connectionState !== "connected"

        Text {
            anchors.centerIn: parent
            text: root.connectionState === "idle" ? qsTr("No live view — start relay from the camera list")
                :                                   qsTr("Connecting…")
            font.pixelSize: Theme.fontM
            color: "white"
        }
    }

    /* ----- Full-screen video (recorded footage, shown while not live) ----- */
    VideoOutput {
        id: playbackVideoOutput
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
            font.pixelSize: Theme.fontM
            color: "white"
        }
    }

    /* ----- HUD header ----- */
    Rectangle {
        id: hud
        height: 48
        color: Qt.rgba(0, 0, 0, 0.65)
        anchors { left: parent.left; right: parent.right; top: parent.top }

        /* Minimize back to the matrix. Also triggered by Escape (see root.Keys.onEscapePressed) */
        Rectangle {
            id: backBtn
            objectName: "minimizeButton"
            width: 96; height: 32; radius: Theme.radiusS
            color: backMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
            anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }

            Row {
                anchors.centerIn: parent
                spacing: Theme.spaceXs

                TblIcon {
                    source: "qrc:/tb/arrows-minimize.svg"
                    color: "white"
                    size: 16
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: qsTr("Minimize")
                    font.pixelSize: Theme.fontS
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root._closing = true
                    TimelineController.goLive()
                    root.StackView.view.clear()
                }
            }

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        /* Camera name */
        Text {
            text: root.cameraName
            font.pixelSize: Theme.fontM
            font.weight: Font.Medium
            color: "white"
            elide: Text.ElideRight
            anchors {
                left: backBtn.right; leftMargin: Theme.spaceM
                right: recordingsBtn.left; rightMargin: Theme.spaceM
                verticalCenter: parent.verticalCenter
            }
        }

        /* View recordings */
        Rectangle {
            id: recordingsBtn
            objectName: "viewRecordingsButton"
            width: 128; height: 32; radius: Theme.radiusS
            color: recordingsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.4)
            border.width: 1
            anchors { right: recBtn.left; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }

            Row {
                anchors.centerIn: parent
                spacing: Theme.spaceXs

                TblIcon {
                    source: "qrc:/tb/video.svg"
                    color: "white"
                    size: 16
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: qsTr("Recordings")
                    font.pixelSize: Theme.fontS
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: recordingsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.viewRecordingsRequested(root.cameraId, root.cameraName)
            }

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        /* Recording toggle */
        Rectangle {
            id: recBtn
            width: 160; height: 32; radius: Theme.radiusS
            enabled: !root.recordingInFlight && root._showingLive
            anchors { right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }

            color: {
                if (!enabled) return "transparent"
                if (root.recording)
                    return recMouse.containsMouse ? Qt.darker(Theme.error, 1.1) : Theme.error
                return recMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
            }
            border.color: {
                if (!enabled) return Qt.rgba(1, 1, 1, 0.2)
                return root.recording ? "transparent" : Qt.rgba(1, 1, 1, 0.4)
            }

            Row {
                anchors.centerIn: parent
                spacing: Theme.spaceS

                RecordingDot {
                    recording: root.recording
                    visible: !root.recordingInFlight
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: {
                        if (root.recordingInFlight) return "…"
                        return root.recording ? qsTr("Stop Recording") : qsTr("Start Recording")
                    }
                    font.pixelSize: Theme.fontS
                    font.weight: Font.Medium
                    color: "white"
                }
            }

            MouseArea {
                id: recMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.recordingInFlight = true
                    if (root.recording)
                        CameraModel.stopRecording(root.cameraId)
                    else
                        CameraModel.startRecording(root.cameraId)
                }
            }

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
        }
    }

    /* ----- Connection dot (bottom-left) ----- */
    Rectangle {
        width: 8; height: 8; radius: 4
        anchors { left: parent.left; bottom: parent.bottom; margins: Theme.spaceM }
        color: root.connectionState === "connected" ? Theme.success
             : root.connectionState === "error"     ? Theme.error
             :                                        Theme.warning
    }
}
