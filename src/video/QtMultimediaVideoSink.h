// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include "IVideoSink.h"
#include <QMediaPlayer>
#include <QPointer>
#include <QTimer>
#include <QVideoSink>
#include <QtQml/qqml.h>
#include <atomic>

class QtMultimediaVideoSink : public IVideoSink {
    Q_OBJECT
    QML_ELEMENT
    // How long an open stream may go without a decoded frame before
    // stalled() fires.
    Q_PROPERTY(int stallTimeoutMs READ stallTimeoutMs WRITE setStallTimeoutMs NOTIFY
                   stallTimeoutMsChanged)

  public:
    explicit QtMultimediaVideoSink(QObject* parent = nullptr);
    ~QtMultimediaVideoSink() override;

    void open(const QString& rtspUrl) override;
    void close() override;
    bool connected() const override;
    Q_INVOKABLE void setVideoOutput(QObject* videoSink) override;

    int stallTimeoutMs() const { return m_stallTimeoutMs; }
    void setStallTimeoutMs(int ms);

  signals:
    void stallTimeoutMsChanged();

  private:
    void play();
    void checkForStall(qint64 nowMs);
    void reportStall(const QString& reason);
    void setWatched(bool watched);
    static QTimer* stallWatchdog();

    QMediaPlayer m_player;
    QTimer m_reconnectTimer;
    QString m_lastUrl;
    QPointer<QVideoSink> m_videoSink;
    QMetaObject::Connection m_frameConnection;
    // Written from whichever thread delivers frames, read by the watchdog.
    std::atomic<qint64> m_lastFrameMs{0};
    bool m_stallReported = false;
    int m_stallTimeoutMs = 5000;
};
