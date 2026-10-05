// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: root

    width: 280

    // Set by whatever hosts this panel when it's sharing space with other
    // dockable panels (see DockController.qml). dockShowPin is only ever
    // true when there's actually something to pin against.
    property bool dockShowPin: false
    property bool dockPinned: false
    signal pinToggled()

    property bool selectionMode: false
    property var selectedIds: []

    function isSelected(id) { return root.selectedIds.indexOf(id) !== -1 }

    function toggleSelected(id) {
        const i = root.selectedIds.indexOf(id)
        if (i === -1)
            root.selectedIds = root.selectedIds.concat([id])
        else {
            const copy = root.selectedIds.slice()
            copy.splice(i, 1)
            root.selectedIds = copy
        }
    }

    function exitSelectionMode() {
        root.selectionMode = false
        root.selectedIds = []
    }

    function batchSetEnabled(enabled) {
        for (const id of root.selectedIds)
            CameraModel.setEnabled(id, enabled)
    }

    // Distinct from selectionMode/selectedIds above (bulk checkbox ops):
    // this is the "currently focused" camera that RecordingsPanel syncs to.
    property string selectedCameraId: ""
    property string selectedCameraName: ""

    signal cameraSelected(string cameraId, string cameraName)

    function selectCamera(id, name) {
        root.selectedCameraId = id
        root.selectedCameraName = name
        root.cameraSelected(id, name)
    }

    // Set by the command palette to briefly highlight a camera row.
    property string flashCameraId: ""

    function flashCamera(id) {
        OverlayPrefs.cameraPanelOpen = true
        searchBar.text = ""
        root.exitSelectionMode()
        const idx = CameraModel.cameraIndexById(id)
        if (idx >= 0)
            cameraList.positionViewAtIndex(idx, ListView.Contain)
        root.flashCameraId = id
        flashTimer.restart()
    }

    Timer {
        id: flashTimer
        interval: 1500
        onTriggered: root.flashCameraId = ""
    }

    // Confirming a delete hides the row and schedules the real
    // CameraModel.deleteCamera() call after undoWindowMs, giving the "Undo"
    // toast action something to cancel. _deleteRequested keeps the row
    // hidden through the async delete too, since pendingDeletes.isPending()
    // alone flips false the instant the timer fires, before the row is
    // actually gone from CameraModel.
    property int undoWindowMs: 5000
    property var _deleteRequested: ({})

    function isCameraPendingDelete(id) {
        const _ = pendingDeletes.version // force re-evaluation, see PendingDeleteQueue.qml
        return pendingDeletes.isPending(id) || root._deleteRequested[id] === true
    }

    function requestDeleteCamera(id, name) {
        root._deleteRequested[id] = true
        pendingDeletes.schedule(id, root.undoWindowMs, function() {
            CameraModel.deleteCamera(id)
        })
        toast.showWithAction(qsTr("Deleted \"%1\"").arg(name), qsTr("Undo"), [id], root.undoWindowMs)
    }

    function requestBatchDeleteCameras(ids, names) {
        for (const id of ids) {
            root._deleteRequested[id] = true
            pendingDeletes.schedule(id, root.undoWindowMs, function() {
                CameraModel.deleteCamera(id)
            })
        }
        const label = ids.length === 1
            ? qsTr("Deleted \"%1\"").arg(names[0])
            : qsTr("Deleted %1 cameras").arg(ids.length)
        toast.showWithAction(label, qsTr("Undo"), ids, root.undoWindowMs)
    }

    // Cancels one or more pending deletes. The "Undo" toast action calls
    // this, and it's exposed as its own function (rather than inlined in
    // Toast.onActionTriggered) so it's directly callable from tests too.
    function undoDelete(ids) {
        for (const id of ids) {
            if (!pendingDeletes.isPending(id))
                continue
            // Clear the flag BEFORE cancel(), not after: cancel() bumps
            // PendingDeleteQueue.version synchronously, so a row binding on
            // it re-evaluates during the call, and clearing afterward would
            // leave the last id in a batch reading the stale flag.
            delete root._deleteRequested[id]
            pendingDeletes.cancel(id)
        }
    }

    PendingDeleteQueue { id: pendingDeletes }

    // Explicit z: without it, visualLayer's later declaration (which
    // contains the camera list) would stack on top and swallow clicks
    // meant for the toast's "Undo" button.
    Toast {
        id: toast
        z: 10
        onActionTriggered: (data) => root.undoDelete(data)
    }

    color: Theme.surfaceAlt

    Component.onCompleted: CameraModel.refresh()

    Behavior on height {
        NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic }
    }

    Item {
        id: visualLayer
        anchors.fill: parent
        clip: true

        Rectangle {
            width: 1
            color: Theme.border
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        }

        Item {
            id: header
            height: 44
            anchors { left: parent.left; leftMargin: 1; right: parent.right; top: parent.top }

            Text {
                text: qsTr("Cameras")
                font.pixelSize: Theme.fontM
                font.weight: Font.Medium
                color: Theme.textPrimary
                anchors { left: parent.left; leftMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }
            }

            HoverButton {
                id: selectButton
                width: 44; height: 24
                opacity: CameraModel.count > 0 ? 1.0 : 0.0
                anchors { right: addCameraButton.left; rightMargin: Theme.spaceXs; verticalCenter: parent.verticalCenter }

                text: root.selectionMode ? qsTr("Cancel") : qsTr("Select")
                fontSize: 10
                onClicked: root.selectionMode ? root.exitSelectionMode() : root.selectionMode = true

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            }

            /* Add camera button: hidden while selecting, its space is
               better spent on the batch action toolbar below. */
            HoverButton {
                id: addCameraButton
                width: 26; height: 26
                opacity: !root.selectionMode ? 1.0 : 0.0
                anchors {
                    right: root.dockShowPin ? pinItem.left : parent.right
                    rightMargin: root.dockShowPin ? Theme.spaceXs : Theme.spaceS
                    verticalCenter: parent.verticalCenter
                }

                variant: "flat"
                text: "+"
                fontSize: Theme.fontM
                showBorder: containsMouse
                borderColor: Theme.accent
                contentColor: containsMouse ? Theme.accent : Theme.textSecondary
                onClicked: addDialog.open()

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            }

            // Only present while this panel is sharing the dock column with
            // another open one.
            Item {
                id: pinItem
                width: 24; height: 24
                visible: root.dockShowPin
                anchors { right: parent.right; rightMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }

                TblIcon {
                    objectName: "cameraPanelPinButton"
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
            anchors { left: parent.left; leftMargin: 1; right: parent.right; top: header.bottom }
        }

        Item {
            anchors {
                left: parent.left; leftMargin: 1
                right: parent.right
                top: headerDivider.bottom
                bottom: parent.bottom
            }

            SearchBar {
                id: searchBar
                anchors {
                    left: parent.left; right: parent.right; top: parent.top
                    leftMargin: Theme.spaceS; rightMargin: Theme.spaceS; topMargin: Theme.spaceS
                }
            }

            Text {
                visible: CameraModel.loading
                text: qsTr("Loading…")
                font.pixelSize: Theme.fontS
                color: Theme.textDisabled
                anchors.centerIn: parent
            }

            ListView {
                id: cameraList
                model: CameraModel
                clip: true
                anchors {
                    left: parent.left; right: parent.right
                    top: searchBar.bottom; bottom: selectionToolbar.top
                    topMargin: Theme.spaceXs
                }

                delegate: Rectangle {
                    id: row
                    objectName: "cameraRow_" + cameraId

                    required property string cameraId
                    required property string cameraName
                    required property string cameraLocation
                    required property bool   cameraEnabled
                    required property string cameraRtspUrl
                    required property string cameraSubRtspUrl
                    required property string cameraUsername
                    required property bool   cameraRecording
                    required property string cameraRelayUrl

                    property string thumbnailUrl: ThumbnailCache.hasThumbnail(row.cameraId)
                        ? ("file://" + ThumbnailCache.thumbnailPath(row.cameraId)) : ""
                    // Disables the Rec/Stop button between click and the
                    // model's own recordingStateChanged reply, same reasoning
                    // as FullCameraView's recordingInFlight.
                    property bool recordingInFlight: false

                    width: cameraList.width
                    height: visible ? 52 : 0
                    visible: !root.isCameraPendingDelete(cameraId) &&
                             (searchBar.text.length === 0 ||
                              cameraName.toLowerCase().includes(searchBar.text.toLowerCase()))
                    color: row.cameraId === root.flashCameraId
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                        : root.selectedCameraId.length > 0 && row.cameraId === root.selectedCameraId
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                        : (rowHover.hovered ? Theme.surfaceHover : "transparent")

                    // Dragging onto a matrix tile assigns this camera to it. The
                    // row can't carry Drag.active itself (it never overlaps a
                    // MatrixView DropArea from inside this clipped ListView), so
                    // it drives the shared DragSession singleton instead. A
                    // ghost item at the App.qml root carries Drag and follows
                    // the cursor across the whole window.
                    z: cardDrag.active ? 100 : 0
                    opacity: cardDrag.active ? 0.6 : 1.0

                    DragHandler {
                        id: cardDrag
                        target: null
                        enabled: !root.selectionMode
                        onActiveChanged: {
                            // cameraId/cameraName MUST be set before flipping `active`:
                            // the App.qml ghost snapshots them synchronously off that
                            // change, so setting active first would hand it stale values.
                            if (active) {
                                DragSession.cameraId = row.cameraId
                                DragSession.cameraName = row.cameraName
                            }
                            DragSession.active = active
                        }
                    }

                    // restoreMode: RestoreNone. Qt6's default (RestoreBindingOrValue)
                    // snaps this back to its pre-binding value (0) the instant
                    // `when` goes false, i.e. exactly on mouse release. That
                    // raced against App.qml's imperative Drag.drop() reading
                    // DragSession's position to decide what's underneath the
                    // ghost, intermittently making the drop land nowhere.
                    Binding {
                        target: DragSession
                        property: "globalX"
                        value: cardDrag.centroid.scenePosition.x
                        when: cardDrag.active
                        restoreMode: Binding.RestoreNone
                    }
                    Binding {
                        target: DragSession
                        property: "globalY"
                        value: cardDrag.centroid.scenePosition.y
                        when: cardDrag.active
                        restoreMode: Binding.RestoreNone
                    }

                    /* Plain click selects this camera. TapHandler is used
                       instead of MouseArea so it coexists cleanly with the
                       DragHandler above rather than competing for events. */
                    TapHandler {
                        enabled: !root.selectionMode
                        onTapped: root.selectCamera(row.cameraId, row.cameraName)
                    }

                    /* Right-click: Duplicate. A TapHandler restricted to the
                       right button, same coexistence reasoning as the plain
                       TapHandler above. */
                    TapHandler {
                        enabled: !root.selectionMode
                        acceptedButtons: Qt.RightButton
                        onTapped: (eventPoint) => {
                            rowContextMenu.targetName = row.cameraName
                            rowContextMenu.targetLocation = row.cameraLocation
                            rowContextMenu.targetRtspUrl = row.cameraRtspUrl
                            rowContextMenu.targetSubRtspUrl = row.cameraSubRtspUrl
                            rowContextMenu.targetEnabled = row.cameraEnabled
                            const pos = row.mapToItem(root, eventPoint.position.x, eventPoint.position.y)
                            rowContextMenu.x = pos.x
                            rowContextMenu.y = pos.y
                            rowContextMenu.open()
                        }
                    }

                    Connections {
                        target: ThumbnailCache
                        function onThumbnailUpdated(camId) {
                            if (camId !== row.cameraId) return
                            row.thumbnailUrl = ""
                            row.thumbnailUrl = "file://" + ThumbnailCache.thumbnailPath(row.cameraId)
                        }
                    }

                    Connections {
                        target: CameraModel
                        function onRecordingStateChanged(camId, recording) {
                            if (camId === row.cameraId)
                                row.recordingInFlight = false
                        }
                    }

                    /* Selection checkbox: only takes up space while
                       selecting, so normal browsing keeps its usual layout. */
                    Checkbox {
                        id: rowCheckbox
                        visible: root.selectionMode
                        checked: root.isSelected(row.cameraId)
                        anchors { left: parent.left; leftMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }
                        onToggled: root.toggleSelected(row.cameraId)
                    }

                    Rectangle {
                        id: rowThumbnail
                        width: 48; height: 27
                        radius: Theme.radiusS
                        color: Theme.surfaceCard
                        clip: true
                        anchors {
                            left: root.selectionMode ? rowCheckbox.right : parent.left
                            leftMargin: Theme.spaceS
                            verticalCenter: parent.verticalCenter
                        }

                        Image {
                            anchors.fill: parent
                            source: row.thumbnailUrl
                            fillMode: Image.PreserveAspectCrop
                            cache: false
                        }
                    }

                    Rectangle {
                        id: enabledDot
                        width: 6; height: 6; radius: 3
                        color: row.cameraEnabled ? Theme.success : Theme.textDisabled
                        anchors { left: rowThumbnail.right; leftMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }
                    }

                    RecordingDot {
                        id: recDot
                        visible: row.cameraRecording
                        recording: row.cameraRecording
                        anchors { left: enabledDot.right; leftMargin: Theme.spaceXs; verticalCenter: parent.verticalCenter }
                    }

                    /* Camera name: right anchor is always actionRow.left,
                       not conditional on hover, so it never reflows in the
                       same frame as actionRow's hover-triggered opacity change. */
                    Text {
                        text: row.cameraName
                        font.pixelSize: Theme.fontS
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        anchors {
                            left: recDot.visible ? recDot.right : enabledDot.right
                            leftMargin: Theme.spaceS
                            right: actionRow.left
                            rightMargin: Theme.spaceS
                            verticalCenter: parent.verticalCenter
                        }
                    }

                    /* Rec/Stop + edit + delete (hover only). Uses an instant
                       visible flip rather than an opacity fade, since fading
                       would also fade in the Edit button's always-solid
                       border. */
                    Row {
                        id: actionRow
                        spacing: 2
                        visible: rowHover.hovered && !root.selectionMode
                        anchors { right: parent.right; rightMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }

                        HoverButton {
                            objectName: "recordButtonRect"
                            width: 36; height: 24
                            text: row.recordingInFlight ? "…" : (row.cameraRecording ? qsTr("Stop") : qsTr("Rec"))
                            fontSize: 10
                            enabled: !row.recordingInFlight
                            borderColor: containsMouse ? Theme.accent : Theme.border
                            onClicked: {
                                row.recordingInFlight = true
                                if (row.cameraRecording)
                                    CameraModel.stopRecording(row.cameraId)
                                else
                                    CameraModel.startRecording(row.cameraId)
                            }
                        }

                        HoverButton {
                            objectName: "editButtonRect"
                            width: 36; height: 24
                            text: qsTr("Edit")
                            fontSize: 10
                            // Accent border on hover (not the default
                            // borderHover gray), no fill animation; see
                            // HoverButton.qml for why.
                            borderColor: containsMouse ? Theme.accent : Theme.border
                            onClicked: {
                                editDialog.cameraId         = row.cameraId
                                editDialog.cameraName       = row.cameraName
                                editDialog.cameraLocation   = row.cameraLocation
                                editDialog.cameraRtspUrl    = row.cameraRtspUrl
                                editDialog.cameraSubRtspUrl = row.cameraSubRtspUrl
                                editDialog.cameraUsername   = row.cameraUsername
                                editDialog.cameraEnabled    = row.cameraEnabled
                                editDialog.open()
                            }
                        }

                        HoverButton {
                            width: 24; height: 24
                            variant: "destructive"
                            text: "×"
                            fontSize: Theme.fontM
                            // Distinct enough from the ambient background to
                            // avoid the fill-flicker risk noted in HoverButton.qml.
                            fillColor: containsMouse
                                ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15)
                                : "transparent"
                            onClicked: {
                                confirmDialog.deleteCameraId   = row.cameraId
                                confirmDialog.deleteCameraName = row.cameraName
                                confirmDialog.open()
                            }
                        }
                    }

                    HoverHandler { id: rowHover }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            Column {
                id: selectionToolbar
                visible: root.selectionMode
                height: root.selectionMode ? implicitHeight : 0
                clip: true
                spacing: Theme.spaceXs
                anchors {
                    left: parent.left; right: parent.right; bottom: parent.bottom
                    leftMargin: Theme.spaceS; rightMargin: Theme.spaceS; bottomMargin: Theme.spaceS
                }

                Rectangle { width: parent.width; height: 1; color: Theme.border }

                Text {
                    text: qsTr("%1 selected").arg(root.selectedIds.length)
                    font.pixelSize: Theme.fontXs
                    color: Theme.textSecondary
                    topPadding: Theme.spaceXs
                }

                Row {
                    spacing: Theme.spaceXs

                    HoverButton {
                        width: 54; height: 24
                        enabled: root.selectedIds.length > 0
                        text: qsTr("Enable")
                        fontSize: 10
                        onClicked: root.batchSetEnabled(true)
                    }
                    HoverButton {
                        width: 58; height: 24
                        enabled: root.selectedIds.length > 0
                        text: qsTr("Disable")
                        fontSize: 10
                        onClicked: root.batchSetEnabled(false)
                    }
                    HoverButton {
                        width: 54; height: 24
                        enabled: root.selectedIds.length > 0
                        variant: "destructive"
                        text: qsTr("Delete")
                        fontSize: 10
                        onClicked: bulkDeleteDialog.open()
                    }
                }
            }

            // Declared after cameraList so it stacks on top: ListView
            // captures press events across its full bounds even when empty.
            EmptyState {
                objectName: "cameraListEmptyState"
                visible: !CameraModel.loading && CameraModel.count === 0
                anchors.centerIn: parent
                width: Math.min(220, root.width - Theme.spaceL * 2)
                icon: "qrc:/tb/camera-filled.svg"
                title: qsTr("No cameras")
                message: qsTr("Add a camera to start viewing footage.")
                actionText: qsTr("+ Add Camera")
                onActionClicked: addDialog.open()
            }

            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        }
    }

    Loader {
        id: addDialog
        active: false
        source: Qt.resolvedUrl("../dialogs/AddCameraDialog.qml")
        // prefill is undefined for a plain "+ Add Camera" open (leaves the
        // dialog's own defaults, i.e. blank), or a {name, location, rtspUrl,
        // subRtspUrl, enabled} object for "Duplicate" (see the row context
        // menu below).
        function open(prefill) {
            active = true
            item.prefillName = prefill ? prefill.name : ""
            item.prefillLocation = prefill ? prefill.location : ""
            item.prefillRtspUrl = prefill ? prefill.rtspUrl : ""
            item.prefillSubRtspUrl = prefill ? prefill.subRtspUrl : ""
            item.prefillEnabled = prefill ? prefill.enabled : true
            item.open()
        }
    }

    EditCameraDialog { id: editDialog }

    ConfirmDialog {
        id: confirmDialog
        property string deleteCameraId:   ""
        property string deleteCameraName: ""
        title: qsTr("Delete camera")
        message: qsTr("Delete \"%1\"?").arg(deleteCameraName)
        confirmLabel: qsTr("Delete")
        onConfirmed: root.requestDeleteCamera(deleteCameraId, deleteCameraName)
    }

    ConfirmDialog {
        id: bulkDeleteDialog
        title: qsTr("Delete cameras")
        message: qsTr("Delete %1 camera(s)?").arg(root.selectedIds.length)
        confirmLabel: qsTr("Delete")
        onConfirmed: {
            const ids = root.selectedIds.slice()
            const names = ids.map(id => CameraModel.cameraById(id).cameraName || "")
            root.requestBatchDeleteCameras(ids, names)
            root.exitSelectionMode()
        }
    }

    // Right-click menu: one shared instance for every row (like editDialog/
    // confirmDialog above), positioned at the click point and populated from
    // whichever row opened it.
    Popup {
        id: rowContextMenu
        objectName: "cameraRowContextMenu"
        property string targetName: ""
        property string targetLocation: ""
        property string targetRtspUrl: ""
        property string targetSubRtspUrl: ""
        property bool   targetEnabled: true

        padding: 4
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        background: Rectangle {
            color: Theme.surfaceCard
            border.color: Theme.border
            radius: Theme.radiusS
        }

        contentItem: HoverButton {
            objectName: "duplicateCameraAction"
            width: 120
            text: qsTr("Duplicate")
            fontSize: 11
            onClicked: {
                rowContextMenu.close()
                addDialog.open({
                    name: CameraModel.nextDuplicateName(rowContextMenu.targetName),
                    location: rowContextMenu.targetLocation,
                    rtspUrl: rowContextMenu.targetRtspUrl,
                    subRtspUrl: rowContextMenu.targetSubRtspUrl,
                    enabled: rowContextMenu.targetEnabled
                })
            }
        }
    }
}
