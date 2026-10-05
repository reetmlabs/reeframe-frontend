// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "SiteManager.h"
#include "AppDatabase.h"
#include "CoordinatorClient.h"
#include "CoordinatorManager.h"
#include <QDateTime>
#include <QJsonArray>
#include <QRestReply>
#include <QSet>
#include <QUuid>
#include <iterator>

// Matches BackendClient's own health-poll interval, for the same reason: light
// enough for a timer that runs for the app's whole lifetime, fast enough that
// picking up a Coordinator that comes up late is imperceptibly different from
// instant.
constexpr int kCoordinatorRefreshIntervalMs = 5000;

SiteManager::SiteManager(AppDatabase* db, CoordinatorManager* coordinatorManager, QObject* parent)
    : QAbstractListModel(parent), m_db(db), m_coordinatorManager(coordinatorManager) {
    connect(this, &QAbstractListModel::rowsInserted, this, &SiteManager::countChanged);
    connect(this, &QAbstractListModel::rowsRemoved, this, &SiteManager::countChanged);
    connect(m_coordinatorManager, &CoordinatorManager::countChanged, this,
            &SiteManager::rebuildForModeChange);
    // A session change (sign-in or sign-out) needs the same rebuild: a fresh
    // GET /me/sites, or pruning a signed-out connection's sites from the
    // dropdown/menus.
    connect(m_coordinatorManager, &CoordinatorManager::sessionsChanged, this,
            &SiteManager::rebuildForModeChange);

    if (m_coordinatorManager->isCoordinatorMode()) {
        refreshCoordinatorSites();
        wireCoordinatorSessionRetries();
    } else {
        loadLocalSites();
    }

    // Retries GET /me/sites on a timer, but only while the visible list is
    // still empty. Once a site has landed, rebuilding every client on each
    // tick would just be wasted work and flicker every status dot. No-op in
    // local mode, where refreshCoordinatorSites() early-returns.
    m_coordinatorRefreshTimer.setInterval(kCoordinatorRefreshIntervalMs);
    connect(&m_coordinatorRefreshTimer, &QTimer::timeout, this, [this] {
        if (m_sites.isEmpty())
            refreshCoordinatorSites();
    });
    m_coordinatorRefreshTimer.start();
}

void SiteManager::loadLocalSites() {
    for (const auto& sr : m_db->loadSites()) {
        SiteEntry site{sr.id, sr.name, {}};
        for (const auto& nr : m_db->loadNodes(sr.id)) {
            site.nodes.append({nr.id, nr.url});
            createClient(nr.id, nr.url, sr.id)->checkHealth();
        }
        m_sites.append(std::move(site));
    }
}

int SiteManager::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : m_sites.size();
}

QVariant SiteManager::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_sites.size())
        return {};
    const auto& site = m_sites.at(index.row());
    switch (role) {
    case SiteIdRole:
        return site.id;
    case SiteNameRole:
        return site.name;
    case SiteNodeCountRole:
        return site.nodes.size();
    case SiteWorstStatusRole:
        return static_cast<int>(worstStatus(site));
    case SitePrimaryUrlRole:
        return site.nodes.isEmpty() ? QString{} : site.nodes.first().url;
    case SiteVersionRole: {
        if (site.nodes.isEmpty())
            return QString{};
        const auto* client = m_clients.value(site.nodes.first().id);
        return client ? client->version() : QString{};
    }
    case SiteCoordinatorUrlRole:
        return site.coordinatorUrl;
    default:
        return {};
    }
}

QHash<int, QByteArray> SiteManager::roleNames() const {
    return {
        {SiteIdRole, "siteId"},
        {SiteNameRole, "siteName"},
        {SiteNodeCountRole, "siteNodeCount"},
        {SiteWorstStatusRole, "siteWorstStatus"},
        {SitePrimaryUrlRole, "sitePrimaryUrl"},
        {SiteVersionRole, "siteVersion"},
        {SiteCoordinatorUrlRole, "siteCoordinatorUrl"},
    };
}

void SiteManager::setActiveSiteIndex(int i) {
    if (i == m_activeSiteIndex || i < 0 || i >= m_sites.size())
        return;
    m_activeSiteIndex = i;
    emit activeSiteChanged();
}

QString SiteManager::activeSiteId() const {
    if (m_activeSiteIndex < 0 || m_activeSiteIndex >= m_sites.size())
        return {};
    return m_sites.at(m_activeSiteIndex).id;
}

QString SiteManager::activeSiteName() const {
    if (m_activeSiteIndex < 0 || m_activeSiteIndex >= m_sites.size())
        return {};
    return m_sites.at(m_activeSiteIndex).name;
}

