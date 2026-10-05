// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "AuthenticatedRecordingDevice.h"
#include "BackendClient.h"
#include <QEventLoop>
#include <QMetaObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <cstring>

AuthenticatedRecordingDevice::AuthenticatedRecordingDevice(BackendClient* client,
                                                           const QString& path, QObject* parent)
    : QIODevice(parent), m_client(client), m_path(path) {
    m_thread.start();
    // QThread's own affinity is the creating thread, not the one it manages, so
    // invokeMethod() must target an object living on m_thread, not m_thread itself.
    m_nam = new QNetworkAccessManager; // no parent, required for moveToThread()
    m_nam->moveToThread(&m_thread);
}

AuthenticatedRecordingDevice::~AuthenticatedRecordingDevice() {
    m_thread.quit();
    m_thread.wait();
    // Nothing can be dispatching to m_nam once the worker thread's event
    // loop has stopped.
    delete m_nam;
}

bool AuthenticatedRecordingDevice::open(QIODevice::OpenMode mode) {
    if (!(mode & QIODevice::ReadOnly))
        return false;
    if (m_size < 0) {
        // A minimal ranged GET, purely to read the total size off the
        // response's Content-Range header.
        const RangeResult probe = fetchRange(0, 0);
        if (!probe.ok || probe.totalSize < 0)
            return false;
        m_size = probe.totalSize;
    }
    m_pos = 0;
    return QIODevice::open(mode);
}

void AuthenticatedRecordingDevice::close() {
    QIODevice::close();
}

bool AuthenticatedRecordingDevice::seek(qint64 pos) {
    if (!QIODevice::seek(pos))
        return false;
    m_pos = pos;
    return true;
}

qint64 AuthenticatedRecordingDevice::writeData(const char*, qint64) {
    return -1; // read-only
}

qint64 AuthenticatedRecordingDevice::readData(char* data, qint64 maxSize) {
    if (m_pos >= m_size)
        return 0; // EOF
    const qint64 end = qMin(m_pos + maxSize, m_size) - 1;
    const RangeResult result = fetchRange(m_pos, end);
    if (!result.ok)
        return -1;
    const qint64 n = result.data.size();
    std::memcpy(data, result.data.constData(), static_cast<size_t>(n));
    m_pos += n;
    return n;
}

AuthenticatedRecordingDevice::RangeResult AuthenticatedRecordingDevice::fetchRange(qint64 start,
                                                                                   qint64 end) {
    RangeResult result;

    QMetaObject::invokeMethod(
        m_nam,
        [this, start, end, &result]() {
            QNetworkRequest req(QUrl(m_client->baseUrl().toString() + m_path));
            req.setRawHeader("Authorization", "Bearer " + m_client->accessToken().toUtf8());
            req.setRawHeader("Range", "bytes=" + QByteArray::number(start) + "-" +
                                          QByteArray::number(end));

            QNetworkReply* reply = m_nam->get(req);
            QEventLoop loop;
            connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
            loop.exec();

            if (reply->error() != QNetworkReply::NoError) {
                reply->deleteLater();
                return;
            }

            result.data = reply->readAll();
            // "bytes 0-0/225267713": the part after the slash is the total.
            const QByteArray contentRange = reply->rawHeader("Content-Range");
            const int slash = contentRange.lastIndexOf('/');
            if (slash >= 0)
                result.totalSize = contentRange.mid(slash + 1).toLongLong();
            result.ok = true;
            reply->deleteLater();
        },
        Qt::BlockingQueuedConnection);

    return result;
}
