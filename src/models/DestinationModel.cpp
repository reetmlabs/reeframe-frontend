// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "DestinationModel.h"
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

DestinationModel::DestinationModel(SiteManager* siteManager, QObject* parent)
    : QAbstractListModel(parent), m_siteManager(siteManager) {
    connect(siteManager, &SiteManager::activeSiteChanged, this, &DestinationModel::onActiveSiteChanged);
    connect(this, &QAbstractItemModel::rowsInserted, this, &DestinationModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &DestinationModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &DestinationModel::countChanged);
}

void DestinationModel::onActiveSiteChanged() {
    QObject::disconnect(m_sessionConnection);
    setLoading(false);
    if (auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId()))
        m_sessionConnection = connect(client, &BackendClient::sessionChanged, this, &DestinationModel::refresh);
    refresh();
}

int DestinationModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : m_destinations.size();
}

QVariant DestinationModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_destinations.size())
        return {};
    const auto& d = m_destinations.at(index.row());
    switch (role) {
    case DestIdRole:
        return d.id;
    case DestNameRole:
        return d.name;
    case DestTypeRole:
        return d.type;
    case DestEnabledRole:
        return d.enabled;
    default:
        return {};
    }
}

QHash<int, QByteArray> DestinationModel::roleNames() const {
    return {
        {DestIdRole, "destId"},
        {DestNameRole, "destName"},
        {DestTypeRole, "destType"},
        {DestEnabledRole, "destEnabled"},
    };
}

void DestinationModel::refresh() {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    setLoading(true);
    const QString nodeId = client->nodeId();
    client->get("/destinations", this, [this, nodeId](QRestReply& reply) {
        setLoading(false);
        if (!reply.isSuccess())
            return;
        const auto doc = reply.readJson();
        if (!doc || !doc->isArray())
            return;
        QList<DestinationDto> destinations;
        for (const auto& val : doc->array())
            destinations.append(fromJson(val.toObject(), nodeId));
        beginResetModel();
        m_destinations = std::move(destinations);
        endResetModel();
    });
}

void DestinationModel::createDestination(const QString& name, const QString& type,
                                         const QVariantMap& config) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client) {
        emit createDestinationFailed(QStringLiteral("no active site session"));
        return;
    }
    QJsonObject obj;
    obj["name"] = name;
    obj["dest_type"] = type;
    obj["config"] = QJsonObject::fromVariantMap(config);
    client->post("/destinations", QJsonDocument(obj), this, [this](QRestReply& reply) {
        if (reply.isSuccess()) {
            refresh();
            emit createDestinationSucceeded();
        } else {
            emit createDestinationFailed(describeFailure(reply));
        }
    });
}

void DestinationModel::updateDestination(const QString& id, const QString& name,
                                         const QString& type, const QVariantMap& config) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client) {
        emit updateDestinationFailed(QStringLiteral("no active site session"));
        return;
    }
    QJsonObject obj;
    obj["name"] = name;
    obj["dest_type"] = type;
    obj["config"] = QJsonObject::fromVariantMap(config);
    client->patch("/destinations/" + id, QJsonDocument(obj), this, [this](QRestReply& reply) {
        if (reply.isSuccess()) {
            refresh();
            emit updateDestinationSucceeded();
        } else {
            emit updateDestinationFailed(describeFailure(reply));
        }
    });
}

void DestinationModel::deleteDestination(const QString& id) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    client->del("/destinations/" + id, this, [this, id](QRestReply& reply) {
        if (!reply.isSuccess()) {
            emit deleteDestinationFailed(id, describeFailure(reply));
            return;
        }
        for (int i = 0; i < m_destinations.size(); ++i) {
            if (m_destinations.at(i).id == id) {
                beginRemoveRows({}, i, i);
                m_destinations.removeAt(i);
                endRemoveRows();
                return;
            }
        }
    });
}

QVariantList DestinationModel::searchableEntries() const {
    QVariantList out;
    out.reserve(m_destinations.size());
    for (const auto& d : m_destinations) {
        out.append(QVariantMap{
            {"id", d.id},
            {"name", d.name},
            {"subtitle", d.type},
            {"type", d.type},
        });
    }
    return out;
}

QVariantMap DestinationModel::destinationById(const QString& id) const {
    for (const auto& d : m_destinations) {
        if (d.id != id)
            continue;
        return {
            {"destId", d.id},
            {"destName", d.name},
            {"destType", d.type},
            {"destEnabled", d.enabled},
            {"destConfig", d.config},
        };
    }
    return {};
}

void DestinationModel::insertTestDestination(const QString& id, const QString& name,
                                              const QString& type, const QVariantMap& config) {
    DestinationDto d;
    d.id = id;
    d.name = name;
    d.type = type;
    d.enabled = true;
    d.config = config;
    beginInsertRows({}, m_destinations.size(), m_destinations.size());
    m_destinations.append(d);
    endInsertRows();
}

void DestinationModel::clearTestDestinations() {
    beginResetModel();
    m_destinations.clear();
    endResetModel();
}

DestinationDto DestinationModel::fromJson(const QJsonObject& obj, const QString& nodeId) {
    DestinationDto d;
    d.id = obj["id"].toString();
    d.name = obj["name"].toString();
    d.type = obj["dest_type"].toString();
    d.enabled = obj["enabled"].toBool();
    d.config = obj["config"].toObject().toVariantMap();
    d.nodeId = nodeId;
    return d;
}

void DestinationModel::setLoading(bool v) {
    if (m_loading == v)
        return;
    m_loading = v;
    emit loadingChanged();
}
