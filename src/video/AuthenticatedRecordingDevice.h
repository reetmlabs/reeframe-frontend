// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QIODevice>
#include <QNetworkAccessManager>
#include <QThread>

class BackendClient;

// Lets QMediaPlayer::setSourceDevice() play an authenticated recording, since
// QMediaPlayer::setSource(QUrl) can't attach the required Authorization header.
// Fetches happen range by range as the demuxer seeks/reads.
//
// Networking runs on a private worker thread because QNetworkAccessManager and
// QNetworkReply are only safe to use on the thread they live on.
class AuthenticatedRecordingDevice : public QIODevice {
    Q_OBJECT
  public:
    // client must outlive this device; path is a relative API path such as
    // RecordingModel::playbackResolved's streamUrl.
    AuthenticatedRecordingDevice(BackendClient* client, const QString& path,
                                 QObject* parent = nullptr);
    ~AuthenticatedRecordingDevice() override;

    bool open(OpenMode mode) override;
    void close() override;
    bool isSequential() const override { return false; }
    qint64 size() const override { return m_size; }
    bool seek(qint64 pos) override;

  protected:
    qint64 readData(char* data, qint64 maxSize) override;
    qint64 writeData(const char* data, qint64 len) override;

  private:
    struct RangeResult {
        QByteArray data;
        // Parsed from the response's Content-Range header, -1 if absent
        // (i.e. the request failed before we could learn it).
        qint64 totalSize = -1;
        bool ok = false;
    };
    // Blocks the calling thread until the ranged GET (inclusive end) has
    // completed on m_thread.
    RangeResult fetchRange(qint64 start, qint64 end);

    BackendClient* m_client;
    QString m_path;
    QThread m_thread;
    QNetworkAccessManager* m_nam = nullptr; // moved to m_thread; only ever used from there
    qint64 m_size = -1;
    qint64 m_pos = 0;
};
