// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QObject>
#include <QTcpServer>

// Minimal local HTTP server that answers every request with 200 and an empty
// JSON array, so QML tests can point a site at a backend that is reachable
// and has no cameras.
class EmptyBackendServer : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString url READ url CONSTANT)
  public:
    explicit EmptyBackendServer(QObject* parent = nullptr);
    QString url() const;

  private:
    void onNewConnection();

    QTcpServer m_server;
};
