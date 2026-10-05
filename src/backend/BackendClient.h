// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QObject>
#include <QRestAccessManager>
#include <QTimer>
#include <QUrl>
#include <functional>

class QRestReply;

class BackendClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString nodeId READ nodeId CONSTANT)
    Q_PROPERTY(Status status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString version READ version NOTIFY versionChanged)
    Q_PROPERTY(bool hasSession READ hasSession NOTIFY sessionChanged)
    Q_PROPERTY(QString username READ username NOTIFY sessionChanged)
    Q_PROPERTY(QString role READ role NOTIFY sessionChanged)
  public:
    enum class Status { Disconnected, Connecting, Online, Error };
    Q_ENUM(Status)

    using ReplyCallback = std::function<void(QRestReply&)>;

    // ok/accessToken/username/role: the shape a Coordinator token request
    // resolves with, mirroring applySessionFromAuthResponse()'s fields.
    using SessionResultCallback = std::function<void(bool ok, const QString& accessToken,
                                                     const QString& username, const QString& role)>;
    using CoordinatorTokenProvider = std::function<void(SessionResultCallback)>;

    explicit BackendClient(const QString& nodeId, const QUrl& baseUrl, QObject* parent = nullptr);

    QString nodeId() const { return m_nodeId; }
    // For callers building requests directly instead of via get()/post()/
    // etc., e.g. AuthenticatedRecordingDevice's raw ranged GETs.
    QUrl baseUrl() const { return m_baseUrl; }
    Status status() const { return m_status; }
    QString version() const { return m_version; }

    bool hasSession() const { return !m_accessToken.isEmpty(); }
    QString username() const { return m_username; }
    // Only known after a live signIn(). A session restored from disk reads
    // empty until the next real sign-in. Display-only, never used for any
    // access decision on the FE side.
    QString role() const { return m_role; }
    Q_INVOKABLE QString accessToken() const { return m_accessToken; }
    Q_INVOKABLE QString refreshToken() const { return m_refreshToken; }
    // Unix seconds decoded from the access token's own `exp` claim, or 0 if
    // there's no session. Test/tooling access to scheduleExpiryRefresh()'s
    // input, same reasoning as accessToken()/refreshToken() above.
    Q_INVOKABLE qint64 accessTokenExpiresAt() const { return m_accessTokenExpiresAt; }

    Q_INVOKABLE void checkHealth();

    // Test-only: sets Status directly, as if a poll had just completed, so a
    // QML test can simulate a background health check without a real server
    // or waiting on the real poll interval. Same convention as
    // restoreSession() below.
    Q_INVOKABLE void setStatusForTest(Status s) { setStatus(s); }

    // ctx is the lifetime guard: the callback is never invoked after ctx is destroyed.
    void get(const QString& path, QObject* ctx, ReplyCallback cb);
    void post(const QString& path, const QJsonDocument& body, QObject* ctx, ReplyCallback cb);
    void put(const QString& path, const QJsonDocument& body, QObject* ctx, ReplyCallback cb);
    void patch(const QString& path, const QJsonDocument& body, QObject* ctx, ReplyCallback cb);
    void del(const QString& path, QObject* ctx, ReplyCallback cb);

    // Restores a session persisted from a previous run (see SiteManager).
    // No network call, just local state. Also usable directly from QML
    // tests to simulate a successful sign-in without a real backend.
    Q_INVOKABLE void restoreSession(const QString& username, const QString& accessToken,
                                    const QString& refreshToken);

    // Signs in against this node. Tries POST /auth/setup first (only
    // succeeds if no user exists yet); on a 409, falls back to POST
    // /auth/login with the same credentials.
    Q_INVOKABLE void signIn(const QString& username, const QString& password);

    // Wires this client to fetch its session from a Coordinator instead of
    // this node's own /auth/login|refresh. Set only for a Coordinator site.
    void setCoordinatorTokenProvider(CoordinatorTokenProvider provider) {
        m_coordinatorTokenProvider = std::move(provider);
    }

    // Requests a session via the provider set above. A site-scoped token
    // has no separate refresh token, so calling this again is how it
    // refreshes. No-op if no provider is set.
    Q_INVOKABLE void requestCoordinatorToken();

    // Exchanges the stored refresh token for a new access token (or, if a
    // CoordinatorTokenProvider is set, re-requests a session through it
    // instead). A no-op if a refresh is already in flight. Clears the
    // session on failure rather than leaving it in a stale state.
    Q_INVOKABLE void refreshAccessToken();

    Q_INVOKABLE void logout();

  signals:
    void statusChanged();
    void versionChanged();
    void sessionChanged();
    void signInFailed(const QString& message);
    void refreshFailed(const QString& message);

  private:
    // transferTimeoutMs of 0 leaves the request without a timeout.
    void sendRequest(const QByteArray& verb, const QString& path, const QJsonDocument& body,
                     QObject* ctx, ReplyCallback cb, int transferTimeoutMs = 0);
    void handleHealthReply(QRestReply& reply);
    // Re-checks /health on a timer without the Connecting flicker checkHealth()
    // shows, so Status can recover to Online (BE came up after the FE did) or
    // drop to Error (BE died mid-session) on its own, with no manual Retry.
    void pollHealthSilently();
    void setStatus(Status s);
    void applySessionFromAuthResponse(QRestReply& reply);
    void clearSession();

    // Schedules refreshAccessToken() to run shortly before
    // m_accessTokenExpiresAt, decoded from the access token's own `exp`
    // claim. The auth responses themselves don't carry an expiry field,
    // so the token is the only source of truth for it.
    void scheduleExpiryRefresh();
    static qint64 decodeJwtExpiry(const QString& jwt);

    QString m_nodeId;
    QUrl m_baseUrl;
    QNetworkAccessManager m_nam;
    QRestAccessManager m_rest{&m_nam};
    Status m_status{Status::Disconnected};
    QString m_version;
    QString m_username;
    QString m_role;
    QString m_accessToken;
    QString m_refreshToken;
    qint64 m_accessTokenExpiresAt = 0;
    bool m_refreshInFlight = false;
    QTimer m_expiryTimer;
    QTimer m_healthPollTimer;
    CoordinatorTokenProvider m_coordinatorTokenProvider;
};
