// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QAbstractListModel>
#include <QHash>
#include <QList>
#include <QString>
#include <QStringList>

class AppDatabase;
class CoordinatorClient;

struct CoordinatorConnection {
    QString url;
    QString accessToken;
    QString refreshToken;
    QString username;
};

// A person can hold connections to multiple, independent Coordinator
// instances at once, each with its own identity and session. An empty
// connection list means no Coordinator is configured (single-site, default
// behavior); one or more entries enables multi-site routing through
// Coordinator.
class CoordinatorManager : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool isCoordinatorMode READ isCoordinatorMode NOTIFY countChanged)
    // For UI that needs to offer "sign in" independent of whether
    // SiteManager currently has any active site, e.g. TopBar's profile
    // popover, right after a sign-out prunes the active site away entirely.
    Q_PROPERTY(bool hasUnsignedConnection READ hasUnsignedConnection NOTIFY sessionsChanged)

  public:
    enum Role {
        UrlRole = Qt::UserRole + 1,
        HasSessionRole,
    };
    Q_ENUM(Role)

    explicit CoordinatorManager(AppDatabase* db, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool isCoordinatorMode() const { return !m_connections.isEmpty(); }
    bool hasUnsignedConnection() const {
        for (const auto& conn : m_connections)
            if (conn.accessToken.isEmpty())
                return true;
        return false;
    }

    Q_INVOKABLE void addConnection(const QString& url);
    Q_INVOKABLE void removeConnection(const QString& url);
    Q_INVOKABLE void setSession(const QString& url, const QString& accessToken,
                                const QString& refreshToken, const QString& username = {});
    // Signs the live client for this connection out (never just this
    // mirror). Clearing only m_connections would leave the actual
    // CoordinatorClient's in-memory session, the authoritative copy, intact.
    Q_INVOKABLE void logout(const QString& url);
    Q_INVOKABLE bool hasSession(const QString& url) const;
    Q_INVOKABLE QString accessToken(const QString& url) const;
    Q_INVOKABLE QString refreshToken(const QString& url) const;
    Q_INVOKABLE QString username(const QString& url) const;

    // The live CoordinatorClient for one connection. Its in-memory session
    // state is authoritative (mirrored into m_connections via
    // sessionChanged, never the other way around). Returns nullptr for an
    // unknown url.
    Q_INVOKABLE CoordinatorClient* clientFor(const QString& url) const;

    // Test-only: every current connection's URL, so a test can clear all of
    // them instead of just the ones it remembers creating.
    Q_INVOKABLE QStringList urls() const;

  signals:
    void countChanged();
    // Any connection's session state changed (sign-in, sign-out, or a
    // restored/refreshed token). Unlike countChanged, this fires without a
    // row being added or removed.
    void sessionsChanged();

  private:
    void save() const;
    int indexOfUrl(const QString& url) const;
    CoordinatorClient* createClient(const QString& url);

    AppDatabase* m_db;
    QList<CoordinatorConnection> m_connections;
    QHash<QString, CoordinatorClient*> m_clients; // url → client (owned)
};
