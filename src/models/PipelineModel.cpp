// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "PipelineModel.h"
#include "SiteManager.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRestReply>

// reply.errorString() is transport-level only (empty for an ordinary non-2xx
// reply). The real reason lives in the JSON body's "error" field.
static QString describeFailure(QRestReply& reply) {
    const auto doc = reply.readJson();
    const QString message =
        doc && doc->isObject() ? doc->object().value("error").toString() : QString{};
    return QStringLiteral("HTTP %1%2")
        .arg(reply.httpStatus())
        .arg(message.isEmpty() ? QString{} : QStringLiteral(" - ") + message);
}

PipelineModel::PipelineModel(SiteManager* siteManager, QObject* parent)
    : QAbstractListModel(parent), m_siteManager(siteManager) {
    connect(siteManager, &SiteManager::activeSiteChanged, this, &PipelineModel::refresh);
    connect(this, &QAbstractItemModel::rowsInserted, this, &PipelineModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &PipelineModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &PipelineModel::countChanged);
}

int PipelineModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : m_pipelines.size();
}

QVariant PipelineModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_pipelines.size())
        return {};
    const auto& p = m_pipelines.at(index.row());
    switch (role) {
    case PipelineIdRole:
        return p.id;
    case PipelineNameRole:
        return p.name;
    case PipelineDescriptionRole:
        return p.description;
    case PipelineTypeRole:
        return p.type;
    case PipelineEnabledRole:
        return p.enabled;
    case PipelineCreatedAtRole:
        return p.createdAt;
    case PipelineUpdatedAtRole:
        return p.updatedAt;
    case PipelineValidationErrorCountRole:
        return p.validationErrorCount;
    case PipelineValidationWarningCountRole:
        return p.validationWarningCount;
    default:
        return {};
    }
}

QHash<int, QByteArray> PipelineModel::roleNames() const {
    return {
        {PipelineIdRole, "pipelineId"},
        {PipelineNameRole, "pipelineName"},
        {PipelineDescriptionRole, "pipelineDescription"},
        {PipelineTypeRole, "pipelineType"},
        {PipelineEnabledRole, "pipelineEnabled"},
        {PipelineCreatedAtRole, "pipelineCreatedAt"},
        {PipelineUpdatedAtRole, "pipelineUpdatedAt"},
        {PipelineValidationErrorCountRole, "pipelineValidationErrorCount"},
        {PipelineValidationWarningCountRole, "pipelineValidationWarningCount"},
    };
}

void PipelineModel::refresh() {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    setLoading(true);
    const QString nodeId = client->nodeId();
    client->get("/pipelines", this, [this, nodeId](QRestReply& reply) {
        setLoading(false);
        if (!reply.isSuccess())
            return;
        const auto doc = reply.readJson();
        if (!doc || !doc->isArray())
            return;
        QList<PipelineDto> pipelines;
        for (const auto& val : doc->array())
            pipelines.append(fromJson(val.toObject(), nodeId));
        beginResetModel();
        m_pipelines = std::move(pipelines);
        endResetModel();
    });
}

void PipelineModel::createPipeline(const QString& name, const QString& description,
                                   const QString& type) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    QJsonObject obj;
    obj["name"] = name;
    obj["description"] = description;
    obj["pipeline_type"] = type;
    client->post("/pipelines", QJsonDocument(obj), this, [this](QRestReply& reply) {
        if (reply.isSuccess())
            refresh();
    });
}

void PipelineModel::updatePipeline(const QString& id, const QString& name,
                                   const QString& description) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client) {
        emit updatePipelineFailed(QStringLiteral("no active site session"));
        return;
    }
    QJsonObject obj;
    obj["name"] = name;
    obj["description"] = description;
    client->patch("/pipelines/" + id, QJsonDocument(obj), this,
                  [this, id, name, description](QRestReply& reply) {
                      if (reply.isSuccess()) {
                          refresh();
                          emit updatePipelineSucceeded(id, name, description);
                      } else {
                          emit updatePipelineFailed(describeFailure(reply));
                      }
                  });
}

void PipelineModel::deletePipeline(const QString& id) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    client->del("/pipelines/" + id, this, [this, id](QRestReply& reply) {
        if (!reply.isSuccess()) {
            emit deletePipelineFailed(id, describeFailure(reply));
            return;
        }
        const int i = indexById(id);
        if (i < 0)
            return;
        beginRemoveRows({}, i, i);
        m_pipelines.removeAt(i);
        endRemoveRows();
    });
}

