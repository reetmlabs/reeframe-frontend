// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QObject>
#include <QTcpServer>

// Minimal local HTTP server standing in for a backend with no cameras, so QML
// tests can point a site at something reachable. /health always answers 200.
// /auth/refresh always issues a new token, the way a backend with a valid
// refresh token would. Every other route answers 200 with an empty JSON array
// while acceptsTokens is on, and 401 while it's off.
class FakeBackendServer : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString url READ url CONSTANT)
    Q_PROPERTY(bool acceptsTokens MEMBER m_acceptsTokens)
    // Requests to anything other than /health, so tests can tell a settled
    // client from one stuck retrying.
    Q_PROPERTY(int requestCount READ requestCount NOTIFY requestCountChanged)
  public:
    explicit FakeBackendServer(bool acceptsTokens, QObject* parent = nullptr);
    QString url() const;
    int requestCount() const { return m_requestCount; }

  signals:
    void requestCountChanged();

  private:
    void onNewConnection();
    QByteArray respond(const QByteArray& path);

    QTcpServer m_server;
    bool m_acceptsTokens;
    int m_requestCount = 0;
    int m_issuedTokens = 0;
};
