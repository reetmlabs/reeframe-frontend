// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "BackendClient.h"
#include <QDateTime>
#include <QJsonObject>
#include <QPointer>
#include <QRestReply>
#include <algorithm>

// Scales 1:1 with total site/node count (one BackendClient each) and runs for
// the app's entire lifetime, so this is kept lighter than the codebase's other
// (bounded, foreground) poll timers rather than copying their interval.
constexpr int kHealthPollIntervalMs = 5000;
// A backend that accepts the connection but hangs mid-restart must still
// count as down, rather than leaving the poll pending forever.
constexpr int kHealthTimeoutMs = 3000;

BackendClient::BackendClient(const QString& nodeId, const QUrl& baseUrl, QObject* parent)
    : QObject(parent), m_nodeId(nodeId) {
    QString base = baseUrl.toString();
    if (base.endsWith('/'))
        base.chop(1);
    m_baseUrl = QUrl(base);

    m_expiryTimer.setSingleShot(true);
    connect(&m_expiryTimer, &QTimer::timeout, this, &BackendClient::refreshAccessToken);

    // Always running, not just while unhealthy: the same timer must catch an
    // Online-to-Error mid-session drop, not only an Error-to-Online recovery.
    m_healthPollTimer.setInterval(kHealthPollIntervalMs);
    connect(&m_healthPollTimer, &QTimer::timeout, this, &BackendClient::pollHealthSilently);
    m_healthPollTimer.start();
}

void BackendClient::checkHealth() {
    setStatus(Status::Connecting);
    pollHealthSilently();
}

void BackendClient::pollHealthSilently() {
    sendRequest(
        "GET", "/health", {}, this, [this](QRestReply& reply) { handleHealthReply(reply); },
        kHealthTimeoutMs);
}

void BackendClient::handleHealthReply(QRestReply& reply) {
    if (reply.isSuccess()) {
        const auto doc = reply.readJson();
        m_version = doc ? doc->object().value("version").toString() : QString{};
        emit versionChanged();
        setStatus(Status::Online);
    } else {
        setStatus(Status::Error);
    }
}

void BackendClient::get(const QString& path, QObject* ctx, ReplyCallback cb) {
    sendRequest("GET", path, {}, ctx, std::move(cb));
}

void BackendClient::post(const QString& path, const QJsonDocument& body, QObject* ctx,
                         ReplyCallback cb) {
    sendRequest("POST", path, body, ctx, std::move(cb));
}

void BackendClient::put(const QString& path, const QJsonDocument& body, QObject* ctx,
                        ReplyCallback cb) {
    sendRequest("PUT", path, body, ctx, std::move(cb));
}

void BackendClient::patch(const QString& path, const QJsonDocument& body, QObject* ctx,
                          ReplyCallback cb) {
    sendRequest("PATCH", path, body, ctx, std::move(cb));
}

void BackendClient::del(const QString& path, QObject* ctx, ReplyCallback cb) {
    sendRequest("DELETE", path, {}, ctx, std::move(cb));
}

void BackendClient::sendRequest(const QByteArray& verb, const QString& path,
                                const QJsonDocument& body, QObject* ctx, ReplyCallback cb,
                                int transferTimeoutMs) {
    QNetworkRequest req(QUrl(m_baseUrl.toString() + path));
    if (transferTimeoutMs > 0)
        req.setTransferTimeout(transferTimeoutMs);
    req.setRawHeader("Accept", "application/json");
    if (!m_accessToken.isEmpty())
        req.setRawHeader("Authorization", "Bearer " + m_accessToken.toUtf8());

    // /auth/* routes aren't behind AuthMiddleware, so a 401 from one of them
    // means bad credentials, not an expired token. Never treat those as a
    // reason to refresh (refreshAccessToken() itself posts to /auth/refresh,
    // which would otherwise recurse into itself on a failure).
    const bool isAuthRoute = path.startsWith(QLatin1String("/auth/"));
    ReplyCallback wrapped = [this, isAuthRoute, cb](QRestReply& reply) {
        if (!isAuthRoute && reply.httpStatus() == 401 &&
            (!m_refreshToken.isEmpty() || m_coordinatorTokenProvider))
            refreshAccessToken();
        cb(reply);
    };

    if (verb == "GET")
        m_rest.get(req, ctx, std::move(wrapped));
    else if (verb == "POST")
        m_rest.post(req, body, ctx, std::move(wrapped));
    else if (verb == "DELETE")
        m_rest.deleteResource(req, ctx, std::move(wrapped));
    else if (verb == "PUT")
        m_rest.put(req, body, ctx, std::move(wrapped));
    else // PATCH
        m_rest.patch(req, body, ctx, std::move(wrapped));
}

void BackendClient::restoreSession(const QString& username, const QString& accessToken,
                                   const QString& refreshToken) {
    m_username = username;
    m_accessToken = accessToken;
    m_refreshToken = refreshToken;
    m_accessTokenExpiresAt = decodeJwtExpiry(accessToken);
    scheduleExpiryRefresh();
    emit sessionChanged();
}

