// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QObject>
#include <QString>

class IVideoSink : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
  public:
    explicit IVideoSink(QObject* parent = nullptr) : QObject(parent) {}

    virtual Q_INVOKABLE void open(const QString& rtspUrl) = 0;
    virtual Q_INVOKABLE void close() = 0;
    virtual bool connected() const = 0;

    // Called from QML: pass VideoOutput.videoSink so the player can write to it.
    virtual Q_INVOKABLE void setVideoOutput(QObject* videoSink) = 0;

  signals:
    void connectedChanged();
    void streamError(const QString& message);
    // The open stream stopped delivering frames or failed. Emitted once per
    // open(); the owner should ask the backend for a fresh relay.
    void stalled();
};
