// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "FakeBackendServer.h"

#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTcpSocket>

namespace {

QByteArray httpResponse(int status, const QByteArray& body) {
    const QByteArray reason = status == 200 ? "OK" : "Unauthorized";
    return "HTTP/1.1 " + QByteArray::number(status) + " " + reason +
           "\r\n"
           "Content-Type: application/json\r\n"
           "Content-Length: " +
           QByteArray::number(body.size()) +
           "\r\n"
           "Connection: close\r\n"
           "\r\n" +
           body;
}

} // namespace

FakeBackendServer::FakeBackendServer(bool acceptsTokens, QObject* parent)
    : QObject(parent), m_acceptsTokens(acceptsTokens) {
    connect(&m_server, &QTcpServer::newConnection, this, &FakeBackendServer::onNewConnection);
    m_server.listen(QHostAddress::LocalHost, 0);
}

QString FakeBackendServer::url() const {
    return QStringLiteral("http://127.0.0.1:%1").arg(m_server.serverPort());
}

void FakeBackendServer::onNewConnection() {
    while (QTcpSocket* socket = m_server.nextPendingConnection()) {
        connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
        connect(socket, &QTcpSocket::readyRead, socket, [this, socket] {
            const QByteArray request = socket->peek(socket->bytesAvailable());
            const qsizetype headersEnd = request.indexOf("\r\n\r\n");
            if (headersEnd < 0)
                return;
            // Wait for the body too, so a POST isn't answered before it has
            // been fully sent.
            const QByteArray lengthHeader = "content-length:";
            qsizetype bodyLength = 0;
            for (const QByteArray& line : request.left(headersEnd).split('\n')) {
                if (line.trimmed().toLower().startsWith(lengthHeader))
                    bodyLength = line.trimmed().mid(lengthHeader.size()).trimmed().toLongLong();
            }
            if (request.size() < headersEnd + 4 + bodyLength)
                return;
            socket->readAll();
            // Request line: "GET /cameras HTTP/1.1"
            const QByteArray path = request.left(request.indexOf("\r\n")).split(' ').value(1);
            socket->write(respond(path));
            socket->disconnectFromHost();
        });
    }
}

QByteArray FakeBackendServer::respond(const QByteArray& path) {
    if (path == "/health")
        return httpResponse(200, "{}");
    ++m_requestCount;
    emit requestCountChanged();
    if (path != "/auth/refresh") {
        return m_acceptsTokens ? httpResponse(200, "[]")
                               : httpResponse(401, R"({"error":"unauthorized"})");
    }

    // A distinct, decodable JWT each time, so the client sees a genuinely new
    // token with an expiry far enough out that its renewal timer stays quiet.
    const QJsonObject claims{{"exp", QDateTime::currentSecsSinceEpoch() + 3600},
                             {"n", ++m_issuedTokens}};
    const QByteArray payload = QJsonDocument(claims).toJson(QJsonDocument::Compact).toBase64(
        QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
    const QJsonObject body{{"access_token", QString::fromLatin1("e30." + payload + ".sig")}};
    return httpResponse(200, QJsonDocument(body).toJson(QJsonDocument::Compact));
}
