// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Checks that the header's close button (icon and click target) stays
// visible on a narrow (e.g. 1-column) matrix tile, like the expand button
// next to it. A minimum-width gate on it would hide it on such tiles.
TestCase {
    id: testCase
    name: "CameraTileHeaderCloseVisibility"
    width: 400
    height: 400
    visible: true
    when: windowShown

    CameraTileHeader {
        id: header
        width: 60 // a narrow 1-column tile
        cameraName: "Narrow Tile"
        connectionState: "connected"
        isRecording: false
    }

    function test_closeButtonVisibleAtNarrowWidth() {
        const closeIcon = findChild(header, "closeButtonIcon");
        verify(closeIcon !== null, "close icon not found");
        compare(closeIcon.visible, true, "close button must stay visible at a narrow tile width");
    }

    function test_expandButtonStillVisibleAtNarrowWidth() {
        const expandButton = findChild(header, "expandButton");
        verify(expandButton !== null, "expand button not found");
        compare(expandButton.visible, true);
    }
}
