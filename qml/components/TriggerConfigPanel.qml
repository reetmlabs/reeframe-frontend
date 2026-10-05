// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: panelRoot

    property var nodeData: ({})

    readonly property string nodeId: nodeData.id !== undefined ? nodeData.id : ""
    readonly property string currentTriggerType: {
        const cfg = nodeData.config
        return (cfg && cfg.trigger_type) ? cfg.trigger_type : ""
    }

    color: Theme.surface

    Rectangle {
        anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
        width: 1
        color: Theme.border
    }

    readonly property var triggerTypeOptions: [
        { value: "",         text: qsTr("Select type…") },
        { value: "schedule", text: qsTr("Schedule") },
        { value: "event",    text: qsTr("Event filter") },
        { value: "stat",     text: qsTr("Stat threshold") },
        { value: "manual",   text: qsTr("Manual") },
    ]

    function findTriggerTypeIndex(val) {
        const m = triggerTypeOptions
        for (let i = 0; i < m.length; i++) {
            if (m[i].value === val) return i
        }
        return 0
    }

    // Depends on SourceModel.count purely to establish a binding: refresh()/
    // createSource()/deleteSource() only bump count, not a dedicated signal.
    readonly property var sourceOptions: {
        const _trackCount = SourceModel.count
        const out = [{ value: "", text: qsTr("Any source") }]
        for (const s of SourceModel.searchableEntries())
            out.push({ value: s.id, text: s.subtitle ? (s.name + " (" + s.subtitle + ")") : s.name })
        return out
    }

    function findSourceIndex(val) {
        const m = sourceOptions
        for (let i = 0; i < m.length; i++) {
            if (m[i].value === val) return i
        }
        return 0
    }

    function resetFromConfig() {
        if (nodeId === "") return
        const cfg = nodeData.config || {}
        labelField.text = nodeData.label || ""
        triggerTypeCombo.currentIndex = findTriggerTypeIndex(cfg.trigger_type || "")
        eventSourceCombo.currentIndex = findSourceIndex(cfg.source_id || "")
        eventFilterArea.text = cfg.filter || ""
        scheduleCronField.text = cfg.cron || ""
        scheduleTzField.text = cfg.timezone || ""
        statMetricCombo.currentIndex = Math.max(0, ["disk", "ram", "cpu"].indexOf(cfg.metric || "disk"))
        statThresholdBox.value = cfg.threshold_pct !== undefined ? cfg.threshold_pct : 90
        statCooldownBox.value = cfg.cooldown_secs !== undefined ? cfg.cooldown_secs : 300
    }

    // SourceModel.refresh() resolves after this panel may have already opened,
    // so re-sync the selection once the real list of sources arrives.
    onSourceOptionsChanged: {
        if (nodeId !== "")
            eventSourceCombo.currentIndex = findSourceIndex((nodeData.config && nodeData.config.source_id) || "")
    }

    Component.onCompleted: SourceModel.refresh()

    function commitTriggerType(val) {
        if (!nodeData.id) return
        PipelineGraphModel.updateNodeConfig(nodeData.id, { trigger_type: val })
        if (val !== "") {
            const m = triggerTypeOptions
            for (let i = 0; i < m.length; i++) {
                if (m[i].value === val) {
                    PipelineGraphModel.updateNodeLabel(nodeData.id, m[i].text)
                    labelField.text = m[i].text
                    break
                }
            }
        }
    }

    function commitConfig() {
        if (!nodeData.id || currentTriggerType === "") return
        let cfg = { trigger_type: currentTriggerType }

        if (currentTriggerType === "schedule") {
            cfg.cron = scheduleCronField.text.trim()
            const tz = scheduleTzField.text.trim()
            if (tz) cfg.timezone = tz
        } else if (currentTriggerType === "event") {
            const src = panelRoot.sourceOptions[eventSourceCombo.currentIndex].value
            if (src) cfg.source_id = src
            cfg.filter = eventFilterArea.text
        } else if (currentTriggerType === "stat") {
            cfg.metric = ["disk", "ram", "cpu"][statMetricCombo.currentIndex]
            cfg.threshold_pct = statThresholdBox.value
            cfg.cooldown_secs = statCooldownBox.value
        }

        PipelineGraphModel.updateNodeConfig(nodeData.id, cfg)
    }

    // A trigger_root node's config loads from a separate, slower request than
    // its base node data (see PipelineGraphModel::load()'s /triggers fetch),
    // so it can still be empty when this node is first selected, so resync
    // whenever the config content changes too, not just on node switch.
    readonly property string configSignature: nodeId + "::" + JSON.stringify(nodeData.config || {})

    onConfigSignatureChanged: resetFromConfig()

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
                        text: qsTr("Trigger")
                        font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spaceS
                    Text {
                        text: qsTr("Trigger type")
                        font.pixelSize: Theme.fontXs; color: Theme.textDisabled
                        width: 72; anchors.verticalCenter: parent.verticalCenter
                    }
                    ComboBox {
                        id: triggerTypeCombo
                        width: parent.width - 72 - Theme.spaceS
                        height: 28
                        model: panelRoot.triggerTypeOptions
                        textRole: "text"
                        font.pixelSize: Theme.fontXs
                        onActivated: panelRoot.commitTriggerType(panelRoot.triggerTypeOptions[currentIndex].value)
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
                property alias textRole: cb.textRole
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
                visible: panelRoot.currentTriggerType === ""
                width: parent.width; height: 48
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Select a trigger type above")
                    font.pixelSize: Theme.fontXs; color: Theme.textDisabled
                }
            }

            Column {
                visible: panelRoot.currentTriggerType === "schedule"
                width: parent.width; spacing: 2

                FormField { id: scheduleCronField; label: qsTr("Cron"); placeholderText: "0 * * * *" }
                FormField { id: scheduleTzField;   label: qsTr("Timezone"); placeholderText: qsTr("optional, e.g. Europe/Berlin") }
            }

            Column {
                visible: panelRoot.currentTriggerType === "event"
                width: parent.width; spacing: 2

                FormCombo    { id: eventSourceCombo; label: qsTr("Source"); model: panelRoot.sourceOptions; textRole: "text" }
                FormTextArea { id: eventFilterArea;  label: qsTr("Filter") }
            }

            Column {
                visible: panelRoot.currentTriggerType === "stat"
                width: parent.width; spacing: 2

                FormCombo { id: statMetricCombo;   label: qsTr("Metric");         model: [qsTr("Disk"), "RAM", "CPU"] }
                FormSpin  { id: statThresholdBox;  label: qsTr("Threshold (%)");  from: 1; to: 100; value: 90 }
                FormSpin  { id: statCooldownBox;   label: qsTr("Cooldown (s)");   from: 0; to: 86400; value: 300 }
            }

            Item {
                visible: panelRoot.currentTriggerType === "manual"
                width: parent.width; height: 48
                Text {
                    anchors { left: parent.left; leftMargin: Theme.spaceM; right: parent.right; rightMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                    text: qsTr("No configuration — pipeline is triggered via the API or UI.")
                    font.pixelSize: Theme.fontXs; color: Theme.textDisabled
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
