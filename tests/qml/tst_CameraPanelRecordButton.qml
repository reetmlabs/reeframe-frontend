// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for the camera list's per-row Rec/Stop button, added alongside
// the existing Edit/Delete row actions. CameraModel is one shared instance
// across every test file in this binary run, so this file clears it in
// initTestCase() to work with a known, isolated camera.
TestCase {
    id: testCase
    name: "CameraPanelRecordButton"
    width: 1280
    height: 800
    visible: true
    when: windowShown

    App {
        id: appUnderTest
        anchors.fill: parent
    }

    function initTestCase() {
        OverlayPrefs.cameraPanelOpen = true;
    }

    function test_recordButtonShowsRecAndFlipsToInFlightImmediatelyOnClick() {
        CameraModel.clearTestCameras();
        const id = "qmltest-rec-" + Date.now();
        CameraModel.insertTestCamera(id, "Rec Test Camera");
        wait(50); // ListView delegates are created incrementally

        const row = findChild(appUnderTest, "cameraRow_" + id);
        verify(row !== null, "camera row not found");

        // The action row (Rec/Edit/Delete) is hover-only, so move the mouse
        // over the row first so it actually becomes visible/clickable.
        mouseMove(row, row.width / 2, row.height / 2);
        wait(50);

        const recButton = findChild(row, "recordButtonRect");
        verify(recButton !== null, "record button not found");
        compare(recButton.text, "Rec", "a non-recording camera's button must read Rec");

        mouseClick(recButton, recButton.width / 2, recButton.height / 2);

        // recordingInFlight flips synchronously in onClicked, before any
        // reply from CameraModel.startRecording(), same convention as
        // FullCameraView's own Start/Stop Recording button.
        compare(recButton.text, "…",
                "button must show the in-flight state immediately on click");
    }

    function test_recordButtonShowsStopForAnAlreadyRecordingCamera() {
        CameraModel.clearTestCameras();
        const id = "qmltest-rec-already-" + Date.now();
        CameraModel.insertTestCamera(id, "Already Recording Camera", true);
        wait(50); // ListView delegates are created incrementally

        const row = findChild(appUnderTest, "cameraRow_" + id);
        verify(row !== null, "camera row not found");
        mouseMove(row, row.width / 2, row.height / 2);
        wait(50);

        const recButton = findChild(row, "recordButtonRect");
        verify(recButton !== null, "record button not found");
        compare(recButton.text, "Stop", "an already-recording camera's button must read Stop");
    }
}
