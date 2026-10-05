// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtMultimedia
import QtTest
import Reeframe

// A live sink must report a stream that delivers no frames, including one
// that never connects, exactly once per open() so its owner can request a
// fresh relay, and never once it has been closed.
TestCase {
    id: testCase
    name: "VideoSinkStall"
    width: 320
    height: 240
    visible: true
    when: windowShown

    VideoOutput { id: output; anchors.fill: parent }

    QtMultimediaVideoSink {
        id: sink
        stallTimeoutMs: 300
    }

    SignalSpy {
        id: stalledSpy
        target: sink
        signalName: "stalled"
    }

    function init() {
        sink.setVideoOutput(output.videoSink);
    }

    function cleanup() {
        sink.close();
        stalledSpy.clear();
    }

    function test_reportsAStreamWithNoFramesOnlyOncePerOpen() {
        sink.open("rtsp://127.0.0.1:1/unreachable");
        tryCompare(stalledSpy, "count", 1, 5000,
                   "a stream that delivers no frames must be reported as stalled");

        // Longer than the sink's own same-URL retry, which must not re-arm it.
        wait(3500);
        compare(stalledSpy.count, 1, "a stall must be reported once per open()");

        sink.open("rtsp://127.0.0.1:1/unreachable");
        tryCompare(stalledSpy, "count", 2, 5000,
                   "reopening must arm stall detection again");
    }

    function test_closedSinkNeverReportsAStall() {
        sink.open("rtsp://127.0.0.1:1/unreachable");
        sink.close();
        wait(1500);
        compare(stalledSpy.count, 0, "a closed sink must not report a stall");
    }
}