int SiteManager::activeSiteStatus() const {
    if (m_activeSiteIndex < 0 || m_activeSiteIndex >= m_sites.size())
        return static_cast<int>(BackendClient::Status::Disconnected);
    return static_cast<int>(worstStatus(m_sites.at(m_activeSiteIndex)));
}

QString SiteManager::activeSiteVersion() const {
    if (m_activeSiteIndex < 0 || m_activeSiteIndex >= m_sites.size())
        return {};
    const auto& site = m_sites.at(m_activeSiteIndex);
    if (site.nodes.isEmpty())
        return {};
    const auto* client = m_clients.value(site.nodes.first().id);
    return client ? client->version() : QString{};
}

QString SiteManager::activeSiteCoordinatorUrl() const {
    if (m_activeSiteIndex < 0 || m_activeSiteIndex >= m_sites.size())
        return {};
    return m_sites.at(m_activeSiteIndex).coordinatorUrl;
}

QString SiteManager::addSite(const QString& name) {
    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_db->insertSite(id, name, QDateTime::currentSecsSinceEpoch());
    beginInsertRows({}, m_sites.size(), m_sites.size());
    m_sites.append({id, name, {}});
    endInsertRows();
    if (m_sites.size() == 1)
        emit activeSiteChanged();
    return id;
}

void SiteManager::removeSite(const QString& siteId) {
    const int i = siteIndexById(siteId);
    if (i < 0)
        return;
    for (const auto& node : m_sites.at(i).nodes)
        delete m_clients.take(node.id);
    m_db->deleteSite(siteId);
    beginRemoveRows({}, i, i);
    m_sites.removeAt(i);
    endRemoveRows();
    // qBound(0, x, m_sites.size() - 1) would violate its min <= max
    // precondition once the last site is removed (size() - 1 == -1); 0 is a
    // safe placeholder since an out-of-range index already means "no active
    // site" elsewhere.
    const int newIndex = m_sites.isEmpty() ? 0 : qBound(0, m_activeSiteIndex, m_sites.size() - 1);
    if (newIndex != m_activeSiteIndex || i <= m_activeSiteIndex)
        m_activeSiteIndex = newIndex;
    emit activeSiteChanged();
}

void SiteManager::addNode(const QString& siteId, const QString& url) {
    const int i = siteIndexById(siteId);
    if (i < 0)
        return;
    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_db->insertNode(id, siteId, url, QDateTime::currentSecsSinceEpoch());
    m_sites[i].nodes.append({id, url});
    createClient(id, url, siteId)->checkHealth();
    const auto idx = index(i);
    emit dataChanged(idx, idx, {SiteNodeCountRole, SiteWorstStatusRole, SitePrimaryUrlRole});
    if (i == m_activeSiteIndex)
        emit activeSiteChanged();
}

void SiteManager::removeNode(const QString& nodeId) {
    for (int i = 0; i < m_sites.size(); ++i) {
        auto& nodes = m_sites[i].nodes;
        for (int j = 0; j < nodes.size(); ++j) {
            if (nodes.at(j).id != nodeId)
                continue;
            delete m_clients.take(nodeId);
            m_db->deleteNode(nodeId);
            nodes.removeAt(j);
            const auto idx = index(i);
            emit dataChanged(idx, idx,
                             {SiteNodeCountRole, SiteWorstStatusRole, SitePrimaryUrlRole});
            if (i == m_activeSiteIndex)
                emit activeSiteChanged();
            return;
        }
    }
}

void SiteManager::checkHealth(const QString& siteId) {
    const int i = siteIndexById(siteId);
    if (i < 0)
        return;
    for (const auto& node : m_sites.at(i).nodes) {
        if (auto* client = m_clients.value(node.id))
            client->checkHealth();
    }
}

void SiteManager::testConnection(const QString& url) {
    delete m_testClient;
    m_testClient = new BackendClient("_test", QUrl(url), this);
    connect(m_testClient, &BackendClient::statusChanged, this, [this] {
        if (m_testClient->status() == BackendClient::Status::Connecting)
            return;
        const bool ok = m_testClient->status() == BackendClient::Status::Online;
        emit testConnectionResult(ok, m_testClient->version());
        m_testClient->deleteLater();
        m_testClient = nullptr;
    });
    m_testClient->checkHealth();
}

BackendClient* SiteManager::clientForNode(const QString& nodeId) const {
    return m_clients.value(nodeId, nullptr);
}

BackendClient* SiteManager::clientForSite(const QString& siteId) const {
    const int i = siteIndexById(siteId);
    if (i < 0 || m_sites.at(i).nodes.isEmpty())
        return nullptr;
    return m_clients.value(m_sites.at(i).nodes.first().id, nullptr);
}

