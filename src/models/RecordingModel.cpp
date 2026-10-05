// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "RecordingModel.h"
#include "AuthenticatedRecordingDevice.h"
#include "BackendClient.h"
#include "SiteManager.h"
#include <QDateTime>
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMediaPlayer>
#include <QRestReply>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>
#include <algorithm>

// Mirrors CameraModel.cpp's describeFailure(): reply.errorString() is
// transport-level only (empty for ordinary non-2xx replies). The real
// reason lives in the JSON body's "error" field.
static QString describeFailure(QRestReply& reply) {
    const auto doc = reply.readJson();
    const QString message =
        doc && doc->isObject() ? doc->object().value("error").toString() : QString{};
    return QStringLiteral("HTTP %1%2")
        .arg(reply.httpStatus())
        .arg(message.isEmpty() ? QString{} : QStringLiteral(" - ") + message);
}

RecordingModel::RecordingModel(SiteManager* siteManager, QObject* parent)
    : QAbstractListModel(parent), m_siteManager(siteManager) {
    connect(this, &QAbstractItemModel::rowsInserted, this, &RecordingModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &RecordingModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &RecordingModel::countChanged);
}

int RecordingModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : m_recordings.size();
}

QVariant RecordingModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_recordings.size())
        return {};
    const auto& r = m_recordings.at(index.row());
    switch (role) {
    case RecordingIdRole:
        return r.id;
    case ChunkIndexRole:
        return r.chunkIndex;
    case StartTimeRole:
        return r.startTime;
    case EndTimeRole:
        return r.endTime;
    case SizeBytesRole:
        return r.sizeBytes;
    case CodecRole:
        return r.codec;
    default:
        return {};
    }
}

QHash<int, QByteArray> RecordingModel::roleNames() const {
    return {
        {RecordingIdRole, "recordingId"},      {ChunkIndexRole, "recordingChunkIndex"},
        {StartTimeRole, "recordingStartTime"}, {EndTimeRole, "recordingEndTime"},
        {SizeBytesRole, "recordingSizeBytes"}, {CodecRole, "recordingCodec"},
    };
}

void RecordingModel::fetchRecordings(const QString& cameraId, const QString& from,
                                     const QString& to) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    setLoading(true);
    const QString path = QString("/cameras/%1/recordings?from=%2&to=%3")
                             .arg(cameraId, QString(QUrl::toPercentEncoding(from)),
                                  QString(QUrl::toPercentEncoding(to)));
    client->get(path, this, [this, cameraId](QRestReply& reply) {
        setLoading(false);
        if (!reply.isSuccess()) {
            const QString reason = describeFailure(reply);
            // No UI listener for fetchFailed, so this is logged to make an
            // empty list diagnosable rather than indistinguishable from "no recordings."
            qWarning() << "RecordingModel: fetch failed for" << cameraId << ":" << reason;
            emit fetchFailed(reason);
            return;
        }
        const auto doc = reply.readJson();
        if (!doc || !doc->isArray()) {
            qWarning() << "RecordingModel: unexpected response shape for" << cameraId;
            return;
        }
        QList<RecordingDto> recordings;
        for (const auto& val : doc->array())
            recordings.append(fromJson(val.toObject()));
        beginResetModel();
        m_recordings = std::move(recordings);
        endResetModel();
    });
}

void RecordingModel::resolvePlayback(const QString& cameraId, const QString& at) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    const QString path =
        QString("/cameras/%1/playback?at=%2").arg(cameraId, QString(QUrl::toPercentEncoding(at)));
    client->get(path, this, [this, cameraId, at](QRestReply& reply) {
        const auto doc = reply.readJson();
        if (reply.isSuccess()) {
            if (!doc || !doc->isObject()) {
                qWarning() << "RecordingModel: malformed playback response for" << cameraId;
                emit playbackFailed(cameraId, QStringLiteral("malformed playback response"), at);
                return;
            }
            const auto obj = doc->object();
            const QString streamUrl = obj["stream_url"].toString();
            if (streamUrl.isEmpty()) {
                qWarning() << "RecordingModel: playback resolved with an empty stream_url for"
                           << cameraId << "at" << at;
                emit playbackFailed(cameraId, QStringLiteral("no stream URL in playback response"),
                                    at);
                return;
            }
            emit playbackResolved(cameraId, obj["recording_id"].toString(), streamUrl,
                                  obj["offset_secs"].toDouble(), at);
            return;
        }
        if (reply.httpStatus() == 404 && doc && doc->isObject()) {
            const auto obj = doc->object();
            emit playbackGap(cameraId, obj["nearest_before"].toString(),
                             obj["nearest_after"].toString(), at);
            return;
        }
        const QString reason = describeFailure(reply);
        qWarning() << "RecordingModel: resolvePlayback failed for" << cameraId << ":" << reason;
        emit playbackFailed(cameraId, reason, at);
    });
}

