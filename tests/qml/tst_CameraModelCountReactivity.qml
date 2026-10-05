// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Guards CameraPanel's "No cameras" empty state against staying visible
// after the first camera is added. A binding on `CameraModel.rowCount()` (a
// plain method call, not a Q_PROPERTY) only re-evaluates when some OTHER
// real property in the same expression changes, never on a row
// insert/remove alone. CameraModel's `count` Q_PROPERTY emits countChanged
// on rowsInserted/rowsRemoved/modelReset, the same pattern SiteManager uses.
//
// The check below binds `trackedCount` declaratively to `CameraModel.count`
// and never re-reads it explicitly. This is the exact mechanism a
// `visible: ... CameraModel.count === 0` expression relies on, and it's
// what an imperative `const x = CameraModel.count` read after the fact
// would NOT actually exercise (that always reflects the current value
// regardless of whether change notifications are wired correctly).
TestCase {
    id: testCase
    name: "CameraModelCountReactivity"
    when: true

    Component {
        id: probeComponent
        QtObject {
            property int trackedCount: CameraModel.count
        }
    }

    function test_bindingReactsToInsertWithoutExplicitReread() {
        const before = CameraModel.count;
        compare(before, CameraModel.rowCount(), "count property must mirror rowCount()");

        const probe = probeComponent.createObject(testCase, {});
        verify(probe !== null, "failed to create probe object");
        compare(probe.trackedCount, before);

        CameraModel.insertTestCamera("qmltest-count-reactivity-" + Date.now(), "Reactivity Probe");

        tryCompare(probe, "trackedCount", before + 1);
        probe.destroy();
    }
}