BackendClient* SiteManager::createClient(const QString& nodeId, const QString& url,
                                         const QString& siteId, const QString& coordinatorUrl) {
    auto* client = new BackendClient(nodeId, QUrl(url), this);
    m_clients.insert(nodeId, client);

    if (coordinatorUrl.isEmpty()) {
        // Each node manages its own user database (see BackendClient::signIn's
        // per-node setup/login), so a session is persisted and restored per
        // node, not per site.
        const QString accessToken = m_db->preference("auth." + nodeId + ".access_token");
        if (!accessToken.isEmpty()) {
            client->restoreSession(m_db->preference("auth." + nodeId + ".username"), accessToken,
                                   m_db->preference("auth." + nodeId + ".refresh_token"));
        }
        connect(client, &BackendClient::sessionChanged, this, [this, nodeId, client] {
            m_db->setPreference("auth." + nodeId + ".username", client->username());
            m_db->setPreference("auth." + nodeId + ".access_token", client->accessToken());
            m_db->setPreference("auth." + nodeId + ".refresh_token", client->refreshToken());
        });
    } else {
        // Coordinator mode: this site's session is a Coordinator-issued, site-scoped
        // token, never this BE's own local login. nodeId is the be_id
        // Coordinator knows it by.
        const QString beId = nodeId;
        client->setCoordinatorTokenProvider([this, coordinatorUrl, beId](auto done) {
            requestCoordinatorSiteToken(coordinatorUrl, beId, std::move(done));
        });
        client->requestCoordinatorToken();
    }

    connect(client, &BackendClient::statusChanged, this, [this, siteId] {
        const int i = siteIndexById(siteId);
        if (i < 0)
            return;
        const auto idx = index(i);
        emit dataChanged(idx, idx, {SiteWorstStatusRole});
        if (i == m_activeSiteIndex)
            emit activeSiteChanged();
    });

    connect(client, &BackendClient::versionChanged, this, [this, siteId] {
        const int i = siteIndexById(siteId);
        if (i < 0)
            return;
        const auto idx = index(i);
        emit dataChanged(idx, idx, {SiteVersionRole});
        if (i == m_activeSiteIndex)
            emit activeSiteChanged();
    });

    return client;
}

int SiteManager::siteIndexById(const QString& siteId) const {
    for (int i = 0; i < m_sites.size(); ++i)
        if (m_sites.at(i).id == siteId)
            return i;
    return -1;
}

BackendClient::Status SiteManager::worstStatus(const SiteEntry& site) const {
    auto result = BackendClient::Status::Disconnected;
    for (const auto& node : site.nodes) {
        const auto* client = m_clients.value(node.id);
        if (!client)
            continue;
        switch (client->status()) {
        case BackendClient::Status::Error:
            return BackendClient::Status::Error;
        case BackendClient::Status::Online:
            result = BackendClient::Status::Online;
            break;
        case BackendClient::Status::Connecting:
            if (result != BackendClient::Status::Online)
                result = BackendClient::Status::Connecting;
            break;
        default:
            break;
        }
    }
    return result;
}

void SiteManager::clearSitesAndClients() {
    for (auto& site : m_sites)
        for (auto& node : site.nodes)
            delete m_clients.take(node.id);
    m_sites.clear();
}

void SiteManager::refreshCoordinatorSites() {
    if (!m_coordinatorManager->isCoordinatorMode())
        return;
    ++m_coordinatorRefreshAttemptCount;

    const int n = m_coordinatorManager->rowCount();
    for (int i = 0; i < n; ++i) {
        const QString url =
            m_coordinatorManager->data(m_coordinatorManager->index(i), CoordinatorManager::UrlRole)
                .toString();
        auto* client = m_coordinatorManager->clientFor(url);
        if (!client)
            continue;

        client->get("/me/sites", this, [this, url](QRestReply& reply) {
            if (!reply.isSuccess())
                return;
            const auto doc = reply.readJson();
            QList<RemoteSiteDto> parsed;
            if (doc && doc->isArray()) {
                for (const auto& v : doc->array())
                    parsed.append(fromJson(v.toObject(), url));
            }
            applyRemoteSites(url, parsed);
        });
    }
}

void SiteManager::wireCoordinatorSessionRetries() {
    if (!m_coordinatorManager->isCoordinatorMode())
        return;
    for (int i = 0; i < m_coordinatorManager->rowCount(); ++i) {
        const QString url =
            m_coordinatorManager->data(m_coordinatorManager->index(i), CoordinatorManager::UrlRole)
                .toString();
        if (auto* client = m_coordinatorManager->clientFor(url)) {
            connect(client, &CoordinatorClient::sessionChanged, this,
                    &SiteManager::refreshCoordinatorSites, Qt::UniqueConnection);
        }
    }
}

