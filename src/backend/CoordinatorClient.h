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

// Talks to one Coordinator instance's own REST API, distinct from
// BackendClient, which talks to a BE. Mirrors BackendClient's shape so
// LoginView.qml (built for a BackendClient) works unmodified against this
// class too.
class CoordinatorClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool hasSession READ hasSession NOTIFY sessionChanged)
    Q_PROPERTY(QString username READ username NOTIFY sessionChanged)
  public:
    using ReplyCallback = std::function<void(QRestReply&)>;

    explicit CoordinatorClient(const QUrl& baseUrl, QObject* parent = nullptr);

    bool hasSession() const { return !m_accessToken.isEmpty(); }
    QString username() const { return m_username; }
    Q_INVOKABLE QString accessToken() const { return m_accessToken; }
    Q_INVOKABLE QString refreshToken() const { return m_refreshToken; }

    // ctx is the lifetime guard: cb is never invoked after ctx is destroyed.
    void get(const QString& path, QObject* ctx, ReplyCallback cb);
    void post(const QString& path, const QJsonDocument& body, QObject* ctx, ReplyCallback cb);

    // Restores a session persisted from a previous run. No network call,
    // just local state. See BackendClient::restoreSession.
    Q_INVOKABLE void restoreSession(const QString& username, const QString& accessToken,
                                    const QString& refreshToken);

    // Signs in against this Coordinator via POST /login.
    Q_INVOKABLE void signIn(const QString& username, const QString& password);

    // Exchanges the stored refresh token for a new access token via
    // POST /refresh. Safe to call while another refresh is already in
    // flight; see BackendClient::refreshAccessToken for why.
    Q_INVOKABLE void refreshAccessToken();

    Q_INVOKABLE void logout();

  signals:
    void sessionChanged();
    void signInFailed(const QString& message);
    void refreshFailed(const QString& message);

  private:
    void sendRequest(const QByteArray& verb, const QString& path, const QJsonDocument& body,
                     QObject* ctx, ReplyCallback cb);
    void clearSession();
    void scheduleExpiryRefresh();
    static qint64 decodeJwtExpiry(const QString& jwt);

    QUrl m_baseUrl;
    QString m_username;
    QString m_accessToken;
    QString m_refreshToken;
    qint64 m_accessTokenExpiresAt = 0;
    bool m_refreshInFlight = false;
    QTimer m_expiryTimer;
    QNetworkAccessManager m_nam;
    QRestAccessManager m_rest{&m_nam};
};
