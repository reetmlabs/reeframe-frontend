// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "VideoSinkRegistry.h"

VideoSinkRegistry::VideoSinkRegistry(QObject* parent) : QObject(parent) {}

void VideoSinkRegistry::registerSink(const QString& cameraId, QObject* sink) {
    if (cameraId.isEmpty() || !sink)
        return;
    m_sinks[cameraId] = sink;
}

void VideoSinkRegistry::unregisterSink(const QString& cameraId, QObject* sink) {
    if (m_sinks.value(cameraId) == sink)
        m_sinks.remove(cameraId);
}

QObject* VideoSinkRegistry::sinkFor(const QString& cameraId) const {
    return m_sinks.value(cameraId);
}

void VideoSinkRegistry::notifyReleased(const QString& cameraId) {
    emit released(cameraId);
}