void RecordingModel::attachAuthenticatedPlayback(QObject* mediaPlayer, const QString& path) {
    auto* player = qobject_cast<QMediaPlayer*>(mediaPlayer);
    if (!player)
        return;
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;

    // setSourceDevice() doesn't take ownership, so the previous device is
    // torn down here, delayed, since it doesn't guarantee the backend has
    // finished reading from that device by the time it returns.
    if (auto previous = m_playbackDevices.take(mediaPlayer))
        QTimer::singleShot(2000, previous, &QObject::deleteLater);

    auto* device = new AuthenticatedRecordingDevice(client, path, mediaPlayer);
    if (!device->open(QIODevice::ReadOnly)) {
        qWarning() << "RecordingModel: failed to open authenticated playback device for" << path;
        device->deleteLater();
        return;
    }
    m_playbackDevices.insert(mediaPlayer, device);
    player->setSourceDevice(device);
}

QVariantList RecordingModel::sessions(int gapToleranceSecs) const {
    QVariantList result;
    if (m_recordings.isEmpty())
        return result;

    auto toEpoch = [](const QString& iso) -> qint64 {
        return QDateTime::fromString(iso, Qt::ISODate).toSecsSinceEpoch();
    };

    QString sessionStart = m_recordings.first().startTime;
    QString sessionEnd = m_recordings.first().endTime;
    qint64 sessionSize = m_recordings.first().sizeBytes;
    int chunkCount = 1;

    auto flushSession = [&]() {
        QVariantMap session;
        session["startTime"] = sessionStart;
        session["endTime"] = sessionEnd;
        session["sizeBytes"] = sessionSize;
        session["chunkCount"] = chunkCount;
        result.append(session);
    };

    for (int i = 1; i < m_recordings.size(); ++i) {
        const auto& chunk = m_recordings.at(i);
        const bool contiguous = !sessionEnd.isEmpty() && (toEpoch(chunk.startTime) -
                                                          toEpoch(sessionEnd)) <= gapToleranceSecs;

        if (contiguous) {
            sessionEnd = chunk.endTime;
            sessionSize =
                (sessionSize < 0 || chunk.sizeBytes < 0) ? -1 : sessionSize + chunk.sizeBytes;
            chunkCount++;
        } else {
            flushSession();
            sessionStart = chunk.startTime;
            sessionEnd = chunk.endTime;
            sessionSize = chunk.sizeBytes;
            chunkCount = 1;
        }
    }
    flushSession();

    return result;
}

QVariantList RecordingModel::dailySummaries(int gapToleranceSecs) const {
    QVariantList days;
    if (m_recordings.isEmpty())
        return days;

    auto toEpoch = [](const QString& iso) -> qint64 {
        return QDateTime::fromString(iso, Qt::ISODate).toSecsSinceEpoch();
    };
    auto localDateOf = [](const QString& iso) {
        return QDateTime::fromString(iso, Qt::ISODate).toLocalTime().date();
    };

    struct DayAccum {
        QDate date;
        QVariantList sessions;
        qint64 totalCoverageSecs = 0;
        QString firstSessionStart;
    };
    QList<DayAccum> accum;

    QString sessionStart, sessionEnd;
    qint64 sessionSize = 0;
    int chunkCount = 0;

    auto flushSession = [&]() {
        if (accum.isEmpty())
            return;
        QVariantMap session;
        session["startTime"] = sessionStart;
        session["endTime"] = sessionEnd;
        session["sizeBytes"] = sessionSize;
        session["chunkCount"] = chunkCount;
        DayAccum& day = accum.last();
        day.sessions.append(session);
        if (day.firstSessionStart.isEmpty())
            day.firstSessionStart = sessionStart;
        if (!sessionEnd.isEmpty())
            day.totalCoverageSecs += toEpoch(sessionEnd) - toEpoch(sessionStart);
    };

    for (const auto& chunk : m_recordings) {
        const QDate chunkDate = localDateOf(chunk.startTime);
        const bool newDay = accum.isEmpty() || chunkDate != accum.last().date;
        const bool contiguous =
            !newDay && !sessionEnd.isEmpty() &&
            (toEpoch(chunk.startTime) - toEpoch(sessionEnd)) <= gapToleranceSecs;

        if (newDay) {
            flushSession();
            accum.append({chunkDate, {}, 0, {}});
            sessionStart = chunk.startTime;
            sessionEnd = chunk.endTime;
            sessionSize = chunk.sizeBytes;
            chunkCount = 1;
        } else if (contiguous) {
            sessionEnd = chunk.endTime;
            sessionSize =
                (sessionSize < 0 || chunk.sizeBytes < 0) ? -1 : sessionSize + chunk.sizeBytes;
            chunkCount++;
        } else {
            flushSession();
            sessionStart = chunk.startTime;
            sessionEnd = chunk.endTime;
            sessionSize = chunk.sizeBytes;
            chunkCount = 1;
        }
    }
    flushSession();

    // Most recent day first: the panel lists days newest-at-top.
    for (auto it = accum.crbegin(); it != accum.crend(); ++it) {
        QVariantMap dayMap;
        dayMap["date"] = it->date.toString(Qt::ISODate);
        dayMap["sessions"] = it->sessions;
        dayMap["totalCoverageSecs"] = it->totalCoverageSecs;
        dayMap["firstSessionStart"] = it->firstSessionStart;
        days.append(dayMap);
    }
    return days;
}