void PipelineModel::setEnabled(const QString& id, bool enabled) {
    const int i = indexById(id);
    if (i < 0)
        return;

    // Optimistic update.
    m_pipelines[i].enabled = enabled;
    const auto idx = index(i);
    emit dataChanged(idx, idx, {PipelineEnabledRole});

    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client) {
        emit enableRollback(id, !enabled, QStringLiteral("no active site session"));
        return;
    }

    // Enabling/disabling is its own endpoint, not a PATCH field: the
    // backend's UpdatePipelineBody only carries name/description.
    const QString path = "/pipelines/" + id + (enabled ? "/enable" : "/disable");
    client->post(path, QJsonDocument(QJsonObject{}), this,
                  [this, id, enabled](QRestReply& reply) {
                      if (reply.isSuccess())
                          return;
                      // Roll back on failure.
                      const int j = indexById(id);
                      if (j >= 0) {
                          m_pipelines[j].enabled = !enabled;
                          const auto jdx = index(j);
                          emit dataChanged(jdx, jdx, {PipelineEnabledRole});
                      }
                      emit enableRollback(id, !enabled, describeFailure(reply));
                  });
}

void PipelineModel::triggerPipeline(const QString& id, const QVariantMap& params) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    QJsonObject obj;
    obj["params"] = QJsonObject::fromVariantMap(params);
    client->post("/pipelines/" + id + "/trigger", QJsonDocument(obj), this,
                 [this, id](QRestReply& reply) {
                     if (reply.isSuccess())
                         emit triggered(id);
                 });
}

PipelineDto PipelineModel::fromJson(const QJsonObject& obj, const QString& nodeId) {
    PipelineDto p;
    p.id = obj["id"].toString();
    p.name = obj["name"].toString();
    p.description = obj["description"].toString();
    p.type = obj["pipeline_type"].toString();
    p.enabled = obj["enabled"].toBool();
    p.createdAt = obj["created_at"].toInteger();
    p.updatedAt = obj["updated_at"].toInteger();
    p.validationErrorCount = obj["validation_error_count"].toInt();
    p.validationWarningCount = obj["validation_warning_count"].toInt();
    p.nodeId = nodeId;
    return p;
}

void PipelineModel::setLoading(bool v) {
    if (m_loading == v)
        return;
    m_loading = v;
    emit loadingChanged();
}

int PipelineModel::indexById(const QString& id) const {
    for (int i = 0; i < m_pipelines.size(); ++i)
        if (m_pipelines.at(i).id == id)
            return i;
    return -1;
}

QVariantMap PipelineModel::pipelineById(const QString& id) const {
    const int i = indexById(id);
    if (i < 0)
        return {};
    const auto& p = m_pipelines.at(i);
    return {
        {"pipelineId", p.id},
        {"pipelineName", p.name},
        {"pipelineDescription", p.description},
        {"pipelineType", p.type},
        {"pipelineEnabled", p.enabled},
        {"pipelineCreatedAt", p.createdAt},
        {"pipelineUpdatedAt", p.updatedAt},
        {"pipelineValidationErrorCount", p.validationErrorCount},
        {"pipelineValidationWarningCount", p.validationWarningCount},
    };
}

int PipelineModel::pipelineIndexById(const QString& id) const {
    return indexById(id);
}

QVariantList PipelineModel::searchableEntries() const {
    QVariantList out;
    out.reserve(m_pipelines.size());
    for (const auto& p : m_pipelines) {
        out.append(QVariantMap{
            {"id", p.id},
            {"name", p.name},
            {"subtitle", p.type},
        });
    }
    return out;
}

void PipelineModel::insertTestPipeline(const QString& id, const QString& name,
                                        int validationErrorCount, int validationWarningCount) {
    PipelineDto p;
    p.id = id;
    p.name = name;
    p.enabled = true;
    p.validationErrorCount = validationErrorCount;
    p.validationWarningCount = validationWarningCount;
    beginInsertRows({}, m_pipelines.size(), m_pipelines.size());
    m_pipelines.append(p);
    endInsertRows();
}

void PipelineModel::clearTestPipelines() {
    beginResetModel();
    m_pipelines.clear();
    endResetModel();
}
