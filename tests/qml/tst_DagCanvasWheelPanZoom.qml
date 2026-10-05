// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for DagCanvas's WheelHandler: Ctrl+wheel zooms, a plain wheel
// pans, and Shift+wheel and a native horizontal wheel delta both pan
// horizontally. Also covers the Ctrl+=/Ctrl+- keyboard fallback for zoom.
TestCase {
    id: testCase
    name: "DagCanvasWheelPanZoom"
    width: 400
    height: 300
    visible: true
    when: windowShown

    DagCanvas {
        id: canvas
        anchors.fill: parent
    }

    function initTestCase() {
        canvas.resetView()
    }

    function init() {
        canvas.resetView()
    }

    function test_ctrlWheelStillZooms() {
        mouseWheel(canvas, 200, 150, 0, 120, Qt.NoButton, Qt.ControlModifier)

        verify(canvas.zoom > 1.0, "Ctrl+wheel up must still zoom in")
    }

    function test_plainWheelPansVerticallyInsteadOfZooming() {
        mouseWheel(canvas, 200, 150, 0, 120)

        compare(canvas.zoom, 1.0, "a plain wheel must not zoom")
        verify(canvas.panY !== 0, "a plain wheel must pan vertically")
        compare(canvas.panX, 0, "a plain vertical wheel must not pan horizontally")
    }

    function test_shiftWheelPansHorizontally() {
        mouseWheel(canvas, 200, 150, 0, 120, Qt.NoButton, Qt.ShiftModifier)

        compare(canvas.zoom, 1.0)
        compare(canvas.panY, 0, "Shift+wheel must not pan vertically")
        verify(canvas.panX !== 0, "Shift+wheel must pan horizontally")
    }

    function test_nativeHorizontalWheelPansHorizontally() {
        mouseWheel(canvas, 200, 150, 90, 0)

        compare(canvas.zoom, 1.0)
        compare(canvas.panY, 0, "a native horizontal wheel delta must not pan vertically")
        verify(canvas.panX !== 0, "a native horizontal wheel delta must pan horizontally")
    }

    // Keyboard fallback for zoom: some Wayland setups don't
    // deliver modifier state to wheel events, so Ctrl+wheel above can't be
    // the only way in.
    function test_ctrlEqualsZoomsIn() {
        keyClick(Qt.Key_Equal, Qt.ControlModifier)

        verify(canvas.zoom > 1.0, "Ctrl+= must zoom in")
    }

    function test_ctrlMinusZoomsOut() {
        canvas.zoom = 2.0

        keyClick(Qt.Key_Minus, Qt.ControlModifier)

        verify(canvas.zoom < 2.0, "Ctrl+- must zoom out")
    }

    function test_zoomInButtonZoomsIn() {
        const zoomInBtn = findChild(canvas, "dagCanvasZoomInButton");
        verify(zoomInBtn !== null, "zoom-in button not found");

        zoomInBtn.clicked();

        verify(canvas.zoom > 1.0, "the zoom-in button must zoom in");
    }

    function test_zoomOutButtonZoomsOut() {
        const zoomOutBtn = findChild(canvas, "dagCanvasZoomOutButton");
        verify(zoomOutBtn !== null, "zoom-out button not found");

        zoomOutBtn.clicked();

        verify(canvas.zoom < 1.0, "the zoom-out button must zoom out");
    }

    function test_zoomResetButtonRestoresDefaultView() {
        const zoomResetBtn = findChild(canvas, "dagCanvasZoomResetButton");
        verify(zoomResetBtn !== null, "zoom-reset button not found");

        canvas.zoom = 2.0;
        canvas.panX = 40;
        canvas.panY = 40;

        zoomResetBtn.clicked();

        compare(canvas.zoom, 1.0, "the reset button must restore default zoom");
        compare(canvas.panX, 0, "the reset button must restore default pan");
        compare(canvas.panY, 0, "the reset button must restore default pan");
    }
}
