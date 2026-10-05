// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "QtMultimediaVideoSink.h"
#include "LiveViewLogging.h"
#include <QCoreApplication>
#include <QElapsedTimer>

namespace {

qint64 monotonicMs() {
    static QElapsedTimer clock = [] {
        QElapsedTimer t;
        t.start();
        return t;
    }();
    return clock.elapsed();
}

// One timer checks every open sink, rather than one timer per tile.
QList<QtMultimediaVideoSink*>& watchedSinks() {
    static QList<QtMultimediaVideoSink*> sinks;
    return sinks;
}

} // namespace

QtMultimediaVideoSink::QtMultimediaVideoSink(QObject* parent) : IVideoSink(parent) {
    m_reconnectTimer.setSingleShot(true);

    connect(&m_reconnectTimer, &QTimer::timeout, this, [this] {
        if (!m_lastUrl.isEmpty())
            play();
    });

    connect(&m_player, &QMediaPlayer::playbackStateChanged, this,
            [this] { emit connectedChanged(); });

    connect(&m_player, &QMediaPlayer::errorOccurred, this,
            [this](QMediaPlayer::Error, const QString& errorString) {
                emit streamError(errorString);
                if (!m_lastUrl.isEmpty()) {
                    reportStall(errorString);
                    m_reconnectTimer.start(3000);
                }
            });

    connect(&m_player, &QMediaPlayer::mediaStatusChanged, this,
            [this](QMediaPlayer::MediaStatus status) {
                if (status == QMediaPlayer::EndOfMedia || status == QMediaPlayer::InvalidMedia) {
                    if (!m_lastUrl.isEmpty()) {
                        reportStall(status == QMediaPlayer::EndOfMedia ? "end of media"
                                                                       : "invalid media");
                        m_reconnectTimer.start(3000);
                    }
                }
            });
}

QtMultimediaVideoSink::~QtMultimediaVideoSink() {
    setWatched(false);
}

void QtMultimediaVideoSink::setVideoOutput(QObject* videoSink) {
    QObject::disconnect(m_frameConnection);
    m_videoSink = qobject_cast<QVideoSink*>(videoSink);
    m_player.setVideoSink(m_videoSink);
    m_lastFrameMs.store(monotonicMs(), std::memory_order_relaxed);
    if (m_videoSink) {
        // Direct, since frames can arrive on a decoder thread and queuing
        // an event per frame per tile would load the UI thread.
        m_frameConnection = connect(
            m_videoSink, &QVideoSink::videoFrameChanged, this,
            [this] { m_lastFrameMs.store(monotonicMs(), std::memory_order_relaxed); },
            Qt::DirectConnection);
    }
}

void QtMultimediaVideoSink::open(const QString& rtspUrl) {
    m_lastUrl = rtspUrl;
    m_stallReported = false;
    m_lastFrameMs.store(monotonicMs(), std::memory_order_relaxed);
    setWatched(true);
    play();
}

// Internal retries of the same URL go through here so they don't reset the
// stall clock that open() starts.
void QtMultimediaVideoSink::play() {
    m_reconnectTimer.stop();
    m_player.setSource(QUrl(m_lastUrl));
    m_player.play();
}

void QtMultimediaVideoSink::close() {
    setWatched(false);
    m_reconnectTimer.stop();
    m_lastUrl.clear();
    m_player.stop();
    m_player.setSource(QUrl{});
}

bool QtMultimediaVideoSink::connected() const {
    return m_player.playbackState() == QMediaPlayer::PlayingState;
}

void QtMultimediaVideoSink::setStallTimeoutMs(int ms) {
    if (m_stallTimeoutMs == ms)
        return;
    m_stallTimeoutMs = ms;
    emit stallTimeoutMsChanged();
}

void QtMultimediaVideoSink::checkForStall(qint64 nowMs) {
    // Without a video output the player has nowhere to deliver frames, so
    // their absence says nothing about the stream.
    if (m_stallReported || m_lastUrl.isEmpty() || !m_videoSink)
        return;
    const qint64 silentMs = nowMs - m_lastFrameMs.load(std::memory_order_relaxed);
    if (silentMs > m_stallTimeoutMs)
        reportStall(QStringLiteral("no frames for %1 ms").arg(silentMs));
}

void QtMultimediaVideoSink::reportStall(const QString& reason) {
    if (m_stallReported)
        return;
    m_stallReported = true;
    qCDebug(lcLiveView) << "stream stalled:" << m_lastUrl << "-" << reason;
    emit stalled();
}

QTimer* QtMultimediaVideoSink::stallWatchdog() {
    static QPointer<QTimer> timer;
    if (!timer) {
        timer = new QTimer(QCoreApplication::instance());
        timer->setInterval(1000);
        QObject::connect(timer, &QTimer::timeout, timer, [] {
            const qint64 now = monotonicMs();
            // Copied and rechecked, since a stalled() handler may close or
            // destroy other sinks mid-loop.
            for (auto* sink : QList(watchedSinks())) {
                if (watchedSinks().contains(sink))
                    sink->checkForStall(now);
            }
        });
    }
    return timer;
}

void QtMultimediaVideoSink::setWatched(bool watched) {
    auto& sinks = watchedSinks();
    if (watched) {
        if (sinks.contains(this))
            return;
        sinks.append(this);
        stallWatchdog()->start();
    } else if (sinks.removeOne(this) && sinks.isEmpty()) {
        stallWatchdog()->stop();
    }
}
