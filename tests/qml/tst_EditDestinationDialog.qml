// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for AddDestinationDialog's edit mode: opening it on an existing
// destination must prefill every field the backend does not mask, leave
// masked credential fields blank, and lock the type combo (see
// DestinationModel::destinationById and ApiTypes.h's DestinationDto::config).
TestCase {
    id: testCase
    name: "EditDestinationDialog"
    width: 800
    height: 800
    visible: true
    when: windowShown

    AddDestinationDialog {
        id: dialog
    }

    function initTestCase() {
        DestinationModel.clearTestDestinations();
    }

    function test_editModePrefillsNonCredentialFieldsAndBlanksCredential() {
        const id = "qmltest-edit-dest-s3-" + Date.now();
        DestinationModel.insertTestDestination(id, "Archive bucket", "s3", {
            bucket: "my-bucket",
            region: "eu-west-1",
            access_key_id: "AKIA_VISIBLE",
            secret_access_key: "***",
            endpoint: "https://minio.internal:9000",
            path_style_access: true,
        });

        dialog.destinationId = id;
        dialog.isEditMode = true;
        dialog.open();

        const nameField = findChild(dialog, "destinationNameField");
        const bucketField = findChild(dialog, "destS3BucketField");
        const regionField = findChild(dialog, "destS3RegionField");
        const keyField = findChild(dialog, "destS3KeyField");
        const secretField = findChild(dialog, "destS3SecretField");
        const endpointField = findChild(dialog, "destS3EndpointField");
        const pathStyleToggle = findChild(dialog, "destS3PathStyleToggle");
        const typeCombo = findChild(dialog, "destinationTypeCombo");

        compare(nameField.text, "Archive bucket");
        compare(bucketField.text, "my-bucket");
        compare(regionField.text, "eu-west-1");
        compare(keyField.text, "AKIA_VISIBLE");
        compare(secretField.text, "", "a masked credential field must never be prefilled");
        compare(endpointField.text, "https://minio.internal:9000");
        compare(pathStyleToggle.checked, true);
        compare(typeCombo.currentIndex, 0, "type combo must land on s3");
        compare(typeCombo.enabled, false, "type cannot be changed once a destination exists");

        dialog.close();
    }

    function test_addModeStartsBlankWithTypeEditable() {
        dialog.destinationId = "";
        dialog.isEditMode = false;
        dialog.open();

        const nameField = findChild(dialog, "destinationNameField");
        const bucketField = findChild(dialog, "destS3BucketField");
        const endpointField = findChild(dialog, "destS3EndpointField");
        const pathStyleToggle = findChild(dialog, "destS3PathStyleToggle");
        const typeCombo = findChild(dialog, "destinationTypeCombo");

        compare(nameField.text, "");
        compare(bucketField.text, "");
        compare(endpointField.text, "");
        compare(pathStyleToggle.checked, false);
        compare(typeCombo.enabled, true);

        dialog.close();
    }
}
