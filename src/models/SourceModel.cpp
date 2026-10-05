// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "SourceModel.h"
#include "BackendClient.h"
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

SourceModel::SourceModel(SiteManager* siteManager, QObject* parent)
    : QAbstractListModel(parent), m_siteManager(siteManager) {
    connect(siteManager, &SiteManager::activeSiteChanged, this, &SourceModel::onActiveSiteChanged);
    connect(this, &QAbstractItemModel::rowsInserted, this, &SourceModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &SourceModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &SourceModel::countChanged);
}

void SourceModel::onActiveSiteChanged() {
    QObject::disconnect(m_sessionConnection);
    setLoading(false);
    if (auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId()))
        m_sessionConnection = connect(client, &BackendClient::sessionChanged, this, &SourceModel::refresh);
    refresh();
}

int SourceModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : m_sources.size();
}

QVariant SourceModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_sources.size())
        return {};
    const auto& s = m_sources.at(index.row());
    switch (role) {
    case SourceIdRole:
        return s.id;
    case SourceNameRole:
        return s.name;
    case SourceTypeRole:
        return s.type;
    case SourceEnabledRole:
        return s.enabled;
    default:
        return {};
    }
}

QHash<int, QByteArray> SourceModel::roleNames() const {
    return {
        {SourceIdRole, "sourceId"},
        {SourceNameRole, "sourceName"},
        {SourceTypeRole, "sourceType"},
        {SourceEnabledRole, "sourceEnabled"},
    };
}

void SourceModel::refresh() {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    setLoading(true);
    const QString nodeId = client->nodeId();
    client->get("/sources", this, [this, nodeId](QRestReply& reply) {
        setLoading(false);
        if (!reply.isSuccess())
            return;
        const auto doc = reply.readJson();
        if (!doc || !doc->isArray())
            return;
        QList<SourceDto> sources;
        for (const auto& val : doc->array())
            sources.append(fromJson(val.toObject(), nodeId));
        beginResetModel();
        m_sources = std::move(sources);
        endResetModel();
    });
}

void SourceModel::createSource(const QString& name, const QString& type,
                               const QVariantMap& config) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client) {
        emit createSourceFailed(QStringLiteral("no active site session"));
        return;
    }
    QJsonObject obj;
    obj["name"] = name;
    obj["source_type"] = type;
    obj["config"] = QJsonObject::fromVariantMap(config);
    client->post("/sources", QJsonDocument(obj), this, [this](QRestReply& reply) {
        if (reply.isSuccess()) {
            refresh();
            emit createSourceSucceeded();
        } else {
            emit createSourceFailed(describeFailure(reply));
        }
    });
}

void SourceModel::updateSource(const QString& id, const QString& name, const QString& type,
                               const QVariantMap& config) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client) {
        emit updateSourceFailed(QStringLiteral("no active site session"));
        return;
    }
    QJsonObject obj;
    obj["name"] = name;
    obj["source_type"] = type;
    obj["config"] = QJsonObject::fromVariantMap(config);
    client->patch("/sources/" + id, QJsonDocument(obj), this, [this](QRestReply& reply) {
        if (reply.isSuccess()) {
            refresh();
            emit updateSourceSucceeded();
        } else {
            emit updateSourceFailed(describeFailure(reply));
        }
    });
}

void SourceModel::deleteSource(const QString& id) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    client->del("/sources/" + id, this, [this, id](QRestReply& reply) {
        if (!reply.isSuccess()) {
            emit deleteSourceFailed(id, describeFailure(reply));
            return;
        }
        for (int i = 0; i < m_sources.size(); ++i) {
            if (m_sources.at(i).id == id) {
                beginRemoveRows({}, i, i);
                m_sources.removeAt(i);
                endRemoveRows();
                return;
            }
        }
    });
}

int SourceModel::sourceIndexById(const QString& id) const {
    for (int i = 0; i < m_sources.size(); ++i)
        if (m_sources.at(i).id == id)
            return i;
    return -1;
}

QVariantList SourceModel::searchableEntries() const {
    QVariantList out;
    out.reserve(m_sources.size());
    for (const auto& s : m_sources) {
        out.append(QVariantMap{
            {"id", s.id},
            {"name", s.name},
            {"subtitle", s.type},
        });
    }
    return out;
}

QVariantMap SourceModel::sourceById(const QString& id) const {
    for (const auto& s : m_sources) {
        if (s.id != id)
            continue;
        return {
            {"sourceId", s.id},
            {"sourceName", s.name},
            {"sourceType", s.type},
            {"sourceEnabled", s.enabled},
            {"sourceConfig", s.config},
        };
    }
    return {};
}

void SourceModel::insertTestSource(const QString& id, const QString& name, const QString& type,
                                    const QVariantMap& config) {
    SourceDto s;
    s.id = id;
    s.name = name;
    s.type = type;
    s.enabled = true;
    s.config = config;
    beginInsertRows({}, m_sources.size(), m_sources.size());
    m_sources.append(s);
    endInsertRows();
}

void SourceModel::clearTestSources() {
    beginResetModel();
    m_sources.clear();
    endResetModel();
}

SourceDto SourceModel::fromJson(const QJsonObject& obj, const QString& nodeId) {
    SourceDto s;
    s.id = obj["id"].toString();
    s.name = obj["name"].toString();
    s.type = obj["source_type"].toString();
    s.enabled = obj["enabled"].toBool();
    s.config = obj["config"].toObject().toVariantMap();
    s.nodeId = nodeId;
    return s;
}

void SourceModel::setLoading(bool v) {
    if (m_loading == v)
        return;
    m_loading = v;
    emit loadingChanged();
}
