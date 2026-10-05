// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for AddSourceDialog's edit mode: opening it on an existing source
// must prefill every field the backend does not mask, leave masked
// credential fields blank, and lock the type combo (see
// SourceModel::sourceById and ApiTypes.h's SourceDto::config).
TestCase {
    id: testCase
    name: "EditSourceDialog"
    width: 800
    height: 800
    visible: true
    when: windowShown

    AddSourceDialog {
        id: dialog
    }

    function initTestCase() {
        SourceModel.clearTestSources();
    }

    function test_editModePrefillsNonCredentialFieldsAndBlanksCredential() {
        const id = "qmltest-edit-source-mqtt-" + Date.now();
        SourceModel.insertTestSource(id, "Living room sensor", "mqtt", {
            host: "192.168.1.100",
            port: 1883,
            topic: "sensors/#",
            username: "sensor-user",
            password: "***",
        });

        dialog.sourceId = id;
        dialog.isEditMode = true;
        dialog.open();

        const nameField = findChild(dialog, "sourceNameField");
        const brokerField = findChild(dialog, "sourceMqttBrokerField");
        const topicField = findChild(dialog, "sourceMqttTopicField");
        const userField = findChild(dialog, "sourceMqttUserField");
        const passField = findChild(dialog, "sourceMqttPassField");
        const typeCombo = findChild(dialog, "sourceTypeCombo");

        compare(nameField.text, "Living room sensor");
        compare(brokerField.text, "192.168.1.100:1883");
        compare(topicField.text, "sensors/#");
        compare(userField.text, "sensor-user");
        compare(passField.text, "", "a masked credential field must never be prefilled");
        compare(typeCombo.currentIndex, 0, "type combo must land on mqtt");
        compare(typeCombo.enabled, false, "type cannot be changed once a source exists");

        dialog.close();
    }

    function test_addModeStartsBlankWithTypeEditable() {
        dialog.sourceId = "";
        dialog.isEditMode = false;
        dialog.open();

        const nameField = findChild(dialog, "sourceNameField");
        const brokerField = findChild(dialog, "sourceMqttBrokerField");
        const typeCombo = findChild(dialog, "sourceTypeCombo");

        compare(nameField.text, "");
        compare(brokerField.text, "");
        compare(typeCombo.enabled, true);

        dialog.close();
    }
}
