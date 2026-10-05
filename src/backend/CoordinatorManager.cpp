// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "CoordinatorManager.h"
#include "AppDatabase.h"
#include "CoordinatorClient.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

namespace {
const QString kPreferenceKey = QStringLiteral("coordinator.connections");
}

CoordinatorManager::CoordinatorManager(AppDatabase* db, QObject* parent)
    : QAbstractListModel(parent), m_db(db) {
    const auto doc = QJsonDocument::fromJson(m_db->preference(kPreferenceKey, "[]").toUtf8());
    if (!doc.isArray())
        return;
    for (const auto& v : doc.array()) {
        const auto obj = v.toObject();
        m_connections.append({obj.value("coordinator_url").toString(),
                              obj.value("access_token").toString(),
                              obj.value("refresh_token").toString(),
                              obj.value("username").toString()});
        createClient(m_connections.last().url);
    }
}

int CoordinatorManager::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : m_connections.size();
}

QVariant CoordinatorManager::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_connections.size())
        return {};
    const auto& conn = m_connections.at(index.row());
    switch (role) {
    case UrlRole:
        return conn.url;
    case HasSessionRole:
        return !conn.accessToken.isEmpty();
    default:
        return {};
    }
}

QHash<int, QByteArray> CoordinatorManager::roleNames() const {
    return {
        {UrlRole, "url"},
        {HasSessionRole, "hasSession"},
    };
}

void CoordinatorManager::addConnection(const QString& url) {
    if (indexOfUrl(url) >= 0)
        return;
    // Create the client before endInsertRows() fires, since QML instantiates
    // the new delegate synchronously and reads clientFor(url) immediately.
    // It's a plain invokable with no NOTIFY, so a null result here would
    // never be re-evaluated later.
    createClient(url);
    beginInsertRows({}, m_connections.size(), m_connections.size());
    m_connections.append({url, {}, {}, {}});
    endInsertRows();
    save();
    emit countChanged();
    // hasUnsignedConnection's NOTIFY: a newly-added connection has no
    // session yet, so this can flip it from false to true.
    emit sessionsChanged();
}

void CoordinatorManager::removeConnection(const QString& url) {
    const int i = indexOfUrl(url);
    if (i < 0)
        return;
    delete m_clients.take(url);
    beginRemoveRows({}, i, i);
    m_connections.removeAt(i);
    endRemoveRows();
    save();
    emit countChanged();
    // hasUnsignedConnection's NOTIFY: removing the only unsigned connection
    // can flip it from true to false.
    emit sessionsChanged();
}

void CoordinatorManager::setSession(const QString& url, const QString& accessToken,
                                    const QString& refreshToken, const QString& username) {
    const int i = indexOfUrl(url);
    if (i < 0)
        return;
    const bool hadSession = !m_connections[i].accessToken.isEmpty();
    m_connections[i].accessToken = accessToken;
    m_connections[i].refreshToken = refreshToken;
    m_connections[i].username = username;
    save();
    const auto idx = index(i);
    emit dataChanged(idx, idx, {HasSessionRole});
    // Only fire sessionsChanged when hasSession actually flips, not on every
    // silent token auto-refresh (CoordinatorClient::refreshAccessToken).
    // SiteManager rebuilds every site's client on this signal, which would
    // otherwise happen on a timer for no reason.
    const bool hasSessionNow = !accessToken.isEmpty();
    if (hadSession != hasSessionNow)
        emit sessionsChanged();
}

void CoordinatorManager::logout(const QString& url) {
    if (auto* client = m_clients.value(url))
        client->logout();
}

bool CoordinatorManager::hasSession(const QString& url) const {
    const int i = indexOfUrl(url);
    return i >= 0 && !m_connections.at(i).accessToken.isEmpty();
}

QString CoordinatorManager::accessToken(const QString& url) const {
    const int i = indexOfUrl(url);
    return i >= 0 ? m_connections.at(i).accessToken : QString{};
}

QString CoordinatorManager::username(const QString& url) const {
    const int i = indexOfUrl(url);
    return i >= 0 ? m_connections.at(i).username : QString{};
}

CoordinatorClient* CoordinatorManager::clientFor(const QString& url) const {
    return m_clients.value(url);
}

QStringList CoordinatorManager::urls() const {
    QStringList result;
    result.reserve(m_connections.size());
    for (const auto& conn : m_connections)
        result.append(conn.url);
    return result;
}

QString CoordinatorManager::refreshToken(const QString& url) const {
    const int i = indexOfUrl(url);
    return i >= 0 ? m_connections.at(i).refreshToken : QString{};
}

void CoordinatorManager::save() const {
    QJsonArray arr;
    for (const auto& conn : m_connections) {
        arr.append(QJsonObject{
            {"coordinator_url", conn.url},
            {"access_token", conn.accessToken},
            {"refresh_token", conn.refreshToken},
            {"username", conn.username},
        });
    }
    m_db->setPreference(kPreferenceKey, QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

int CoordinatorManager::indexOfUrl(const QString& url) const {
    for (int i = 0; i < m_connections.size(); ++i)
        if (m_connections.at(i).url == url)
            return i;
    return -1;
}

CoordinatorClient* CoordinatorManager::createClient(const QString& url) {
    auto* client = new CoordinatorClient(QUrl(url), this);
    m_clients.insert(url, client);

    const int i = indexOfUrl(url);
    if (i >= 0 && !m_connections.at(i).accessToken.isEmpty()) {
        client->restoreSession(m_connections.at(i).username, m_connections.at(i).accessToken,
                               m_connections.at(i).refreshToken);
    }
    connect(client, &CoordinatorClient::sessionChanged, this, [this, url, client] {
        setSession(url, client->accessToken(), client->refreshToken(), client->username());
    });
    return client;
}
