// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "EmptyBackendServer.h"

#include <QTcpSocket>

EmptyBackendServer::EmptyBackendServer(QObject* parent) : QObject(parent) {
    connect(&m_server, &QTcpServer::newConnection, this, &EmptyBackendServer::onNewConnection);
    m_server.listen(QHostAddress::LocalHost, 0);
}

QString EmptyBackendServer::url() const {
    return QStringLiteral("http://127.0.0.1:%1").arg(m_server.serverPort());
}

void EmptyBackendServer::onNewConnection() {
    while (QTcpSocket* socket = m_server.nextPendingConnection()) {
        connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
        connect(socket, &QTcpSocket::readyRead, socket, [socket] {
            // Requests here never carry a body, so the end of the headers is
            // the end of the request.
            if (!socket->peek(socket->bytesAvailable()).contains("\r\n\r\n"))
                return;
            socket->readAll();
            socket->write("HTTP/1.1 200 OK\r\n"
                          "Content-Type: application/json\r\n"
                          "Content-Length: 2\r\n"
                          "Connection: close\r\n"
                          "\r\n"
                          "[]");
            socket->disconnectFromHost();
        });
    }
}