// aud-scoped tokens have no separate refresh of their own. This is called
// again, in full, whenever BackendClient's own expiry timer decides it's
// time to renew (see BackendClient::refreshAccessToken).
void SiteManager::requestCoordinatorSiteToken(const QString& coordinatorUrl, const QString& beId,
                                              BackendClient::SessionResultCallback done) {
    auto* client = m_coordinatorManager->clientFor(coordinatorUrl);
    if (!client) {
        done(false, {}, {}, {});
        return;
    }
    client->post("/me/sites/" + beId + "/token", {}, this, [done](QRestReply& reply) {
        if (!reply.isSuccess()) {
            done(false, {}, {}, {});
            return;
        }
        const auto doc = reply.readJson();
        if (!doc || !doc->isObject()) {
            done(false, {}, {}, {});
            return;
        }
        const auto obj = doc->object();
        const auto userObj = obj.value("user").toObject();
        done(true, obj.value("access_token").toString(), userObj.value("username").toString(),
             userObj.value("role").toString());
    });
}

void SiteManager::seedRemoteSiteForTest(const QString& coordinatorUrl, const QString& beId,
                                        const QString& name, const QString& beUrl) {
    auto sites = m_remoteSitesByConnection.value(coordinatorUrl);
    sites.append({beId, name, beUrl, coordinatorUrl});
    applyRemoteSites(coordinatorUrl, sites);
}

void SiteManager::clearRemoteSitesForTest() {
    m_remoteSitesByConnection.clear();
    // Only rebuild the visible list from it in Coordinator mode. In local
    // mode the visible list is local sites, and rebuildVisibleSitesFromRemote()
    // would otherwise wipe them from the in-memory model (though not from
    // AppDatabase) for no reason.
    if (m_coordinatorManager->isCoordinatorMode())
        rebuildVisibleSitesFromRemote();
}

void SiteManager::applyRemoteSites(const QString& coordinatorUrl,
                                   const QList<RemoteSiteDto>& sites) {
    m_remoteSitesByConnection.insert(coordinatorUrl, sites);
    rebuildVisibleSitesFromRemote();
}

// Rebuilds the whole visible list from the union of every connection's
// last-known answer each time any one of them changes, rather than trying
// to patch the model incrementally. Connections are few and this runs
// only on a Coordinator response, never on a hot path.
void SiteManager::rebuildVisibleSitesFromRemote() {
    beginResetModel();
    clearSitesAndClients();
    for (auto it = m_remoteSitesByConnection.constBegin();
         it != m_remoteSitesByConnection.constEnd(); ++it) {
        for (const auto& remote : it.value()) {
            SiteEntry site{
                remote.beId, remote.name, {{remote.beId, remote.beUrl}}, remote.coordinatorUrl};
            m_sites.append(std::move(site));
            createClient(remote.beId, remote.beUrl, remote.beId, remote.coordinatorUrl)
                ->checkHealth();
        }
    }
    endResetModel();
    m_activeSiteIndex = 0;
    emit countChanged();
    emit activeSiteChanged();
}

// Prunes any connection that's removed or has lost its session (signed
// out) from the remote-sites cache, so its sites stop showing in the
// dropdown/menus as if still reachable. Falls back to local AppDatabase
// sites only once no connection remains.
void SiteManager::rebuildForModeChange() {
    QSet<QString> liveSignedInUrls;
    for (int i = 0; i < m_coordinatorManager->rowCount(); ++i) {
        const QString url =
            m_coordinatorManager->data(m_coordinatorManager->index(i), CoordinatorManager::UrlRole)
                .toString();
        if (m_coordinatorManager->hasSession(url))
            liveSignedInUrls.insert(url);
    }
    for (auto it = m_remoteSitesByConnection.begin(); it != m_remoteSitesByConnection.end();) {
        it = liveSignedInUrls.contains(it.key()) ? std::next(it)
                                                 : m_remoteSitesByConnection.erase(it);
    }

    if (m_coordinatorManager->isCoordinatorMode()) {
        rebuildVisibleSitesFromRemote();
        refreshCoordinatorSites();
        wireCoordinatorSessionRetries();
        return;
    }

    beginResetModel();
    clearSitesAndClients();
    m_remoteSitesByConnection.clear();
    loadLocalSites();
    endResetModel();
    m_activeSiteIndex = 0;
    emit countChanged();
    emit activeSiteChanged();
}

RemoteSiteDto SiteManager::fromJson(const QJsonObject& obj, const QString& coordinatorUrl) {
    return {obj.value("be_id").toString(), obj.value("name").toString(),
            obj.value("be_url").toString(), coordinatorUrl};
}
