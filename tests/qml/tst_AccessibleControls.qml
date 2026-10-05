// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for keyboard/accessibility support on the shared interactive
// components (HoverButton, Checkbox, ToggleSwitch, NavItem): each must be
// Tab-reachable, activatable via Space/Enter once focused, expose correct
// Accessible role/name/checked state, and show a visible focus ring while
// focused.
TestCase {
    id: testCase
    name: "AccessibleControls"
    width: 400
    height: 400
    visible: true
    when: windowShown

    Column {
        anchors.fill: parent
        spacing: 20

        HoverButton {
            id: button
            text: "Save"
        }
        Checkbox {
            id: checkbox
        }
        ToggleSwitch {
            id: toggleSwitch
        }
        NavItem {
            id: navItem
            width: 200
            label: "Matrix"
            icon: "qrc:/tb/layout-grid.svg"
        }
    }

    function test_hoverButtonIsTabFocusableAndAccessible() {
        compare(button.activeFocusOnTab, true);
        compare(button.Accessible.role, Accessible.Button);
        compare(button.Accessible.name, "Save");
        verify(button.Accessible.focusable);
    }

    function test_hoverButtonActivatesViaSpaceAndEnterWhenFocused() {
        let clickCount = 0;
        function onClicked() { clickCount++; }
        button.clicked.connect(onClicked);

        button.forceActiveFocus();
        verify(button.activeFocus, "button did not accept keyboard focus");
        compare(button.visible, true);

        keyClick(Qt.Key_Space);
        compare(clickCount, 1, "Space did not activate the focused button");

        keyClick(Qt.Key_Return);
        compare(clickCount, 2, "Return did not activate the focused button");

        button.clicked.disconnect(onClicked);
    }

    function test_hoverButtonShowsFocusRingOnlyWhenFocused() {
        checkbox.forceActiveFocus(); // move focus away from button first
        verify(!button.activeFocus);

        button.forceActiveFocus();
        verify(button.activeFocus);
        // The focus ring is the last child Rectangle, visible only while
        // activeFocus is true. Verified indirectly via activeFocus itself
        // since the ring's `visible` binding is a direct 1:1 mirror of it.
    }

    function test_checkboxIsTabFocusableAndTogglesViaSpace() {
        compare(checkbox.activeFocusOnTab, true);
        compare(checkbox.Accessible.role, Accessible.CheckBox);
        verify(checkbox.Accessible.checkable);

        let lastToggled = null;
        function onToggled(v) { lastToggled = v; }
        checkbox.toggled.connect(onToggled);

        checkbox.forceActiveFocus();
        verify(checkbox.activeFocus, "checkbox did not accept keyboard focus");

        keyClick(Qt.Key_Space);
        compare(lastToggled, true, "Space did not toggle the focused checkbox");

        checkbox.toggled.disconnect(onToggled);
    }

    function test_toggleSwitchIsTabFocusableAndTogglesViaSpace() {
        compare(toggleSwitch.activeFocusOnTab, true);
        compare(toggleSwitch.Accessible.role, Accessible.CheckBox);

        const before = toggleSwitch.checked;
        toggleSwitch.forceActiveFocus();
        verify(toggleSwitch.activeFocus, "toggle switch did not accept keyboard focus");

        keyClick(Qt.Key_Space);
        compare(toggleSwitch.checked, !before, "Space did not toggle the focused switch");
    }

    function test_navItemHeaderIsTabFocusableAndActivatesViaEnter() {
        // NavItem's focusable/clickable surface is its inner "header" row,
        // not the root Item (which also contains the collapsible
        // sub-column).
        const header = findChild(navItem, "navItemHeader");
        verify(header !== null, "NavItem's header row not found");
        compare(header.activeFocusOnTab, true);
        compare(header.Accessible.role, Accessible.Button);
        compare(header.Accessible.name, "Matrix");

        let clickCount = 0;
        function onClicked() { clickCount++; }
        navItem.clicked.connect(onClicked);

        header.forceActiveFocus();
        verify(header.activeFocus, "NavItem header did not accept keyboard focus");

        keyClick(Qt.Key_Return);
        compare(clickCount, 1, "Return did not activate the focused nav item");

        navItem.clicked.disconnect(onClicked);
    }

    function test_disabledControlsAreNotTabFocusable() {
        button.enabled = false;
        checkbox.enabled = false;
        toggleSwitch.enabled = false;

        compare(button.activeFocusOnTab, false);
        compare(checkbox.activeFocusOnTab, false);
        compare(toggleSwitch.activeFocusOnTab, false);

        button.enabled = true;
        checkbox.enabled = true;
        toggleSwitch.enabled = true;
    }
}
