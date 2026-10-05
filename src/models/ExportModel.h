// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QNetworkAccessManager>
#include <QObject>
#include <QString>
#include <QTimer>

class SiteManager;

// One export job at a time. Starting a new export replaces whatever this
// was tracking before. Not a list model: RecordingsPanel only ever needs to
// show the single in-flight job's status against whichever session row
// requested it.
class ExportModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(qint64 sizeBytes READ sizeBytes NOTIFY sizeBytesChanged)

  public:
    explicit ExportModel(SiteManager* siteManager, QObject* parent = nullptr);

    // "" | "pending" | "processing" | "completed" | "failed", mirroring
    // ExportJobDto.status from the backend directly, no local remapping.
    QString status() const { return m_status; }
    QString error() const { return m_error; }
    qint64 sizeBytes() const { return m_sizeBytes; }

    // from/to are RFC 3339 timestamps.
    Q_INVOKABLE void requestExport(const QString& cameraId, const QString& from,
                                   const QString& to);

    // Opens a native "Save As" dialog (Qt Widgets QFileDialog, already a
    // dependency via QApplication for the system tray). Returns the chosen
    // path, or an empty string if the user cancelled.
    Q_INVOKABLE QString chooseSaveLocation() const;

    // Downloads the completed job's file to localPath. download_url is an
    // absolute URL from the backend (same assumption as playback's
    // stream_url), so this goes through a plain QNetworkAccessManager
    // rather than BackendClient, which always prefixes a site's base URL
    // onto a relative path.
    Q_INVOKABLE void downloadTo(const QString& localPath);

  signals:
    void statusChanged();
    void errorChanged();
    void sizeBytesChanged();
    void downloadCompleted(const QString& localPath);
    void downloadFailed(const QString& message);

  private:
    void setStatus(const QString& s);
    void pollOnce();
    void applyJobJson(const class QJsonObject& obj);

    SiteManager* m_siteManager;
    QString m_jobId;
    QString m_cameraId;
    QString m_downloadUrl;
    QString m_status;
    QString m_error;
    qint64 m_sizeBytes = -1;
    QTimer m_pollTimer;
    QNetworkAccessManager m_downloadNam;
};