void RecordingModel::fetchRetentionDays() {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client) {
        emit retentionDaysFetched(30);
        return;
    }
    client->get("/system/settings", this, [this](QRestReply& reply) {
        if (!reply.isSuccess()) {
            qWarning() << "RecordingModel: fetchRetentionDays failed:" << describeFailure(reply);
            emit retentionDaysFetched(30);
            return;
        }
        const auto doc = reply.readJson();
        if (!doc || !doc->isArray()) {
            emit retentionDaysFetched(30);
            return;
        }
        for (const auto& val : doc->array()) {
            const auto obj = val.toObject();
            if (obj.value("key").toString() == QLatin1String("recordings.retention_days")) {
                const auto value = obj.value("value");
                emit retentionDaysFetched(value.isDouble() ? static_cast<int>(value.toDouble())
                                                           : 30);
                return;
            }
        }
        emit retentionDaysFetched(30);
    });
}

void RecordingModel::fetchDailySummary(const QString& cameraId, const QString& from,
                                       const QString& to) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    const QString path = QString("/cameras/%1/recordings/daily-summary?from=%2&to=%3")
                             .arg(cameraId, QString(QUrl::toPercentEncoding(from)),
                                  QString(QUrl::toPercentEncoding(to)));
    client->get(path, this, [this, cameraId](QRestReply& reply) {
        if (!reply.isSuccess()) {
            const QString reason = describeFailure(reply);
            qWarning() << "RecordingModel: fetchDailySummary failed for" << cameraId << ":"
                       << reason;
            emit dailySummaryFetchFailed(reason);
            return;
        }
        const auto doc = reply.readJson();
        if (!doc || !doc->isArray()) {
            qWarning() << "RecordingModel: unexpected daily-summary response shape for" << cameraId;
            emit dailySummaryFetchFailed(QStringLiteral("unexpected response shape"));
            return;
        }
        emit dailySummaryFetched(parseDailySummary(*doc));
    });
}

QVariantList RecordingModel::parseDailySummaryForTest(const QString& json) const {
    return parseDailySummary(QJsonDocument::fromJson(json.toUtf8()));
}

// Maps the backend's snake_case DailyCoverageDto[] (oldest day first) onto
// dailySummaries()'s camelCase shape (most recent first), so
// RecordingsPanel.qml renders both the same way.
QVariantList RecordingModel::parseDailySummary(const QJsonDocument& doc) {
    QVariantList days;
    if (!doc.isArray())
        return days;

    for (const auto& dayVal : doc.array()) {
        const auto dayObj = dayVal.toObject();

        QVariantList sessions;
        QString firstSessionStart;
        for (const auto& sessionVal : dayObj.value("session_ranges").toArray()) {
            const auto sessionObj = sessionVal.toObject();
            QVariantMap session;
            const QString startTime = sessionObj.value("start").toString();
            session["startTime"] = startTime;
            session["endTime"] =
                sessionObj.value("end").isNull() ? QString{} : sessionObj.value("end").toString();
            session["sizeBytes"] =
                sessionObj.value("size_bytes").isNull()
                    ? -1
                    : static_cast<qint64>(sessionObj.value("size_bytes").toDouble());
            session["chunkCount"] = sessionObj.value("chunk_count").toInt();
            sessions.append(session);
            if (firstSessionStart.isEmpty())
                firstSessionStart = startTime;
        }

        QVariantMap day;
        day["date"] = dayObj.value("date").toString();
        day["sessions"] = sessions;
        day["totalCoverageSecs"] = static_cast<qint64>(dayObj.value("coverage_seconds").toDouble());
        day["firstSessionStart"] = firstSessionStart;
        days.append(day);
    }

    // Backend returns oldest-first; the panel lists days newest-at-top.
    std::reverse(days.begin(), days.end());
    return days;
}

void RecordingModel::insertTestChunk(const QString& startTime, const QString& endTime,
                                     qint64 sizeBytes) {
    RecordingDto chunk;
    chunk.id = QString("test-chunk-%1").arg(m_recordings.size());
    chunk.chunkIndex = m_recordings.size();
    chunk.startTime = startTime;
    chunk.endTime = endTime;
    chunk.sizeBytes = sizeBytes;
    beginInsertRows({}, m_recordings.size(), m_recordings.size());
    m_recordings.append(chunk);
    endInsertRows();
}

void RecordingModel::clearTestChunks() {
    beginResetModel();
    m_recordings.clear();
    endResetModel();
}

RecordingDto RecordingModel::fromJson(const QJsonObject& obj) {
    RecordingDto r;
    r.id = obj["id"].toString();
    r.chunkIndex = obj["chunk_index"].toInt();
    r.startTime = obj["start_time"].toString();
    r.endTime = obj["end_time"].toString();
    r.sizeBytes =
        obj["size_bytes"].isNull() ? -1 : static_cast<qint64>(obj["size_bytes"].toDouble());
    r.codec = obj["codec"].toString();
    return r;
}

void RecordingModel::setLoading(bool v) {
    if (m_loading == v)
        return;
    m_loading = v;
    emit loadingChanged();
}
