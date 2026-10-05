// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Regression coverage for destination-type-driven field visibility in
// TransportConfigPanel. Path and filename templates only apply to file-drop
// destinations. Contact list ID applies to none of the currently implemented
// types, since every adapter delivers to an address, chat, or channel fixed
// on the Destination's own config (see the backend's vms-transports
// adapters, which is where this split comes from).
TestCase {
    id: testCase
    name: "TransportConfigPanel"
    width: 400
    height: 600
    visible: true
    when: windowShown

    function initTestCase() {
        DestinationModel.clearTestDestinations();
    }

    TransportConfigPanel {
        id: panel
        width: 400
        height: 600
    }

    function test_1_s3DestinationIsFileBased() {
        const id = "qmltest-transport-s3-" + Date.now();
        DestinationModel.insertTestDestination(id, "S3 bucket", "s3");
        panel.nodeData = { id: "node-" + id, config: { destination_id: id } };

        compare(panel.selectedDestinationType, "s3");
        compare(panel.isFileBasedDestination, true);
        compare(panel.isContactBasedDestination, false);
    }

    function test_2_telegramDestinationIsNeitherFileNorContactBased() {
        const id = "qmltest-transport-telegram-" + Date.now();
        DestinationModel.insertTestDestination(id, "Ops Telegram", "telegram");
        panel.nodeData = { id: "node-" + id, config: { destination_id: id } };

        // Bot-only: a bot always posts to the one chat_id on the Destination
        // itself, so there's no per-node contact list for it to pick.
        compare(panel.selectedDestinationType, "telegram");
        compare(panel.isFileBasedDestination, false);
        compare(panel.isContactBasedDestination, false);
    }

    function test_2b_slackDestinationIsNotContactBased() {
        const id = "qmltest-transport-slack-" + Date.now();
        DestinationModel.insertTestDestination(id, "Ops Slack", "slack");
        panel.nodeData = { id: "node-" + id, config: { destination_id: id } };

        // Slack delivers to the channel fixed on the Destination's own
        // config, not to a per-node contact list.
        compare(panel.selectedDestinationType, "slack");
        compare(panel.isFileBasedDestination, false);
        compare(panel.isContactBasedDestination, false);
    }

    function test_2c_emailDestinationIsNotContactBased() {
        const id = "qmltest-transport-email-" + Date.now();
        DestinationModel.insertTestDestination(id, "Ops Email", "email");
        panel.nodeData = { id: "node-" + id, config: { destination_id: id } };

        // Email delivers to the "to" address fixed on the Destination's own
        // config, not to a per-node contact list.
        compare(panel.selectedDestinationType, "email");
        compare(panel.isFileBasedDestination, false);
        compare(panel.isContactBasedDestination, false);
    }

    function test_3_noDestinationSelectedHidesBothGroups() {
        panel.nodeData = { id: "node-none", config: {} };

        compare(panel.selectedDestinationType, "");
        compare(panel.isFileBasedDestination, false);
        compare(panel.isContactBasedDestination, false);
    }

    function test_4_savingAnEmailNodeDropsAStaleContactListId() {
        const destId = "qmltest-transport-email-stale-" + Date.now();
        DestinationModel.insertTestDestination(destId, "Ops Email", "email");
        const nodeId = PipelineGraphModel.addNode("transport", 0, 0);
        PipelineGraphModel.updateNodeConfig(nodeId, {
            destination_id: destId,
            contact_list_id: "11111111-1111-1111-1111-111111111111",
        });

        panel.nodeData = PipelineGraphModel.nodeById(nodeId);
        panel.commitConfig();

        verify(!("contact_list_id" in PipelineGraphModel.nodeById(nodeId).config),
               "a stale contact_list_id must be dropped once an email node saves again");

        PipelineGraphModel.removeNode(nodeId);
    }
}
