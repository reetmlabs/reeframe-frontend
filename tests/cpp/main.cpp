// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include <QtQml/qqmlextensionplugin.h>
#include <QtQuickTest/quicktest.h>

#include "TestSetup.h"

// See src/main.cpp for why this is required: reeframe-fe-core's "Reeframe"
// QML module is a static plugin that qmlimportscanner can't auto-detect for
// this target (the test .qml files are loaded from disk at runtime via
// QUICK_TEST_SOURCE_DIR, not scanned as QML_FILES).
Q_IMPORT_QML_PLUGIN(ReeframePlugin)

QUICK_TEST_MAIN_WITH_SETUP(reeframe_fe_qml_tests, TestSetup)
