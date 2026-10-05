// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: panelRoot

    property var nodeData: ({})

    readonly property string nodeId: nodeData.id !== undefined ? nodeData.id : ""
    readonly property string dagNodeType: nodeData.type || ""
    readonly property string currentActionType: {
        const cfg = nodeData.config
        return (cfg && cfg.action_type) ? cfg.action_type : ""
    }

    color: Theme.surface

    Rectangle {
        anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
        width: 1
        color: Theme.border
    }

    readonly property var actionTypeOptions: {
        const none = { value: "", text: qsTr("Select type…") }
        if (dagNodeType === "device_control") {
            return [
                none,
                { value: "start_recording",     text: qsTr("Start recording") },
                { value: "stop_recording",       text: qsTr("Stop recording") },
                { value: "ptz_move",             text: qsTr("PTZ move") },
                { value: "set_stream_quality",   text: qsTr("Set stream quality") },
                { value: "trigger_alarm_output", text: qsTr("Trigger alarm output") },
            ]
        }
        return [
            none,
            { value: "delay",               text: qsTr("Delay") },
            { value: "render_notification", text: qsTr("Render notification") },
            { value: "extract_clip",        text: qsTr("Extract clip") },
            { value: "snapshot",            text: qsTr("Snapshot") },
            { value: "transcode",           text: qsTr("Transcode") },
            { value: "watermark",           text: qsTr("Watermark") },
            { value: "merge_clips",         text: qsTr("Merge clips") },
            { value: "compress",            text: qsTr("Compress") },
            { value: "encrypt",             text: qsTr("Encrypt") },
            { value: "skip",                text: qsTr("Skip (no-op)") },
        ]
    }

    // Wire-value arrays for each type-specific combo, shared between
    // commitConfig() (index → value) and resetFromConfig() (value → index)
    // so the two directions can't drift apart.
    readonly property var renderNotificationFormats: ["text", "html", "markdown"]
    readonly property var snapshotFormats: ["jpeg", "png"]
    readonly property var transcodeCodecs: ["h264", "h265", "vp9", "av1"]
    // "" (Auto) means no resolution override: cfg.resolution is omitted entirely.
    readonly property var transcodeResolutions: ["", "3840x2160", "2560x1440", "1920x1080", "1280x720", "854x480"]
    readonly property var transcodePresets: ["ultrafast", "fast", "medium", "slow"]
    readonly property var videoOutputFormats: ["mp4", "mkv"]
    readonly property var watermarkPositions: ["top_left", "top_right", "bottom_left", "bottom_right", "center"]
    readonly property var mergeClipsOrders: ["chronological", "reverse_chronological"]
    readonly property var mergeClipsGapFills: ["black_frame", "freeze", "skip"]
    readonly property var compressAlgorithms: ["zstd", "gzip", "lz4"]
    readonly property var ptzModes: ["preset", "absolute", "relative"]

    // Index of `val` in `values`, or `fallback` when absent (a fresh node's
    // config won't have this field at all yet).
    function comboIndexOr(values, val, fallback) {
        const i = values.indexOf(val)
        return i >= 0 ? i : fallback
    }

    function findActionTypeIndex(val) {
        const m = actionTypeOptions
        for (let i = 0; i < m.length; i++) {
            if (m[i].value === val) return i
        }
        return 0
    }

    function resetFromConfig() {
        if (nodeId === "") return
        const cfg = nodeData.config || {}
        labelField.text = nodeData.label || ""
        actionTypeCombo.currentIndex = findActionTypeIndex(cfg.action_type || "")
        // All three device_control action types key their camera under the
        // same "camera_id" field, and only one is visible per node at a time.
        srCameraCombo.cameraId = cfg.camera_id || ""
        srDurationBox.value = cfg.duration_secs !== undefined ? cfg.duration_secs : 0
        srQualityField.text = cfg.quality || ""
        stCameraCombo.cameraId = cfg.camera_id || ""
        ptzCameraCombo.cameraId = cfg.camera_id || ""

        delayDurationBox.value = cfg.duration_secs !== undefined ? cfg.duration_secs : 0

        rnTemplateArea.text = cfg.template || ""
        rnFormatCombo.currentIndex = comboIndexOr(renderNotificationFormats, cfg.format, 0)

        ecPreBox.value = cfg.pre_event_secs !== undefined ? cfg.pre_event_secs : 0
        ecPostBox.value = cfg.post_event_secs !== undefined ? cfg.post_event_secs : 0
        ecFormatField.text = cfg.format || ""
        ecCameraField.cameraId = cfg.camera_id || ""
        ecManualToggle.checked = cfg.use_manual_range || false

        snapFormatCombo.currentIndex = comboIndexOr(snapshotFormats, cfg.format, 0)
        snapQualitySlider.value = cfg.quality !== undefined ? cfg.quality : 85
        snapCameraField.cameraId = cfg.camera_id || ""

        tcCodecCombo.currentIndex = comboIndexOr(transcodeCodecs, cfg.codec, 0)
        tcBitrateBox.value = cfg.bitrate_kbps !== undefined ? cfg.bitrate_kbps : 0
        tcResCombo.currentIndex = comboIndexOr(transcodeResolutions, cfg.resolution || "", 0)
        tcPresetCombo.currentIndex = comboIndexOr(transcodePresets, cfg.preset, 1)
        tcFormatCombo.currentIndex = comboIndexOr(videoOutputFormats, cfg.output_format, 0)

        wmTemplateArea.text = cfg.text_template || ""
        wmPosCombo.currentIndex = comboIndexOr(watermarkPositions, cfg.position, 2)
        wmFontBox.value = cfg.font_size !== undefined ? cfg.font_size : 24
        wmOpacitySlider.value = cfg.opacity !== undefined ? cfg.opacity : 0.8

        mcOrderCombo.currentIndex = comboIndexOr(mergeClipsOrders, cfg.order, 0)
        mcGapCombo.currentIndex = comboIndexOr(mergeClipsGapFills, cfg.gap_fill, 0)
        mcFormatCombo.currentIndex = comboIndexOr(videoOutputFormats, cfg.output_format, 0)

        czAlgoCombo.currentIndex = comboIndexOr(compressAlgorithms, cfg.algorithm, 0)
        czLevelBox.value = cfg.level !== undefined ? cfg.level : 3

        // Encrypt's algorithm is a fixed "AES-256-GCM" label, not a control.
        enKeyField.text = cfg.key_ref || ""

        const cmd = cfg.command || {}
        ptzModeCombo.currentIndex = comboIndexOr(ptzModes, cmd.mode, 0)
        ptzPresetBox.value = cmd.preset_id !== undefined ? cmd.preset_id : 1
        ptzPanField.text = cmd.pan !== undefined ? String(cmd.pan) : ""
        ptzTiltField.text = cmd.tilt !== undefined ? String(cmd.tilt) : ""
        ptzZoomField.text = cmd.zoom !== undefined ? String(cmd.zoom) : ""
    }

    Component.onCompleted: CameraModel.refresh()

    function commitActionType(val) {
        if (!nodeData.id) return
        PipelineGraphModel.updateNodeConfig(nodeData.id, { action_type: val })
        if (val !== "") {
            const m = actionTypeOptions
            for (let i = 0; i < m.length; i++) {
                if (m[i].value === val) {
                    PipelineGraphModel.updateNodeLabel(nodeData.id, m[i].text)
                    labelField.text = m[i].text
                    break
                }
            }
            // Some action configs have required fields with no valid
            // "unset" state on the backend (e.g. compress/encrypt's
            // algorithm), so commit the type's current defaults right away
            // rather than leaving them out until some other field is
            // touched.
            panelRoot.commitConfig()
        }
    }

    function commitConfig() {
        if (!nodeData.id || currentActionType === "") return
        let cfg = { action_type: currentActionType }

        if (currentActionType === "delay") {
            cfg.duration_secs = delayDurationBox.value
        } else if (currentActionType === "render_notification") {
            cfg.template = rnTemplateArea.text
            cfg.format = renderNotificationFormats[rnFormatCombo.currentIndex]
        } else if (currentActionType === "extract_clip") {
            cfg.pre_event_secs = ecPreBox.value
            cfg.post_event_secs = ecPostBox.value
            cfg.format = ecFormatField.text.trim() || "mp4"
            if (ecCameraField.cameraId) cfg.camera_id = ecCameraField.cameraId
            cfg.use_manual_range = ecManualToggle.checked
        } else if (currentActionType === "snapshot") {
            cfg.format = snapshotFormats[snapFormatCombo.currentIndex]
            cfg.quality = snapQualitySlider.value
            if (snapCameraField.cameraId) cfg.camera_id = snapCameraField.cameraId
        } else if (currentActionType === "transcode") {
            cfg.codec = transcodeCodecs[tcCodecCombo.currentIndex]
            cfg.bitrate_kbps = tcBitrateBox.value
            const res = transcodeResolutions[tcResCombo.currentIndex]
            if (res) cfg.resolution = res
            cfg.preset = transcodePresets[tcPresetCombo.currentIndex]
            cfg.output_format = videoOutputFormats[tcFormatCombo.currentIndex]
        } else if (currentActionType === "watermark") {
            cfg.text_template = wmTemplateArea.text
            cfg.position = watermarkPositions[wmPosCombo.currentIndex]
            cfg.font_size = wmFontBox.value
            cfg.opacity = Math.round(wmOpacitySlider.value * 100) / 100
        } else if (currentActionType === "merge_clips") {
            cfg.order = mergeClipsOrders[mcOrderCombo.currentIndex]
            cfg.gap_fill = mergeClipsGapFills[mcGapCombo.currentIndex]
            cfg.output_format = videoOutputFormats[mcFormatCombo.currentIndex]
        } else if (currentActionType === "compress") {
            cfg.algorithm = compressAlgorithms[czAlgoCombo.currentIndex]
            cfg.level = czLevelBox.value
        } else if (currentActionType === "encrypt") {
            cfg.algorithm = "aes256_gcm"
            cfg.key_ref = enKeyField.text.trim()
        } else if (currentActionType === "start_recording") {
            if (srCameraCombo.cameraId) cfg.camera_id = srCameraCombo.cameraId
            cfg.duration_secs = srDurationBox.value
            cfg.quality = srQualityField.text.trim() || "high"
        } else if (currentActionType === "stop_recording") {
            if (stCameraCombo.cameraId) cfg.camera_id = stCameraCombo.cameraId
        } else if (currentActionType === "ptz_move") {
            if (ptzCameraCombo.cameraId) cfg.camera_id = ptzCameraCombo.cameraId
            const mode = ptzModes[ptzModeCombo.currentIndex]
            if (mode === "preset") {
                cfg.command = { mode: "preset", preset_id: ptzPresetBox.value }
            } else {
                cfg.command = {
                    mode: mode,
                    pan:  parseFloat(ptzPanField.text)  || 0.0,
                    tilt: parseFloat(ptzTiltField.text) || 0.0,
                    zoom: parseFloat(ptzZoomField.text) || 0.0,
                }
            }
        }

        PipelineGraphModel.updateNodeConfig(nodeData.id, cfg)
    }

    onNodeIdChanged: resetFromConfig()

    Column {
        id: headerSection
        anchors { top: parent.top; left: parent.left; right: parent.right }

        Item {
            width: parent.width; height: 44

            Text {
                text: qsTr("Label")
                font.pixelSize: Theme.fontXs
                color: Theme.textDisabled
                width: 48
                anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
            }

            TextField {
                id: labelField
                anchors {
                    left: parent.left; leftMargin: 56
                    right: parent.right; rightMargin: Theme.spaceM
                    verticalCenter: parent.verticalCenter
                }
                height: 28
                font.pixelSize: Theme.fontS
                color: Theme.textPrimary
                leftPadding: Theme.spaceS
                rightPadding: Theme.spaceS

                background: Rectangle {
                    color: "transparent"
                    radius: Theme.radiusS
                    border.color: labelField.activeFocus ? Theme.accent : Theme.border
                    border.width: labelField.activeFocus ? 2 : 1
                }

                onEditingFinished: {
                    const t = text.trim()
                    if (t !== "" && nodeData.id)
                        PipelineGraphModel.updateNodeLabel(nodeData.id, t)
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Item {
            width: parent.width; height: 80

            Column {
                anchors {
                    left: parent.left; leftMargin: Theme.spaceM
                    right: parent.right; rightMargin: Theme.spaceM
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.spaceS

                Row {
                    spacing: Theme.spaceS
                    Text {
                        text: qsTr("Node type")
                        font.pixelSize: Theme.fontXs; color: Theme.textDisabled
                        width: 72; anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: dagNodeType === "device_control" ? qsTr("Device control") : qsTr("Action")
                        font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spaceS
                    Text {
                        text: qsTr("Action type")
                        font.pixelSize: Theme.fontXs; color: Theme.textDisabled
                        width: 72; anchors.verticalCenter: parent.verticalCenter
                    }
                    ComboBox {
                        id: actionTypeCombo
                        width: parent.width - 72 - Theme.spaceS
                        height: 28
                        model: panelRoot.actionTypeOptions
                        textRole: "text"
                        font.pixelSize: Theme.fontXs
                        onActivated: panelRoot.commitActionType(panelRoot.actionTypeOptions[currentIndex].value)
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }
    }

    ScrollView {
        id: formScroll
        anchors { top: headerSection.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentWidth: width
        clip: true

        Column {
            id: formBody
            width: formScroll.width
            spacing: 0
            topPadding: Theme.spaceS
            bottomPadding: Theme.spaceM

            component FormSpin: Item {
                property alias label: lbl.text
                property alias value: sb.value
                property alias from: sb.from
                property alias to: sb.to

                width: parent.width
                height: 32

                Text {
                    id: lbl
                    font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                    width: 108
                    anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                }
                SpinBox {
                    id: sb
                    anchors { left: parent.left; leftMargin: 116; right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                    height: 26
                    font.pixelSize: Theme.fontXs
                    onValueModified: panelRoot.commitConfig()
                }
            }

            component FormCombo: Item {
                property alias label: lbl.text
                property alias model: cb.model
                property alias currentIndex: cb.currentIndex

                width: parent.width
                height: 32

                Text {
                    id: lbl
                    font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                    width: 108
                    anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                }
                ComboBox {
                    id: cb
                    anchors { left: parent.left; leftMargin: 116; right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                    height: 26
                    font.pixelSize: Theme.fontXs
                    onActivated: panelRoot.commitConfig()
                }
            }

            component FormField: Item {
                property alias label: lbl.text
                property alias text: tf.text
                property alias placeholderText: tf.placeholderText

                width: parent.width
                height: 32

                Text {
                    id: lbl
                    font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                    width: 108
                    anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                }
                TextField {
                    id: tf
                    anchors { left: parent.left; leftMargin: 116; right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                    height: 26
                    font.pixelSize: Theme.fontXs
                    color: Theme.textPrimary
                    leftPadding: Theme.spaceS; rightPadding: Theme.spaceS
                    background: Rectangle {
                        color: "transparent"; radius: Theme.radiusS
                        border.color: tf.activeFocus ? Theme.accent : Theme.border
                        border.width: tf.activeFocus ? 2 : 1
                    }
                    onEditingFinished: panelRoot.commitConfig()
                }
            }

            component FormToggle: Item {
                property alias label: lbl.text
                property alias checked: ts.checked

                width: parent.width
                height: 32

                Text {
                    id: lbl
                    font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                    width: 108
                    anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                }
                ToggleSwitch {
                    id: ts
                    anchors { left: parent.left; leftMargin: 116; verticalCenter: parent.verticalCenter }
                    onCheckedChanged: panelRoot.commitConfig()
                }
            }

            // Type-to-filter + click-to-select camera picker (CameraModel has
            // no built-in autocomplete widget, so this filters a plain
            // TextField's input against CameraModel.searchableEntries()).
            component FormCameraCombo: Item {
                property alias label: lbl.text
                property string cameraId: ""

                signal committed()

                width: parent.width
                height: 32

                // Depends on CameraModel.count purely to establish a binding:
                // refresh()/createCamera()/deleteCamera() only bump count, not
                // a dedicated signal.
                readonly property var cameraOptions: {
                    const _trackCount = CameraModel.count
                    return CameraModel.searchableEntries()
                }

                readonly property var filteredOptions: {
                    const q = searchField.text.trim().toLowerCase()
                    if (q === "" || !searchField.activeFocus) return cameraOptions
                    return cameraOptions.filter((c) =>
                        c.name.toLowerCase().includes(q)
                        || (c.subtitle && c.subtitle.toLowerCase().includes(q)))
                }

                function nameFor(id) {
                    if (id === "") return ""
                    for (const c of cameraOptions) {
                        if (c.id === id) return c.name
                    }
                    return id
                }

                // Re-sync the displayed name once the real camera list arrives
                // (CameraModel.refresh() resolves after this panel may have
                // already opened) or when a different node is selected.
                onCameraOptionsChanged: if (!searchField.activeFocus) searchField.text = nameFor(cameraId)
                onCameraIdChanged: if (!searchField.activeFocus) searchField.text = nameFor(cameraId)

                Text {
                    id: lbl
                    font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                    width: 108
                    anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                }

                TextField {
                    id: searchField
                    anchors { left: parent.left; leftMargin: 116; right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                    height: 26
                    font.pixelSize: Theme.fontXs
                    color: Theme.textPrimary
                    placeholderText: qsTr("Search cameras… (optional)")
                    leftPadding: Theme.spaceS; rightPadding: Theme.spaceS
                    background: Rectangle {
                        color: "transparent"; radius: Theme.radiusS
                        border.color: searchField.activeFocus ? Theme.accent : Theme.border
                        border.width: searchField.activeFocus ? 2 : 1
                    }
                    onActiveFocusChanged: {
                        if (activeFocus) {
                            text = ""
                            resultsPopup.open()
                        } else {
                            resultsPopup.close()
                            text = nameFor(cameraId)
                        }
                    }
                    onTextEdited: resultsPopup.open()
                    Keys.onEscapePressed: focus = false
                }

                Popup {
                    id: resultsPopup
                    y: parent.height
                    x: 116
                    width: parent.width - 116 - Theme.spaceM
                    implicitHeight: Math.min(160, Math.max(1, resultsList.count) * 28)
                    padding: 0

                    contentItem: ListView {
                        id: resultsList
                        model: filteredOptions
                        clip: true
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width; height: 28
                            color: hoverArea.containsMouse ? Theme.surfaceHover : "transparent"
                            Text {
                                anchors { left: parent.left; leftMargin: Theme.spaceS; right: parent.right; rightMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }
                                text: modelData.subtitle ? (modelData.name + "  ·  " + modelData.subtitle) : modelData.name
                                font.pixelSize: Theme.fontXs; color: Theme.textPrimary
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                id: hoverArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    cameraId = modelData.id
                                    searchField.text = modelData.name
                                    resultsPopup.close()
                                    committed()
                                }
                            }
                        }
                    }
                }

                Component.onCompleted: searchField.text = nameFor(cameraId)
            }

            component FormSlider: Item {
                property alias label: lbl.text
                property alias value: sl.value
                property alias from: sl.from
                property alias to: sl.to
                property alias stepSize: sl.stepSize

                width: parent.width
                height: 32

                Text {
                    id: lbl
                    font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                    width: 108
                    anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                }
                Row {
                    anchors { left: parent.left; leftMargin: 116; right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                    spacing: Theme.spaceS
                    Slider {
                        id: sl
                        width: parent.width - valText.width - Theme.spaceS
                        anchors.verticalCenter: parent.verticalCenter
                        onMoved: panelRoot.commitConfig()
                    }
                    Text {
                        id: valText
                        text: Math.round(sl.value * 100) / 100
                        font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                        width: 30
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            component FormTextArea: Item {
                property alias label: lbl.text
                property alias text: ta.text

                width: parent.width
                height: 80

                Text {
                    id: lbl
                    font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                    anchors { left: parent.left; leftMargin: Theme.spaceM; top: parent.top; topMargin: 8 }
                }
                ScrollView {
                    anchors { left: parent.left; leftMargin: Theme.spaceM; right: parent.right; rightMargin: Theme.spaceM; bottom: parent.bottom; bottomMargin: 4; top: parent.top; topMargin: 24 }
                    TextArea {
                        id: ta
                        font.pixelSize: Theme.fontXs; color: Theme.textPrimary
                        wrapMode: TextArea.Wrap
                        background: Rectangle {
                            color: "transparent"; radius: Theme.radiusS
                            border.color: ta.activeFocus ? Theme.accent : Theme.border
                            border.width: ta.activeFocus ? 2 : 1
                        }
                        onEditingFinished: panelRoot.commitConfig()
                    }
                }
            }

            Item {
                visible: panelRoot.currentActionType === ""
                width: parent.width; height: 48
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Select an action type above")
                    font.pixelSize: Theme.fontXs; color: Theme.textDisabled
                }
            }

            Column {
                visible: panelRoot.currentActionType === "delay"
                width: parent.width; spacing: 2

                FormSpin {
                    id: delayDurationBox
                    label: qsTr("Duration (s)")
                    from: 0; to: 86400
                }
            }

            Column {
                visible: panelRoot.currentActionType === "render_notification"
                width: parent.width; spacing: 2

                FormTextArea { id: rnTemplateArea; label: qsTr("Template") }
                FormCombo {
                    id: rnFormatCombo
                    label: qsTr("Format")
                    model: [qsTr("Text"), "HTML", qsTr("Markdown")]
                }
            }

            Column {
                visible: panelRoot.currentActionType === "extract_clip"
                width: parent.width; spacing: 2

                FormSpin { id: ecPreBox;  label: qsTr("Pre-event (s)");  from: 0; to: 3600 }
                FormSpin { id: ecPostBox; label: qsTr("Post-event (s)"); from: 0; to: 3600 }
                FormField { id: ecFormatField;  label: qsTr("Format");    placeholderText: "mp4" }
                FormCameraCombo {
                    id: ecCameraField
                    objectName: "nodeConfigExtractClipCameraCombo"
                    label: qsTr("Camera"); onCommitted: panelRoot.commitConfig()
                }
                FormToggle { id: ecManualToggle; label: qsTr("Manual range") }
            }

            Column {
                visible: panelRoot.currentActionType === "snapshot"
                width: parent.width; spacing: 2

                FormCombo {
                    id: snapFormatCombo
                    label: qsTr("Format")
                    model: ["JPEG", "PNG"]
                }
                FormSlider {
                    id: snapQualitySlider
                    label: qsTr("Quality")
                    from: 1; to: 100; stepSize: 1; value: 85
                }
                FormCameraCombo {
                    id: snapCameraField
                    objectName: "nodeConfigSnapshotCameraCombo"
                    label: qsTr("Camera"); onCommitted: panelRoot.commitConfig()
                }
            }

            Column {
                visible: panelRoot.currentActionType === "transcode"
                width: parent.width; spacing: 2

                FormCombo {
                    id: tcCodecCombo
                    label: qsTr("Codec")
                    model: ["H.264", "H.265", "VP9", "AV1"]
                }
                FormSpin { id: tcBitrateBox; label: qsTr("Bitrate (kbps)"); from: 100; to: 100000 }
                FormCombo {
                    id: tcResCombo
                    objectName: "nodeConfigTranscodeResolutionCombo"
                    label: qsTr("Resolution")
                    model: [qsTr("Auto (keep source)"), "3840×2160 (4K)", "2560×1440 (QHD)", "1920×1080 (Full HD)", "1280×720 (HD)", "854×480 (SD)"]
                }
                FormCombo {
                    id: tcPresetCombo
                    label: qsTr("Preset")
                    model: ["ultrafast", "fast", "medium", "slow"]
                    currentIndex: 1
                }
                FormCombo {
                    id: tcFormatCombo
                    label: qsTr("Output format")
                    model: ["mp4", "mkv"]
                }
            }

            Column {
                visible: panelRoot.currentActionType === "watermark"
                width: parent.width; spacing: 2

                FormTextArea { id: wmTemplateArea; label: qsTr("Text template") }
                FormCombo {
                    id: wmPosCombo
                    label: qsTr("Position")
                    model: [qsTr("Top left"), qsTr("Top right"), qsTr("Bottom left"), qsTr("Bottom right"), qsTr("Center")]
                    currentIndex: 2
                }
                FormSpin { id: wmFontBox; label: qsTr("Font size (pt)"); from: 8; to: 120; value: 24 }
                FormSlider {
                    id: wmOpacitySlider
                    label: qsTr("Opacity")
                    from: 0; to: 1; stepSize: 0.05; value: 0.8
                }
            }

            Column {
                visible: panelRoot.currentActionType === "merge_clips"
                width: parent.width; spacing: 2

                FormCombo {
                    id: mcOrderCombo
                    label: qsTr("Order")
                    model: [qsTr("Chronological"), qsTr("Reverse chronological")]
                }
                FormCombo {
                    id: mcGapCombo
                    label: qsTr("Gap fill")
                    model: [qsTr("Black frame"), qsTr("Freeze"), qsTr("Skip")]
                }
                FormCombo {
                    id: mcFormatCombo
                    label: qsTr("Output format")
                    model: ["mp4", "mkv"]
                }
            }

            Column {
                visible: panelRoot.currentActionType === "compress"
                width: parent.width; spacing: 2

                FormCombo {
                    id: czAlgoCombo
                    objectName: "nodeConfigCompressAlgorithmCombo"
                    label: qsTr("Algorithm")
                    model: ["Zstd", "Gzip", "LZ4"]
                }
                FormSpin {
                    id: czLevelBox
                    objectName: "nodeConfigCompressLevelBox"
                    label: qsTr("Level"); from: 1; to: 22; value: 3
                }
            }

            Column {
                visible: panelRoot.currentActionType === "encrypt"
                width: parent.width; spacing: 2

                Item {
                    width: parent.width; height: 32
                    Text {
                        text: qsTr("Algorithm")
                        font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                        width: 108
                        anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        text: "AES-256-GCM"
                        font.pixelSize: Theme.fontXs; color: Theme.textPrimary
                        anchors { left: parent.left; leftMargin: 116; verticalCenter: parent.verticalCenter }
                    }
                }
                FormField { id: enKeyField; label: qsTr("Key ref"); placeholderText: qsTr("default") }
            }

            Item {
                visible: panelRoot.currentActionType === "skip"
                width: parent.width; height: 48
                Text {
                    anchors { left: parent.left; leftMargin: Theme.spaceM; right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                    text: qsTr("No configuration — this node does nothing and always succeeds.")
                    font.pixelSize: Theme.fontXs; color: Theme.textDisabled
                    wrapMode: Text.WordWrap
                }
            }

            Column {
                visible: panelRoot.currentActionType === "start_recording"
                width: parent.width; spacing: 2

                FormCameraCombo { id: srCameraCombo; label: qsTr("Camera"); onCommitted: panelRoot.commitConfig() }
                FormSpin  { id: srDurationBox;  label: qsTr("Duration (s)"); from: 0; to: 86400 }
                Text {
                    width: parent.width - 116 - Theme.spaceM
                    anchors.left: parent.left; anchors.leftMargin: 116
                    text: qsTr("0 = start recording and never stop automatically")
                    font.pixelSize: Theme.fontXs; color: Theme.textDisabled
                    wrapMode: Text.WordWrap
                }
                FormField { id: srQualityField; label: qsTr("Quality"); placeholderText: qsTr("high") }
            }

            Column {
                visible: panelRoot.currentActionType === "stop_recording"
                width: parent.width; spacing: 2

                FormCameraCombo { id: stCameraCombo; label: qsTr("Camera"); onCommitted: panelRoot.commitConfig() }
            }

            Column {
                visible: panelRoot.currentActionType === "ptz_move"
                width: parent.width; spacing: 2

                FormCameraCombo { id: ptzCameraCombo; label: qsTr("Camera"); onCommitted: panelRoot.commitConfig() }
                FormCombo {
                    id: ptzModeCombo
                    label: qsTr("Mode")
                    model: [qsTr("Preset"), qsTr("Absolute"), qsTr("Relative")]
                }
                FormSpin {
                    id: ptzPresetBox
                    label: qsTr("Preset ID")
                    from: 1; to: 255
                    visible: ptzModeCombo.currentIndex === 0
                }
                FormField {
                    id: ptzPanField
                    label: qsTr("Pan")
                    placeholderText: "0.0"
                    visible: ptzModeCombo.currentIndex !== 0
                }
                FormField {
                    id: ptzTiltField
                    label: qsTr("Tilt")
                    placeholderText: "0.0"
                    visible: ptzModeCombo.currentIndex !== 0
                }
                FormField {
                    id: ptzZoomField
                    label: qsTr("Zoom")
                    placeholderText: "0.0"
                    visible: ptzModeCombo.currentIndex !== 0
                }
            }
        }
    }
}
