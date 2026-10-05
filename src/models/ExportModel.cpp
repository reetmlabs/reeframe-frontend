// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "ExportModel.h"
#include "SiteManager.h"
#include <QFile>
#include <QFileDialog>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QRestReply>
#include <QStandardPaths>
#include <QUrl>

ExportModel::ExportModel(SiteManager* siteManager, QObject* parent)
    : QObject(parent), m_siteManager(siteManager) {
    m_pollTimer.setInterval(2000);
    connect(&m_pollTimer, &QTimer::timeout, this, &ExportModel::pollOnce);
}

void ExportModel::requestExport(const QString& cameraId, const QString& from, const QString& to) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;

    m_pollTimer.stop();
    m_jobId.clear();
    m_cameraId = cameraId;
    m_downloadUrl.clear();
    m_sizeBytes = -1;
    emit sizeBytesChanged();
    m_error.clear();
    emit errorChanged();
    setStatus(QStringLiteral("pending"));

    QJsonObject body;
    body["camera_id"] = cameraId;
    body["from"] = from;
    body["to"] = to;

    client->post("/recordings/export", QJsonDocument(body), this, [this](QRestReply& reply) {
        const auto doc = reply.readJson();
        if (!reply.isSuccess() || !doc || !doc->isObject()) {
            m_error = reply.isSuccess() ? QStringLiteral("malformed export response")
                                       : reply.errorString();
            emit errorChanged();
            setStatus(QStringLiteral("failed"));
            return;
        }
        const auto obj = doc->object();
        m_jobId = obj["id"].toString();
        applyJobJson(obj);
        if (m_status != QStringLiteral("completed") && m_status != QStringLiteral("failed"))
            m_pollTimer.start();
    });
}

void ExportModel::pollOnce() {
    if (m_jobId.isEmpty()) {
        m_pollTimer.stop();
        return;
    }
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    client->get(QString("/export-jobs/%1").arg(m_jobId), this, [this](QRestReply& reply) {
        const auto doc = reply.readJson();
        if (!reply.isSuccess() || !doc || !doc->isObject())
            return; // transient hiccup, keep polling rather than giving up
        applyJobJson(doc->object());
        if (m_status == QStringLiteral("completed") || m_status == QStringLiteral("failed"))
            m_pollTimer.stop();
    });
}

void ExportModel::applyJobJson(const QJsonObject& obj) {
    setStatus(obj["status"].toString());
    m_downloadUrl = obj["download_url"].toString();
    const auto errStr = obj["error"].toString();
    if (!errStr.isEmpty()) {
        m_error = errStr;
        emit errorChanged();
    }
    const qint64 size =
        obj["size_bytes"].isNull() ? -1 : static_cast<qint64>(obj["size_bytes"].toDouble());
    if (size != m_sizeBytes) {
        m_sizeBytes = size;
        emit sizeBytesChanged();
    }
}

QString ExportModel::chooseSaveLocation() const {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    const QString suggestedName = QString("%1_%2.mp4").arg(m_cameraId, m_jobId);
    const QString suggestedPath = dir.isEmpty() ? suggestedName : (dir + "/" + suggestedName);
    return QFileDialog::getSaveFileName(nullptr, tr("Save Export"), suggestedPath,
                                        tr("Video files (*.mp4);;All files (*)"));
}

void ExportModel::downloadTo(const QString& localPath) {
    if (m_downloadUrl.isEmpty()) {
        emit downloadFailed(tr("export not ready"));
        return;
    }
    auto* reply = m_downloadNam.get(QNetworkRequest(QUrl(m_downloadUrl)));
    connect(reply, &QNetworkReply::finished, this, [this, reply, localPath]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit downloadFailed(reply->errorString());
            return;
        }
        QFile file(localPath);
        if (!file.open(QIODevice::WriteOnly)) {
            emit downloadFailed(tr("could not open file for writing"));
            return;
        }
        file.write(reply->readAll());
        file.close();
        emit downloadCompleted(localPath);
    });
}

void ExportModel::setStatus(const QString& s) {
    if (m_status == s)
        return;
    m_status = s;
    emit statusChanged();
}
