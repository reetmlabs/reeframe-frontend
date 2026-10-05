// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for the delayed-dispatch "Undo delete" primitive: scheduling an
// id delays onCommit rather than running it immediately, cancel() stops it
// from ever running if called in time, and multiple ids can be pending
// concurrently with independent countdowns.
TestCase {
    id: testCase
    name: "PendingDeleteQueue"
    when: true

    PendingDeleteQueue { id: queue }

    function test_scheduleCommitsAfterDelay() {
        const id = "a-" + Date.now();
        let committed = false;

        queue.schedule(id, 50, function() { committed = true; });

        verify(queue.isPending(id));
        verify(!committed, "must not commit before the delay elapses");

        tryVerify(function() { return committed; }, 1000);
        verify(!queue.isPending(id), "no longer pending once committed");
    }

    function test_cancelPreventsCommit() {
        const id = "b-" + Date.now();
        let committed = false;

        queue.schedule(id, 100, function() { committed = true; });
        verify(queue.isPending(id));

        const cancelled = queue.cancel(id);

        verify(cancelled, "cancel() should report success for a pending id");
        verify(!queue.isPending(id));

        wait(200);
        verify(!committed, "cancelled action must never commit");
    }

    function test_cancelUnknownIdReturnsFalse() {
        verify(!queue.cancel("never-scheduled-" + Date.now()));
    }

    function test_cancelAlreadyCommittedIdReturnsFalse() {
        const id = "c-" + Date.now();
        let committed = false;
        queue.schedule(id, 30, function() { committed = true; });

        tryVerify(function() { return committed; }, 1000);

        verify(!queue.cancel(id), "cancelling an already-committed id must be a no-op");
    }

    function test_concurrentPendingIdsAreIndependent() {
        const idKeep = "keep-" + Date.now();
        const idDrop = "drop-" + Date.now();
        let keepCommitted = false;
        let dropCommitted = false;

        queue.schedule(idKeep, 300, function() { keepCommitted = true; });
        queue.schedule(idDrop, 300, function() { dropCommitted = true; });

        queue.cancel(idDrop);

        verify(queue.isPending(idKeep), "cancelling one id must not affect another");
        verify(!queue.isPending(idDrop));

        tryVerify(function() { return keepCommitted; }, 1000);
        compare(dropCommitted, false, "cancelled action must never commit even after the other one does");
    }

    function test_versionIncrementsOnScheduleAndCancel() {
        const id = "v-" + Date.now();
        const before = queue.version;

        queue.schedule(id, 200, function() {});
        verify(queue.version > before, "version must bump on schedule");

        const afterSchedule = queue.version;
        queue.cancel(id);
        verify(queue.version > afterSchedule, "version must bump on cancel");
    }

    function test_reschedulingSameIdReplacesPreviousTimer() {
        const id = "r-" + Date.now();
        let firstCommitted = false;
        let secondCommitted = false;

        queue.schedule(id, 100, function() { firstCommitted = true; });
        queue.schedule(id, 100, function() { secondCommitted = true; });

        tryVerify(function() { return secondCommitted; }, 1000);
        compare(firstCommitted, false,
                "scheduling the same id again must replace the earlier pending action, not run both");
    }
}
