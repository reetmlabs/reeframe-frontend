// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QHash>
#include <QObject>
#include <QPointer>
#include <QString>

// Lets a CameraTile's already-open IVideoSink be borrowed by FullCameraView
// instead of opening a second, independent connection to the same relay.
// FullCameraView calls notifyReleased() on destruction so the tile can
// reclaim the display.
class VideoSinkRegistry : public QObject {
    Q_OBJECT
  public:
    explicit VideoSinkRegistry(QObject* parent = nullptr);

    Q_INVOKABLE void registerSink(const QString& cameraId, QObject* sink);
    Q_INVOKABLE void unregisterSink(const QString& cameraId, QObject* sink);
    Q_INVOKABLE QObject* sinkFor(const QString& cameraId) const;
    Q_INVOKABLE void notifyReleased(const QString& cameraId);

  signals:
    void released(const QString& cameraId);

  private:
    QHash<QString, QPointer<QObject>> m_sinks;
};
