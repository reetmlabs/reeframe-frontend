// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// A Transport node shows its destination's type (S3, Email, ...) as a chip in
// the bottom-right of the card, looked up live from DestinationModel. Nodes
// with no destination, an unknown destination, or of another type show none.
TestCase {
    id: testCase
    name: "DagNodeTransportTypeChip"
    width: 600
    height: 400
    visible: true
    when: windowShown

    readonly property string s3DestId: "chip-dest-s3-" + Date.now()
    readonly property string lateDestId: "chip-dest-late-" + Date.now()

    DagNode {
        id: s3Node
        x: 20; y: 20
        nodeData: ({ id: "chipS3", type: "transport", x: 20, y: 20,
                     config: { destination_id: testCase.s3DestId } })
    }

    DagNode {
        id: emptyNode
        x: 220; y: 20
        nodeData: ({ id: "chipEmpty", type: "transport", x: 220, y: 20, config: {} })
    }

    DagNode {
        id: unknownNode
        x: 420; y: 20
        nodeData: ({ id: "chipUnknown", type: "transport", x: 420, y: 20,
                     config: { destination_id: "chip-dest-missing" } })
    }

    DagNode {
        id: lateNode
        x: 20; y: 150
        nodeData: ({ id: "chipLate", type: "transport", x: 20, y: 150,
                     config: { destination_id: testCase.lateDestId } })
    }

    DagNode {
        id: actionNode
        x: 220; y: 150
        nodeData: ({ id: "chipAction", type: "action", x: 220, y: 150,
                     config: { destination_id: testCase.s3DestId } })
    }

    function initTestCase() {
        DestinationModel.clearTestDestinations()
        DestinationModel.insertTestDestination(s3DestId, "Footage bucket", "s3")
    }

    function cleanupTestCase() {
        DestinationModel.clearTestDestinations()
    }

    function chipFor(node) {
        const chip = findChild(node, "dagNodeTypeChip_" + node.nodeData.id)
        verify(chip !== null, "type chip not found on " + node.nodeData.id)
        return chip
    }

    function test_transportShowsItsDestinationType() {
        const chip = chipFor(s3Node)
        verify(chip.visible)
        compare(chip.type, "s3")

        const box = chip.mapToItem(s3Node, 0, 0, chip.width, chip.height)
        const port = findChild(s3Node, "dagNodeOutputPort_chipS3_0")
        verify(port !== null, "output port not found")
        verify(box.x >= 0 && box.y >= 0 && box.y + box.height <= s3Node.height,
               "the chip must sit inside the card")
        verify(box.x + box.width <= port.x, "the chip must stay clear of the output port")
    }

    function test_noBadgeWithoutAKnownDestination() {
        verify(!chipFor(emptyNode).visible, "a Transport with no destination shows no chip")
        verify(!chipFor(unknownNode).visible, "an unknown destination shows no chip")
    }

    function test_badgeAppearsOnceTheDestinationLoads() {
        verify(!chipFor(lateNode).visible)
        DestinationModel.insertTestDestination(lateDestId, "Ops inbox", "email")
        tryCompare(chipFor(lateNode), "visible", true)
        compare(chipFor(lateNode).type, "email")
    }

    function test_otherNodeTypesShowNoBadge() {
        verify(!chipFor(actionNode).visible, "only Transport nodes show a destination chip")
    }
}
