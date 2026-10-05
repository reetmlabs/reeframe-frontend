// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// The status dot must reflect both the video player's connectionState and
// backend reachability, not connectionState alone, since a player can still
// report "connected" on buffered data after the backend has gone down.
TestCase {
    id: testCase
    name: "CameraTileHeaderReachability"
    width: 400
    height: 400
    visible: true
    when: windowShown

    CameraTileHeader {
        id: header
        cameraName: "Test Camera"
        connectionState: "connected"
        isRecording: false
    }

    function test_dotIsGreenWhenConnectedAndBackendReachable() {
        header.backendReachable = true;
        compare(header.dotColor, Theme.success);
    }

    function test_dotIsErrorWhenBackendUnreachableEvenIfPlayerReportsConnected() {
        header.backendReachable = false;
        compare(header.dotColor, Theme.error);
    }
}
