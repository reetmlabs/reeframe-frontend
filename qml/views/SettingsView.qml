// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtQuick.Controls.Basic

Item {
    id: root

    property int currentTab: 0

    property string d_slotTl: ""
    property string d_slotTc: ""
    property string d_slotTr: ""
    property string d_slotBl: ""
    property string d_slotBc: ""
    property string d_slotBr: ""
    property string d_customTl: ""
    property string d_customTc: ""
    property string d_customTr: ""
    property string d_customBl: ""
    property string d_customBc: ""
    property string d_customBr: ""
    property int d_fontSize: 10
    property string d_textColor: "#ffffff"
    property real d_bgOpacity: 0.55
    property bool d_headerShowClose: true
    property bool d_headerShowExpand: true

    readonly property var slotOptions: [
        { value: "none", label: qsTr("None") },
        { value: "timestamp", label: qsTr("Timestamp") },
        { value: "location", label: qsTr("Location") },
        { value: "custom", label: qsTr("Custom text") }
    ]

    readonly property var fontOptions: [
        { value: 10, label: qsTr("Small (10)") },
        { value: 12, label: qsTr("Medium (12)") },
        { value: 14, label: qsTr("Large (14)") }
    ]

    readonly property var colorPresets: ["#ffffff", "#cccccc", "#ffee55", "#44ddff"]

    function resetDraft() {
        d_slotTl = OverlayPrefs.slotTl
        d_slotTc = OverlayPrefs.slotTc
        d_slotTr = OverlayPrefs.slotTr
        d_slotBl = OverlayPrefs.slotBl
        d_slotBc = OverlayPrefs.slotBc
        d_slotBr = OverlayPrefs.slotBr
        d_customTl = OverlayPrefs.customTl
        d_customTc = OverlayPrefs.customTc
        d_customTr = OverlayPrefs.customTr
        d_customBl = OverlayPrefs.customBl
        d_customBc = OverlayPrefs.customBc
        d_customBr = OverlayPrefs.customBr
        d_fontSize = OverlayPrefs.fontSize
        d_textColor = OverlayPrefs.textColor
        d_bgOpacity = OverlayPrefs.bgOpacity
        d_headerShowClose = OverlayPrefs.headerShowClose
        d_headerShowExpand = OverlayPrefs.headerShowExpand
        showCloseToggle.checked = OverlayPrefs.headerShowClose
        showExpandToggle.checked = OverlayPrefs.headerShowExpand
        opacitySlider.value = OverlayPrefs.bgOpacity
        colorHexField.text = OverlayPrefs.textColor
        customTlField.text = OverlayPrefs.customTl
        customTcField.text = OverlayPrefs.customTc
        customTrField.text = OverlayPrefs.customTr
        customBlField.text = OverlayPrefs.customBl
        customBcField.text = OverlayPrefs.customBc
        customBrField.text = OverlayPrefs.customBr
    }

    function applyDraft() {
        OverlayPrefs.slotTl = d_slotTl
        OverlayPrefs.slotTc = d_slotTc
        OverlayPrefs.slotTr = d_slotTr
        OverlayPrefs.slotBl = d_slotBl
        OverlayPrefs.slotBc = d_slotBc
        OverlayPrefs.slotBr = d_slotBr
        OverlayPrefs.customTl = d_customTl
        OverlayPrefs.customTc = d_customTc
        OverlayPrefs.customTr = d_customTr
        OverlayPrefs.customBl = d_customBl
        OverlayPrefs.customBc = d_customBc
        OverlayPrefs.customBr = d_customBr
        OverlayPrefs.fontSize = d_fontSize
        OverlayPrefs.textColor = d_textColor
        OverlayPrefs.bgOpacity = d_bgOpacity
        OverlayPrefs.headerShowClose = d_headerShowClose
        OverlayPrefs.headerShowExpand = d_headerShowExpand
    }

    Component.onCompleted: resetDraft()

    component SettingCombo: ComboBox {
        id: combo

        property string boundValue: ""
        property var options: []

        signal valueSelected(string value)

        width: 160
        height: 32
        model: options
        textRole: "label"
        valueRole: "value"

        onBoundValueChanged: {
            currentIndex = options.findIndex(function (o) {
                return o.value == boundValue
            })
        }
        Component.onCompleted: {
            currentIndex = options.findIndex(function (o) {
                return o.value == boundValue
            })
        }
        onActivated: combo.valueSelected(currentValue)

        background: Rectangle {
            color: combo.pressed ? Theme.surfaceHover : Theme.surface
            border.color: Theme.border
            radius: Theme.radiusS
        }
        contentItem: Text {
            leftPadding: Theme.spaceM
            text: combo.displayText
            font.pixelSize: Theme.fontS
            color: Theme.textPrimary
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        indicator: Text {
            x: combo.width - width - Theme.spaceS
            text: "▾"
            font.pixelSize: Theme.fontXs
            color: Theme.textSecondary
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    ScrollView {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: footer.top
        }
        contentWidth: availableWidth

        Column {
            id: contentCol

            width: Math.min(560, root.width - Theme.spaceXl * 2)
            x: (root.width - width) / 2
            topPadding: Theme.spaceXl
            bottomPadding: Theme.spaceXl
            spacing: 0

            Text {
                text: qsTr("Settings")
                font.pixelSize: Theme.fontXl
                font.weight: Font.Medium
                color: Theme.textPrimary
            }

            Item {
                width: 1
                height: Theme.spaceL
            }

            Row {
                spacing: 0

                Repeater {
                    model: [qsTr("Header"), qsTr("Overlay"), qsTr("About")]

                    delegate: Item {
                        required property string modelData
                        required property int index

                        width: 100
                        height: 36

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2
                            color: root.currentTab === index ? Theme.accent : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: Theme.fontS
                            font.weight: root.currentTab === index ? Font.Medium : Font.Normal
                            color: root.currentTab === index ? Theme.textPrimary : Theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = index
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Item {
                width: 1
                height: Theme.spaceL
            }

            /* ═══════════ Header tab ═══════════ */
            Column {
                width: parent.width
                spacing: Theme.spaceM
                visible: root.currentTab === 0

                Row {
                    width: parent.width
                    spacing: Theme.spaceM

                    Text {
                        width: 200
                        text: qsTr("Show close button")
                        font.pixelSize: Theme.fontS
                        color: Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    ToggleSwitch {
                        id: showCloseToggle

                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.d_headerShowClose
                        onToggled: (v) => root.d_headerShowClose = v
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spaceM

                    Text {
                        width: 200
                        text: qsTr("Show expand button")
                        font.pixelSize: Theme.fontS
                        color: Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    ToggleSwitch {
                        id: showExpandToggle

                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.d_headerShowExpand
                        onToggled: (v) => root.d_headerShowExpand = v
                    }
                }
            }

            /* ═══════════ Overlay tab ═══════════ */
            Column {
                width: parent.width
                spacing: Theme.spaceM
                visible: root.currentTab === 1

                Text {
                    text: qsTr("Top row")
                    font.pixelSize: Theme.fontXs
                    color: Theme.textSecondary
                    font.weight: Font.Medium
                }

                Column {
                    width: parent.width
                    spacing: Theme.spaceS

                    Row {
                        width: parent.width
                        spacing: Theme.spaceM

                        Text {
                            width: 80
                            text: qsTr("Left")
                            font.pixelSize: Theme.fontS
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        SettingCombo {
                            boundValue: root.d_slotTl
                            options: root.slotOptions
                            onValueSelected: (v) => root.d_slotTl = v
                        }
                    }

                    TextField {
                        id: customTlField

                        width: parent.width
                        height: 32
                        visible: root.d_slotTl === "custom"
                        placeholderText: qsTr("Custom text — top left")
                        color: Theme.textPrimary
                        placeholderTextColor: Theme.textDisabled
                        font.pixelSize: Theme.fontS
                        leftPadding: Theme.spaceM
                        selectionColor: Theme.accent
                        onEditingFinished: root.d_customTl = text

                        background: Rectangle {
                            color: Theme.surface
                            border.color: customTlField.activeFocus ? Theme.accent : Theme.border
                            radius: Theme.radiusS

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.durationFast
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spaceS

                    Row {
                        width: parent.width
                        spacing: Theme.spaceM

                        Text {
                            width: 80
                            text: qsTr("Centre")
                            font.pixelSize: Theme.fontS
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        SettingCombo {
                            boundValue: root.d_slotTc
                            options: root.slotOptions
                            onValueSelected: (v) => root.d_slotTc = v
                        }
                    }

                    TextField {
                        id: customTcField

                        width: parent.width
                        height: 32
                        visible: root.d_slotTc === "custom"
                        placeholderText: qsTr("Custom text — top centre")
                        color: Theme.textPrimary
                        placeholderTextColor: Theme.textDisabled
                        font.pixelSize: Theme.fontS
                        leftPadding: Theme.spaceM
                        selectionColor: Theme.accent
                        onEditingFinished: root.d_customTc = text

                        background: Rectangle {
                            color: Theme.surface
                            border.color: customTcField.activeFocus ? Theme.accent : Theme.border
                            radius: Theme.radiusS

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.durationFast
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spaceS

                    Row {
                        width: parent.width
                        spacing: Theme.spaceM

                        Text {
                            width: 80
                            text: qsTr("Right")
                            font.pixelSize: Theme.fontS
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        SettingCombo {
                            boundValue: root.d_slotTr
                            options: root.slotOptions
                            onValueSelected: (v) => root.d_slotTr = v
                        }
                    }

                    TextField {
                        id: customTrField

                        width: parent.width
                        height: 32
                        visible: root.d_slotTr === "custom"
                        placeholderText: qsTr("Custom text — top right")
                        color: Theme.textPrimary
                        placeholderTextColor: Theme.textDisabled
                        font.pixelSize: Theme.fontS
                        leftPadding: Theme.spaceM
                        selectionColor: Theme.accent
                        onEditingFinished: root.d_customTr = text

                        background: Rectangle {
                            color: Theme.surface
                            border.color: customTrField.activeFocus ? Theme.accent : Theme.border
                            radius: Theme.radiusS

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.durationFast
                                }
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: Theme.spaceS
                }

                Text {
                    text: qsTr("Bottom row")
                    font.pixelSize: Theme.fontXs
                    color: Theme.textSecondary
                    font.weight: Font.Medium
                }

                Column {
                    width: parent.width
                    spacing: Theme.spaceS

                    Row {
                        width: parent.width
                        spacing: Theme.spaceM

                        Text {
                            width: 80
                            text: qsTr("Left")
                            font.pixelSize: Theme.fontS
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        SettingCombo {
                            boundValue: root.d_slotBl
                            options: root.slotOptions
                            onValueSelected: (v) => root.d_slotBl = v
                        }
                    }

                    TextField {
                        id: customBlField

                        width: parent.width
                        height: 32
                        visible: root.d_slotBl === "custom"
                        placeholderText: qsTr("Custom text — bottom left")
                        color: Theme.textPrimary
                        placeholderTextColor: Theme.textDisabled
                        font.pixelSize: Theme.fontS
                        leftPadding: Theme.spaceM
                        selectionColor: Theme.accent
                        onEditingFinished: root.d_customBl = text

                        background: Rectangle {
                            color: Theme.surface
                            border.color: customBlField.activeFocus ? Theme.accent : Theme.border
                            radius: Theme.radiusS

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.durationFast
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spaceS

                    Row {
                        width: parent.width
                        spacing: Theme.spaceM

                        Text {
                            width: 80
                            text: qsTr("Centre")
                            font.pixelSize: Theme.fontS
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        SettingCombo {
                            boundValue: root.d_slotBc
                            options: root.slotOptions
                            onValueSelected: (v) => root.d_slotBc = v
                        }
                    }

                    TextField {
                        id: customBcField

                        width: parent.width
                        height: 32
                        visible: root.d_slotBc === "custom"
                        placeholderText: qsTr("Custom text — bottom centre")
                        color: Theme.textPrimary
                        placeholderTextColor: Theme.textDisabled
                        font.pixelSize: Theme.fontS
                        leftPadding: Theme.spaceM
                        selectionColor: Theme.accent
                        onEditingFinished: root.d_customBc = text

                        background: Rectangle {
                            color: Theme.surface
                            border.color: customBcField.activeFocus ? Theme.accent : Theme.border
                            radius: Theme.radiusS

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.durationFast
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spaceS

                    Row {
                        width: parent.width
                        spacing: Theme.spaceM

                        Text {
                            width: 80
                            text: qsTr("Right")
                            font.pixelSize: Theme.fontS
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        SettingCombo {
                            boundValue: root.d_slotBr
                            options: root.slotOptions
                            onValueSelected: (v) => root.d_slotBr = v
                        }
                    }

                    TextField {
                        id: customBrField

                        width: parent.width
                        height: 32
                        visible: root.d_slotBr === "custom"
                        placeholderText: qsTr("Custom text — bottom right")
                        color: Theme.textPrimary
                        placeholderTextColor: Theme.textDisabled
                        font.pixelSize: Theme.fontS
                        leftPadding: Theme.spaceM
                        selectionColor: Theme.accent
                        onEditingFinished: root.d_customBr = text

                        background: Rectangle {
                            color: Theme.surface
                            border.color: customBrField.activeFocus ? Theme.accent : Theme.border
                            radius: Theme.radiusS

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.durationFast
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.border
                }

                /* ----- Font size ----- */
                Row {
                    width: parent.width
                    spacing: Theme.spaceM

                    Text {
                        width: 120
                        text: qsTr("Font size")
                        font.pixelSize: Theme.fontS
                        color: Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    SettingCombo {
                        boundValue: root.d_fontSize
                        options: root.fontOptions
                        onValueSelected: (v) => root.d_fontSize = parseInt(v)
                    }
                }

                /* ----- Text colour ----- */
                Column {
                    width: parent.width
                    spacing: Theme.spaceS

                    Text {
                        text: qsTr("Text colour")
                        font.pixelSize: Theme.fontXs
                        color: Theme.textSecondary
                    }

                    Row {
                        spacing: Theme.spaceS

                        Repeater {
                            model: root.colorPresets

                            delegate: Rectangle {
                                required property string modelData

                                width: 28
                                height: 28
                                radius: Theme.radiusS
                                color: modelData
                                border.color: root.d_textColor === modelData ? Theme.accent : Theme.border
                                border.width: root.d_textColor === modelData ? 2 : 1

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.d_textColor = modelData
                                        colorHexField.text = modelData
                                    }
                                }

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Theme.durationFast
                                    }
                                }
                            }
                        }

                        TextField {
                            id: colorHexField

                            width: 90
                            height: 28
                            text: root.d_textColor
                            color: Theme.textPrimary
                            placeholderTextColor: Theme.textDisabled
                            font.pixelSize: Theme.fontXs
                            font.family: "monospace"
                            leftPadding: Theme.spaceS
                            selectionColor: Theme.accent
                            onEditingFinished: {
                                if (/^#[0-9a-fA-F]{6}$/.test(text))
                                    root.d_textColor = text
                                else
                                    text = root.d_textColor
                            }

                            background: Rectangle {
                                color: Theme.surface
                                border.color: colorHexField.activeFocus ? Theme.accent : Theme.border
                                radius: Theme.radiusS

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Theme.durationFast
                                    }
                                }
                            }
                        }
                    }
                }

                /* ----- Background opacity ----- */
                Column {
                    width: parent.width
                    spacing: Theme.spaceS

                    Row {
                        spacing: Theme.spaceM

                        Text {
                            text: qsTr("Background opacity")
                            font.pixelSize: Theme.fontXs
                            color: Theme.textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: Math.round(opacitySlider.value * 100) + " %"
                            font.pixelSize: Theme.fontXs
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Slider {
                        id: opacitySlider

                        width: parent.width
                        from: 0
                        to: 1
                        stepSize: 0.05
                        value: root.d_bgOpacity
                        onMoved: root.d_bgOpacity = value

                        background: Rectangle {
                            x: opacitySlider.leftPadding
                            y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                            width: opacitySlider.availableWidth
                            height: 4
                            radius: 2
                            color: Theme.border

                            Rectangle {
                                width: opacitySlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: Theme.accent
                            }
                        }

                        handle: Rectangle {
                            x: opacitySlider.leftPadding + opacitySlider.visualPosition * (opacitySlider.availableWidth - width)
                            y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                            width: 16
                            height: 16
                            radius: 8
                            color: opacitySlider.pressed ? Qt.darker(Theme.accent, 1.1) : "white"
                            border.color: Theme.accent
                            border.width: 2
                        }
                    }
                }
            }

            /* ═══════════ About tab ═══════════ */
            Column {
                width: parent.width
                spacing: Theme.spaceM
                visible: root.currentTab === 2

                Row {
                    width: parent.width
                    spacing: Theme.spaceM

                    Text {
                        width: 200
                        text: qsTr("Version")
                        font.pixelSize: Theme.fontS
                        color: Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        objectName: "aboutVersionText"
                        text: Qt.application.version
                        font.pixelSize: Theme.fontS
                        color: Theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.border }

                Text {
                    text: qsTr("Connected sites")
                    font.pixelSize: Theme.fontXs
                    color: Theme.textSecondary
                    font.weight: Font.Medium
                }

                Text {
                    objectName: "aboutNoSitesText"
                    visible: SiteManager.count === 0
                    text: qsTr("No sites connected")
                    font.pixelSize: Theme.fontS
                    color: Theme.textDisabled
                }

                Column {
                    width: parent.width
                    spacing: Theme.spaceS
                    visible: SiteManager.count > 0

                    Repeater {
                        model: SiteManager

                        delegate: Row {
                            required property string siteId
                            required property string siteName
                            required property string siteVersion

                            objectName: "aboutSiteRow_" + siteId
                            width: parent.width
                            spacing: Theme.spaceM

                            Text {
                                width: 200
                                text: siteName
                                font.pixelSize: Theme.fontS
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                objectName: "aboutSiteVersionText"
                                text: siteVersion.length > 0 ? siteVersion : qsTr("Not connected")
                                font.pixelSize: Theme.fontS
                                color: Theme.textSecondary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.border }

                Text {
                    text: qsTr("Open-source licences")
                    font.pixelSize: Theme.fontXs
                    color: Theme.textSecondary
                    font.weight: Font.Medium
                }

                Column {
                    width: parent.width
                    spacing: Theme.spaceS

                    Text {
                        objectName: "aboutQtLicenseText"
                        width: parent.width
                        text: qsTr("Qt 6 — GNU Lesser General Public License v3 (LGPLv3). This application links to Qt dynamically; the Qt libraries used by this application may be replaced with a compatible version. See qt.io/licensing for details.")
                        font.pixelSize: Theme.fontXs
                        color: Theme.textSecondary
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        objectName: "aboutTablerLicenseText"
                        width: parent.width
                        text: qsTr("Tabler Icons — MIT License. Copyright © Paweł Kuna and contributors.")
                        font.pixelSize: Theme.fontXs
                        color: Theme.textSecondary
                        wrapMode: Text.WordWrap
                    }
                }
            }

        }
    }

    /* ----- Fixed footer ----- */
    Rectangle {
        id: footer

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 56
        color: Theme.surface

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: 1
            color: Theme.border
        }

        Row {
            anchors {
                right: parent.right
                rightMargin: Theme.spaceXl
                verticalCenter: parent.verticalCenter
            }
            spacing: Theme.spaceS

            Rectangle {
                width: 80
                height: 32
                radius: Theme.radiusS
                color: cancelMouse.containsMouse ? Theme.surfaceHover : "transparent"
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Cancel")
                    font.pixelSize: Theme.fontS
                    color: Theme.textPrimary
                }

                MouseArea {
                    id: cancelMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetDraft()
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durationFast
                    }
                }
            }

            Rectangle {
                width: 80
                height: 32
                radius: Theme.radiusS
                color: applyMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Apply")
                    font.pixelSize: Theme.fontS
                    font.weight: Font.Medium
                    color: Theme.textOnAccent
                }

                MouseArea {
                    id: applyMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.applyDraft()
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durationFast
                    }
                }
            }
        }
    }
}
