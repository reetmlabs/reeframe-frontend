// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include "ApiTypes.h"
#include <QAbstractListModel>
#include <QHash>
#include <QList>
#include <QPointer>
#include <QString>
#include <QVariantList>

class SiteManager;
class AuthenticatedRecordingDevice;

class RecordingModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
  public:
    enum Role {
        RecordingIdRole = Qt::UserRole + 1,
        ChunkIndexRole,
        StartTimeRole,
        EndTimeRole,
        SizeBytesRole,
        CodecRole,
    };
    Q_ENUM(Role)

    explicit RecordingModel(SiteManager* siteManager, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool loading() const { return m_loading; }

    // from/to are RFC 3339 timestamps, e.g. "2026-07-20T00:00:00Z". Lists
    // chunks overlapping [from, to), oldest first.
    Q_INVOKABLE void fetchRecordings(const QString& cameraId, const QString& from,
                                     const QString& to);

    // at is an RFC 3339 timestamp. cameraId is echoed back on every signal
    // since multiple camera tiles share this one model instance.
    Q_INVOKABLE void resolvePlayback(const QString& cameraId, const QString& at);

    // Lets QMediaPlayer play a Bearer-authenticated recording, since
    // QMediaPlayer::setSource(QUrl) can't attach that header (see
    // AuthenticatedRecordingDevice). mediaPlayer must be a QMediaPlayer (the
    // QML MediaPlayer element is one); path is a playbackResolved streamUrl.
    Q_INVOKABLE void attachAuthenticatedPlayback(QObject* mediaPlayer, const QString& path);

    // Merges consecutive chunks (gap under gapToleranceSecs) into session
    // ranges, so chunking (an internal recording-safety detail) stays
    // hidden from the operator.
    Q_INVOKABLE QVariantList sessions(int gapToleranceSecs) const;

    // Buckets currently-fetched chunks into per-day sessions (like
    // sessions()), most recent day first. firstSessionStart is the safe
    // seek target for "preview from start", since local midnight itself
    // may be unrecorded.
    Q_INVOKABLE QVariantList dailySummaries(int gapToleranceSecs) const;

    // Reads recordings.retention_days from GET /system/settings, to cap how
    // far back the date-range picker allows selecting. Emits
    // retentionDaysFetched with a fallback default if the fetch fails or the
    // setting is missing.
    Q_INVOKABLE void fetchRetentionDays();

    // from/to are bare "yyyy-MM-dd" dates (to exclusive). A different
    // endpoint from fetchRecordings(), backed by a server-side precomputed
    // table refreshed periodically rather than computed on demand. Emits
    // dailySummaryFetched with the same shape dailySummaries() produces.
    //
    // Day boundaries are UTC (backend-side), not the local calendar day.
    // This is an accepted limitation.
    Q_INVOKABLE void fetchDailySummary(const QString& cameraId, const QString& from,
                                       const QString& to);

    // Test-only seam: exercises fetchDailySummary()'s response parsing
    // against a hand-crafted JSON string, without a real server.
    Q_INVOKABLE QVariantList parseDailySummaryForTest(const QString& json) const;

    // Test-only seeding, mirroring CameraModel::insertTestCamera/
    // clearTestCameras. Lets QML tests exercise sessions() and the
    // chunk-row UI without a real backend.
    Q_INVOKABLE void insertTestChunk(const QString& startTime, const QString& endTime,
                                     qint64 sizeBytes);
    Q_INVOKABLE void clearTestChunks();

  signals:
    void loadingChanged();
    void countChanged();
    void fetchFailed(const QString& message);
    // at echoes back resolvePlayback()'s own request, so a listener can tell
    // a stale response (superseded by a newer seek before this one arrived)
    // apart from the one it's still waiting on.
    void playbackResolved(const QString& cameraId, const QString& recordingId,
                          const QString& streamUrl, double offsetSecs, const QString& at);
    void playbackGap(const QString& cameraId, const QString& nearestBefore,
                     const QString& nearestAfter, const QString& at);
    void playbackFailed(const QString& cameraId, const QString& message, const QString& at);
    void retentionDaysFetched(int days);
    void dailySummaryFetched(const QVariantList& days);
    void dailySummaryFetchFailed(const QString& message);

  private:
    static RecordingDto fromJson(const QJsonObject& obj);
    static QVariantList parseDailySummary(const QJsonDocument& doc);
    void setLoading(bool v);

    SiteManager* m_siteManager;
    QList<RecordingDto> m_recordings;
    bool m_loading = false;
    // One device per player, so attachAuthenticatedPlayback() can tear down
    // the previous one (QMediaPlayer::setSourceDevice() doesn't own it).
    QHash<QObject*, QPointer<AuthenticatedRecordingDevice>> m_playbackDevices;
};
