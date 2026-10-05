// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QLoggingCategory>

// Live view reconnect decisions: backend status edges, relay requests and
// stream stalls. Debug output is off by default; enable it with
// QT_LOGGING_RULES="reeframe.liveview.debug=true".
Q_DECLARE_LOGGING_CATEGORY(lcLiveView)
