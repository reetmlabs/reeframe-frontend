// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: panelRoot

    property var nodeData: ({})

    readonly property string nodeId: nodeData.id !== undefined ? nodeData.id : ""

    color: Theme.surface

    Rectangle {
        anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
        width: 1
        color: Theme.border
    }

    function resetFromConfig() {
        if (nodeId === "") return
        const cfg = nodeData.config || {}
        labelField.text = nodeData.label || ""
        exprArea.text = cfg.condition_expr || ""
    }

    function commitConfig() {
        if (!nodeData.id) return
        PipelineGraphModel.updateNodeConfig(nodeData.id, { condition_expr: exprArea.text.trim() })
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
            width: parent.width; height: 32

            Row {
                anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
                spacing: Theme.spaceS
                Text {
                    text: qsTr("Node type")
                    font.pixelSize: Theme.fontXs; color: Theme.textDisabled
                    width: 72; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: qsTr("Condition")
                    font.pixelSize: Theme.fontXs; color: Theme.textSecondary
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }
    }

    Column {
        anchors { top: headerSection.bottom; left: parent.left; right: parent.right }
        topPadding: Theme.spaceS
        spacing: Theme.spaceXs

        Text {
            anchors { left: parent.left; leftMargin: Theme.spaceM; right: parent.right; rightMargin: Theme.spaceM }
            text: qsTr("Expression")
            font.pixelSize: Theme.fontXs; color: Theme.textSecondary
        }

        ScrollView {
            anchors { left: parent.left; leftMargin: Theme.spaceM; right: parent.right; rightMargin: Theme.spaceM }
            height: 100
            TextArea {
                id: exprArea
                font.pixelSize: Theme.fontXs; color: Theme.textPrimary
                wrapMode: TextArea.Wrap
                placeholderText: qsTr("score > 0.5")
                background: Rectangle {
                    color: "transparent"; radius: Theme.radiusS
                    border.color: exprArea.activeFocus ? Theme.accent : Theme.border
                    border.width: exprArea.activeFocus ? 2 : 1
                }
                onEditingFinished: panelRoot.commitConfig()
            }
        }

        Text {
            anchors { left: parent.left; leftMargin: Theme.spaceM; right: parent.right; rightMargin: Theme.spaceM }
            text: qsTr("Rust-like boolean expression, evaluated against the immediately preceding node's output fields, referenced directly by name (no prefix) — e.g. score > 0.5 or confidence > 0.85 && label == \"person\". If this node has more than one incoming edge, only the first parent's output is used.")
            font.pixelSize: Theme.fontXs; color: Theme.textDisabled
            wrapMode: Text.WordWrap
        }
    }
}