void BackendClient::signIn(const QString& username, const QString& password) {
    QJsonObject body;
    body["username"] = username;
    body["password"] = password;
    const QJsonDocument doc(body);

    post("/auth/setup", doc, this, [this, doc](QRestReply& reply) {
        if (reply.isSuccess()) {
            applySessionFromAuthResponse(reply);
            return;
        }
        if (reply.httpStatus() != 409) {
            emit signInFailed(reply.errorString());
            return;
        }
        // Setup already completed on this node, so fall back to a normal
        // login with the same credentials the user just typed.
        post("/auth/login", doc, this, [this](QRestReply& loginReply) {
            if (loginReply.isSuccess())
                applySessionFromAuthResponse(loginReply);
            else
                emit signInFailed(loginReply.errorString());
        });
    });
}

void BackendClient::requestCoordinatorToken() {
    if (m_coordinatorTokenProvider)
        refreshAccessToken();
}

void BackendClient::refreshAccessToken() {
    if (m_coordinatorTokenProvider) {
        // Already in flight. Whoever's waiting sees the result via
        // sessionChanged()/refreshFailed() same as this caller would.
        if (m_refreshInFlight)
            return;
        m_refreshInFlight = true;
        // The coordinator token provider's network call is guarded by
        // SiteManager's ctx, not this client, so a raw [this] capture would
        // fire on a freed BackendClient if a site-list rebuild destroys it
        // mid-flight. QPointer guards against that.
        QPointer<BackendClient> guard(this);
        m_coordinatorTokenProvider([this, guard](bool ok, const QString& accessToken,
                                                 const QString& username, const QString& role) {
            if (!guard)
                return;
            m_refreshInFlight = false;
            if (!ok) {
                emit refreshFailed(QStringLiteral("coordinator token request failed"));
                clearSession();
                return;
            }
            m_accessToken = accessToken;
            m_username = username;
            m_role = role;
            m_accessTokenExpiresAt = decodeJwtExpiry(accessToken);
            scheduleExpiryRefresh();
            emit sessionChanged();
        });
        return;
    }

    if (m_refreshToken.isEmpty()) {
        emit refreshFailed(QStringLiteral("no refresh token available"));
        return;
    }
    // Already refreshing. Whoever's waiting on that call will see the
    // result via sessionChanged()/refreshFailed() same as this caller
    // would, so there's nothing more to do here.
    if (m_refreshInFlight)
        return;
    m_refreshInFlight = true;

    QJsonObject body;
    body["refresh_token"] = m_refreshToken;

    post("/auth/refresh", QJsonDocument(body), this, [this](QRestReply& reply) {
        m_refreshInFlight = false;
        if (!reply.isSuccess()) {
            emit refreshFailed(reply.errorString());
            clearSession();
            return;
        }
        const auto doc = reply.readJson();
        if (!doc || !doc->isObject()) {
            emit refreshFailed(QStringLiteral("malformed refresh response"));
            clearSession();
            return;
        }
        m_accessToken = doc->object().value("access_token").toString();
        m_accessTokenExpiresAt = decodeJwtExpiry(m_accessToken);
        scheduleExpiryRefresh();
        emit sessionChanged();
    });
}

void BackendClient::logout() { clearSession(); }

void BackendClient::applySessionFromAuthResponse(QRestReply& reply) {
    const auto doc = reply.readJson();
    if (!doc || !doc->isObject()) {
        emit signInFailed(QStringLiteral("malformed auth response"));
        return;
    }
    const auto obj = doc->object();
    const auto userObj = obj["user"].toObject();
    m_accessToken = obj["access_token"].toString();
    m_refreshToken = obj["refresh_token"].toString();
    m_username = userObj.value("username").toString();
    m_role = userObj.value("role").toString();
    m_accessTokenExpiresAt = decodeJwtExpiry(m_accessToken);
    scheduleExpiryRefresh();
    emit sessionChanged();
}

void BackendClient::clearSession() {
    m_username.clear();
    m_role.clear();
    m_accessToken.clear();
    m_refreshToken.clear();
    m_accessTokenExpiresAt = 0;
    m_expiryTimer.stop();
    emit sessionChanged();
}

void BackendClient::scheduleExpiryRefresh() {
    if (m_accessTokenExpiresAt <= 0) {
        m_expiryTimer.stop();
        return;
    }
    // Refresh a bit ahead of actual expiry so an in-flight request doesn't
    // race the token going stale. Clamped so a malformed/hostile `exp` far
    // in the future can't overflow QTimer's int-milliseconds range.
    const qint64 nowSecs = QDateTime::currentSecsSinceEpoch();
    qint64 delaySecs = (m_accessTokenExpiresAt - nowSecs) - 60;
    delaySecs = std::clamp<qint64>(delaySecs, 5, 24 * 60 * 60);
    m_expiryTimer.start(int(delaySecs * 1000));
}

qint64 BackendClient::decodeJwtExpiry(const QString& jwt) {
    const auto parts = jwt.split('.');
    if (parts.size() != 3)
        return 0;
    const QByteArray payload = QByteArray::fromBase64(
        parts.at(1).toUtf8(), QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
    const auto doc = QJsonDocument::fromJson(payload);
    if (!doc.isObject())
        return 0;
    return static_cast<qint64>(doc.object().value("exp").toDouble());
}

void BackendClient::setStatus(Status s) {
    if (m_status == s)
        return;
    m_status = s;
    emit statusChanged();
}
