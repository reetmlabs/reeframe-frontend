// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QList>
#include <QString>
#include <QVariantMap>

struct CameraDto {
    QString id;
    QString name;
    QString location;
    QString rtspUrl;
    QString subRtspUrl;
    QString username;
    bool enabled = false;
    // Whether a recording (disk-writing) branch is attached, independent of
    // whether a live view relay is running (see relayUrl/mainRelayUrl below).
    bool recording = false;
    QString relayUrl; // sub-quality relay URL, used by matrix tiles
    QString mainRelayUrl; // main-quality relay URL, used by full-screen view
    qint64 createdAt = 0;
    QString nodeId;
};

struct SourceDto {
    QString id;
    QString name;
    QString type;
    bool enabled = false;
    // As returned by GET. Credential fields are masked as "***", never the
    // real value. Safe to show back to the user, never safe to resubmit.
    QVariantMap config;
    QString nodeId;
};

struct DestinationDto {
    QString id;
    QString name;
    QString type;
    bool enabled = false;
    // As returned by GET. Credential fields are masked as "***", never the
    // real value. Safe to show back to the user, never safe to resubmit.
    QVariantMap config;
    QString nodeId;
};

struct PipelineDto {
    QString id;
    QString name;
    QString description;
    QString type;
    bool enabled = false;
    qint64 createdAt = 0;
    qint64 updatedAt = 0;
    int validationErrorCount = 0;
    int validationWarningCount = 0;
    QString nodeId;
};

struct NodeResultDto {
    QString nodeId;
    QString status;
    qint64 startedAt = 0;
    qint64 completedAt = 0;
    QString output;
    QString error;
};

struct PipelineNodeDto {
    QString id;
    QString type;
    QString label;
    QVariantMap config;
    double x = 0.0;
    double y = 0.0;
    // Whether this node has a corresponding row on the backend yet. False
    // for a node added locally since the last load()/save(), which needs a
    // POST rather than a PATCH on the next save().
    bool persisted = false;
};

struct PipelineEdgeDto {
    QString id;
    QString fromNodeId;
    QString toNodeId;
    QString edgeType;
    bool persisted = false;
};

struct RunDto {
    QString id;
    QString pipelineId;
    QString status; // "pending" | "running" | "completed" | "failed" | "cancelled"
    QString triggerType; // "manual" | "scheduled" | "event"
    qint64 triggeredAt = 0;
    qint64 completedAt = 0;
    QString error;
    QList<NodeResultDto> nodeResults;
    QString nodeId;
};

// A site as reported by a Coordinator connection's GET /me/sites, tagged
// with which connection it came from, since Coordinator mode's site list is the union
// of every configured Coordinator's own answer.
struct RemoteSiteDto {
    QString beId;
    QString name;
    QString beUrl;
    QString coordinatorUrl;
};

struct RecordingDto {
    QString id;
    int chunkIndex = 0;
    QString startTime; // RFC 3339
    QString endTime; // RFC 3339; empty if the chunk is still being written
    qint64 sizeBytes = -1; // -1 if not yet known (still-open chunk)
    QString codec;
};
