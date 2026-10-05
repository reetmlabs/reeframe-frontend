// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "RunModel.h"
#include "SiteManager.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRestReply>

// "output" on the wire is the node's full NodeOutput object (artifact_path,
// text, metadata, ...), not a display string, so pick whichever field a human
// would actually want to read.
static QString summarizeNodeOutput(const QJsonObject& output) {
    const QString text = output["text"].toString();
    if (!text.isEmpty())
        return text;
    const QString artifact = output["artifact_path"].toString();
    if (!artifact.isEmpty())
        return QStringLiteral("Artifact: %1").arg(artifact);
    return {};
}

RunModel::RunModel(SiteManager* siteManager, QObject* parent)
    : QAbstractListModel(parent), m_siteManager(siteManager) {
    m_pollTimer.setInterval(2000);
    connect(&m_pollTimer, &QTimer::timeout, this, [this] {
        if (!m_pollingPipelineId.isEmpty())
            refresh(m_pollingPipelineId);
    });
    connect(this, &QAbstractItemModel::rowsInserted, this, &RunModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &RunModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &RunModel::countChanged);
}

int RunModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : m_runs.size();
}

QVariant RunModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_runs.size())
        return {};
    const auto& r = m_runs.at(index.row());
    switch (role) {
    case RunIdRole:
        return r.id;
    case RunStatusRole:
        return r.status;
    case RunTriggerTypeRole:
        return r.triggerType;
    case RunTriggeredAtRole:
        return r.triggeredAt;
    case RunCompletedAtRole:
        return r.completedAt;
    case RunErrorRole:
        return r.error;
    default:
        return {};
    }
}

QHash<int, QByteArray> RunModel::roleNames() const {
    return {
        {RunIdRole, "runId"},
        {RunStatusRole, "runStatus"},
        {RunTriggerTypeRole, "runTriggerType"},
        {RunTriggeredAtRole, "runTriggeredAt"},
        {RunCompletedAtRole, "runCompletedAt"},
        {RunErrorRole, "runError"},
    };
}

void RunModel::refresh(const QString& pipelineId, int limit) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    m_currentPipelineId = pipelineId;
    setLoading(true);
    const QString nodeId = client->nodeId();
    const QString path = QString("/pipelines/%1/runs?limit=%2").arg(pipelineId).arg(limit);
    client->get(path, this, [this, nodeId](QRestReply& reply) {
        setLoading(false);
        if (!reply.isSuccess())
            return;
        const auto doc = reply.readJson();
        if (!doc || !doc->isArray())
            return;
        QList<RunDto> runs;
        for (const auto& val : doc->array())
            runs.append(fromJson(val.toObject(), nodeId));
        beginResetModel();
        m_runs = std::move(runs);
        endResetModel();
        if (m_pollTimer.isActive() && !hasActiveRuns())
            stopPolling();
    });
}

void RunModel::startPolling(const QString& pipelineId) {
    m_pollingPipelineId = pipelineId;
    refresh(pipelineId);
    m_pollTimer.start();
}

void RunModel::stopPolling() {
    m_pollTimer.stop();
    m_pollingPipelineId.clear();
}

QVariantList RunModel::nodeResultsForRun(const QString& runId) const {
    for (const auto& run : m_runs) {
        if (run.id != runId)
            continue;
        QVariantList result;
        for (const auto& nr : run.nodeResults) {
            QVariantMap map;
            map["nodeId"] = nr.nodeId;
            map["status"] = nr.status;
            map["startedAt"] = nr.startedAt;
            map["completedAt"] = nr.completedAt;
            map["output"] = nr.output;
            map["error"] = nr.error;
            result.append(map);
        }
        return result;
    }
    return {};
}

QVariantMap RunModel::runById(const QString& runId) const {
    for (const auto& r : m_runs) {
        if (r.id != runId)
            continue;
        return {
            {"runId", r.id},
            {"runStatus", r.status},
            {"runTriggerType", r.triggerType},
            {"runTriggeredAt", r.triggeredAt},
            {"runCompletedAt", r.completedAt},
            {"runError", r.error},
        };
    }
    return {};
}

RunDto RunModel::fromJson(const QJsonObject& obj, const QString& nodeId) {
    RunDto r;
    r.id = obj["id"].toString();
    r.pipelineId = obj["pipeline_id"].toString();
    r.status = obj["status"].toString();
    r.triggerType = obj["trigger_type"].toString();
    r.triggeredAt = obj["triggered_at"].toInteger();
    r.completedAt = obj["completed_at"].toInteger();
    r.error = obj["error"].toString();
    r.nodeId = nodeId;
    for (const auto& v : obj["node_results"].toArray())
        r.nodeResults.append(nodeResultFromJson(v.toObject()));
    return r;
}

NodeResultDto RunModel::nodeResultFromJson(const QJsonObject& obj) {
    NodeResultDto nr;
    nr.nodeId = obj["node_id"].toString();
    nr.status = obj["status"].toString();
    nr.startedAt = obj["started_at"].toInteger();
    nr.completedAt = obj["completed_at"].toInteger();
    nr.output = summarizeNodeOutput(obj["output"].toObject());
    nr.error = obj["error"].toString();
    return nr;
}

void RunModel::insertTestRun(const QString& runId, const QString& status,
                              const QString& error, const QVariantList& nodeResults) {
    RunDto r;
    r.id = runId;
    r.status = status;
    r.error = error;
    for (const auto& v : nodeResults) {
        const auto map = v.toMap();
        NodeResultDto nr;
        nr.nodeId = map.value("nodeId").toString();
        nr.status = map.value("status").toString();
        nr.startedAt = map.value("startedAt").toLongLong();
        nr.completedAt = map.value("completedAt").toLongLong();
        nr.output = map.value("output").toString();
        nr.error = map.value("error").toString();
        r.nodeResults.append(nr);
    }
    beginInsertRows({}, m_runs.size(), m_runs.size());
    m_runs.append(r);
    endInsertRows();
}

void RunModel::clearTestRuns() {
    beginResetModel();
    m_runs.clear();
    endResetModel();
}

void RunModel::setLoading(bool v) {
    if (m_loading == v)
        return;
    m_loading = v;
    emit loadingChanged();
}

bool RunModel::hasActiveRuns() const {
    for (const auto& r : m_runs)
        if (r.status == "running" || r.status == "pending")
            return true;
    return false;
}
