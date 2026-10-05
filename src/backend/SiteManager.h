// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include "ApiTypes.h"
#include "BackendClient.h"
#include <QAbstractListModel>
#include <QHash>
#include <QJsonObject>
#include <QList>
#include <QString>
#include <QTimer>

class AppDatabase;
class CoordinatorManager;
class CoordinatorClient;

struct NodeEntry {
    QString id;
    QString url;
};

struct SiteEntry {
    QString id;
    QString name;
    QList<NodeEntry> nodes;
    // Empty for a locally-configured site. Non-empty names the
    // Coordinator connection URL this site's GET /me/sites answer came
    // from, once at least one Coordinator connection is configured.
    QString coordinatorUrl;
};

class SiteManager : public QAbstractListModel {
    Q_OBJECT

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(
        int activeSiteIndex READ activeSiteIndex WRITE setActiveSiteIndex NOTIFY activeSiteChanged)
    Q_PROPERTY(QString activeSiteId READ activeSiteId NOTIFY activeSiteChanged)
    Q_PROPERTY(QString activeSiteName READ activeSiteName NOTIFY activeSiteChanged)
    Q_PROPERTY(int activeSiteStatus READ activeSiteStatus NOTIFY activeSiteChanged)
    Q_PROPERTY(QString activeSiteVersion READ activeSiteVersion NOTIFY activeSiteChanged)
    Q_PROPERTY(
        QString activeSiteCoordinatorUrl READ activeSiteCoordinatorUrl NOTIFY activeSiteChanged)

  public:
    enum Role {
        SiteIdRole = Qt::UserRole + 1,
        SiteNameRole,
        SiteNodeCountRole,
        SiteWorstStatusRole, // int cast of BackendClient::Status
        SitePrimaryUrlRole,
        SiteVersionRole,
        SiteCoordinatorUrlRole,
    };
    Q_ENUM(Role)

    explicit SiteManager(AppDatabase* db, CoordinatorManager* coordinatorManager,
                         QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int activeSiteIndex() const { return m_activeSiteIndex; }
    void setActiveSiteIndex(int i);
    QString activeSiteId() const;
    QString activeSiteName() const;
    int activeSiteStatus() const;
    QString activeSiteVersion() const;
    QString activeSiteCoordinatorUrl() const; // empty for a local site

    Q_INVOKABLE QString addSite(const QString& name); // returns new site ID
    Q_INVOKABLE void removeSite(const QString& siteId);
    Q_INVOKABLE void addNode(const QString& siteId, const QString& url);
    Q_INVOKABLE void removeNode(const QString& nodeId);
    Q_INVOKABLE void checkHealth(const QString& siteId);
    Q_INVOKABLE void testConnection(const QString& url);
    Q_INVOKABLE int siteIndexById(const QString& siteId) const;

    Q_INVOKABLE BackendClient* clientForNode(const QString& nodeId) const;
    Q_INVOKABLE BackendClient* clientForSite(const QString& siteId) const;

    // Re-fetches GET /me/sites from every Coordinator connection and
    // rebuilds the list as their union (no-op in local mode). Runs
    // automatically on any connection change; callable directly too.
    Q_INVOKABLE void refreshCoordinatorSites();

    // Test-only: injects one remote site as if GET /me/sites had just
    // returned it, bypassing the network round trip. coordinatorUrl must
    // already be a connection CoordinatorManager knows about.
    Q_INVOKABLE void seedRemoteSiteForTest(const QString& coordinatorUrl, const QString& beId,
                                           const QString& name, const QString& beUrl);

    // Test-only: clears every seeded/fetched remote site and rebuilds the
    // (now empty) Coordinator site list. No effect in local mode.
    Q_INVOKABLE void clearRemoteSitesForTest();

    // Test-only: how many times refreshCoordinatorSites() has actually run,
    // including failed attempts. It's the only way to observe
    // wireCoordinatorSessionRetries() retrying.
    Q_INVOKABLE int coordinatorRefreshAttemptCountForTest() const {
        return m_coordinatorRefreshAttemptCount;
    }

  signals:
    void countChanged();
    void activeSiteChanged();
    void testConnectionResult(bool success, const QString& version);

  private:
    // coordinatorUrl empty (default) means a local site, with its session
    // restored from/persisted to AppDatabase. Non-empty
    // means this site's session comes from that Coordinator connection's
    // token endpoint instead (see requestCoordinatorSiteToken()).
    BackendClient* createClient(const QString& nodeId, const QString& url, const QString& siteId,
                                const QString& coordinatorUrl = {});
    void requestCoordinatorSiteToken(const QString& coordinatorUrl, const QString& beId,
                                     BackendClient::SessionResultCallback done);
    BackendClient::Status worstStatus(const SiteEntry& site) const;
    static RemoteSiteDto fromJson(const QJsonObject& obj, const QString& coordinatorUrl);

    void loadLocalSites();
    void clearSitesAndClients();
    void applyRemoteSites(const QString& coordinatorUrl, const QList<RemoteSiteDto>& sites);
    void rebuildVisibleSitesFromRemote();
    void rebuildForModeChange();
    // Connects each Coordinator connection's sessionChanged (including a
    // silent background token refresh, unlike CoordinatorManager::sessionsChanged)
    // to retry refreshCoordinatorSites(). Qt::UniqueConnection guards repeat
    // calls against double-wiring an already-connected client.
    void wireCoordinatorSessionRetries();

    AppDatabase* m_db;
    CoordinatorManager* m_coordinatorManager;
    QList<SiteEntry> m_sites;
    QHash<QString, BackendClient*> m_clients; // nodeId → client (owned)
    QHash<QString, QList<RemoteSiteDto>> m_remoteSitesByConnection; // coordinatorUrl → its sites
    BackendClient* m_testClient = nullptr;
    int m_activeSiteIndex = 0;
    // Retries GET /me/sites on a timer, but only while the visible site list
    // is still empty (see the constructor for why). Otherwise a Coordinator
    // that isn't reachable yet at FE startup leaves the site list empty
    // forever, since refreshCoordinatorSites() itself never retries a failed
    // request on its own.
    QTimer m_coordinatorRefreshTimer;
    int m_coordinatorRefreshAttemptCount = 0;
};
