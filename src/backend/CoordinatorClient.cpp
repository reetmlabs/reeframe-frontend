// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "CoordinatorClient.h"
#include <QDateTime>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QRestReply>
#include <algorithm>

// reply.errorString() is transport-level only (empty for an ordinary non-2xx
// reply, e.g. a 401 from bad credentials). The real reason lives in the
// JSON body's "error" field.
static QString describeFailure(QRestReply& reply) {
    const auto doc = reply.readJson();
    const QString message =
        doc && doc->isObject() ? doc->object().value("error").toString() : QString{};
    return QStringLiteral("HTTP %1%2")
        .arg(reply.httpStatus())
        .arg(message.isEmpty() ? QString{} : QStringLiteral(" - ") + message);
}

CoordinatorClient::CoordinatorClient(const QUrl& baseUrl, QObject* parent) : QObject(parent) {
    QString base = baseUrl.toString();
    if (base.endsWith('/'))
        base.chop(1);
    m_baseUrl = QUrl(base);

    m_expiryTimer.setSingleShot(true);
    connect(&m_expiryTimer, &QTimer::timeout, this, &CoordinatorClient::refreshAccessToken);
}

void CoordinatorClient::get(const QString& path, QObject* ctx, ReplyCallback cb) {
    sendRequest("GET", path, {}, ctx, std::move(cb));
}

void CoordinatorClient::post(const QString& path, const QJsonDocument& body, QObject* ctx,
                             ReplyCallback cb) {
    sendRequest("POST", path, body, ctx, std::move(cb));
}

void CoordinatorClient::sendRequest(const QByteArray& verb, const QString& path,
                                    const QJsonDocument& body, QObject* ctx, ReplyCallback cb) {
    QNetworkRequest req(QUrl(m_baseUrl.toString() + path));
    req.setRawHeader("Accept", "application/json");
    if (!m_accessToken.isEmpty())
        req.setRawHeader("Authorization", "Bearer " + m_accessToken.toUtf8());

    // /login and /refresh aren't gated by RequireUser, so a 401 from one of
    // them means bad credentials, not an expired token.
    const bool isAuthRoute = path == QLatin1String("/login") || path == QLatin1String("/refresh");
    ReplyCallback wrapped = [this, isAuthRoute, cb](QRestReply& reply) {
        if (!isAuthRoute && reply.httpStatus() == 401 && !m_refreshToken.isEmpty())
            refreshAccessToken();
        cb(reply);
    };

    if (verb == "GET")
        m_rest.get(req, ctx, std::move(wrapped));
    else
        m_rest.post(req, body, ctx, std::move(wrapped));
}

void CoordinatorClient::restoreSession(const QString& username, const QString& accessToken,
                                       const QString& refreshToken) {
    m_username = username;
    m_accessToken = accessToken;
    m_refreshToken = refreshToken;
    m_accessTokenExpiresAt = decodeJwtExpiry(accessToken);
    scheduleExpiryRefresh();
    emit sessionChanged();
}

void CoordinatorClient::signIn(const QString& username, const QString& password) {
    QJsonObject body;
    body["username"] = username;
    body["password"] = password;

    post("/login", QJsonDocument(body), this, [this, username](QRestReply& reply) {
        if (!reply.isSuccess()) {
            emit signInFailed(describeFailure(reply));
            return;
        }
        const auto doc = reply.readJson();
        if (!doc || !doc->isObject()) {
            emit signInFailed(QStringLiteral("malformed login response"));
            return;
        }
        const auto obj = doc->object();
        m_username = username;
        m_accessToken = obj.value("access_token").toString();
        m_refreshToken = obj.value("refresh_token").toString();
        m_accessTokenExpiresAt = decodeJwtExpiry(m_accessToken);
        scheduleExpiryRefresh();
        emit sessionChanged();
    });
}

void CoordinatorClient::refreshAccessToken() {
    if (m_refreshToken.isEmpty()) {
        emit refreshFailed(QStringLiteral("no refresh token available"));
        return;
    }
    if (m_refreshInFlight)
        return;
    m_refreshInFlight = true;

    QJsonObject body;
    body["refresh_token"] = m_refreshToken;

    post("/refresh", QJsonDocument(body), this, [this](QRestReply& reply) {
        m_refreshInFlight = false;
        if (!reply.isSuccess()) {
            emit refreshFailed(describeFailure(reply));
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

void CoordinatorClient::logout() { clearSession(); }

void CoordinatorClient::clearSession() {
    m_username.clear();
    m_accessToken.clear();
    m_refreshToken.clear();
    m_accessTokenExpiresAt = 0;
    m_expiryTimer.stop();
    emit sessionChanged();
}

void CoordinatorClient::scheduleExpiryRefresh() {
    if (m_accessTokenExpiresAt <= 0) {
        m_expiryTimer.stop();
        return;
    }
    const qint64 nowSecs = QDateTime::currentSecsSinceEpoch();
    qint64 delaySecs = (m_accessTokenExpiresAt - nowSecs) - 60;
    delaySecs = std::clamp<qint64>(delaySecs, 5, 24 * 60 * 60);
    m_expiryTimer.start(int(delaySecs * 1000));
}

qint64 CoordinatorClient::decodeJwtExpiry(const QString& jwt) {
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
