// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QObject>
#include <QString>

class ThumbnailCache : public QObject {
    Q_OBJECT
public:
    explicit ThumbnailCache(QObject* parent = nullptr);

    Q_INVOKABLE QString thumbnailPath(const QString& cameraId) const;
    Q_INVOKABLE bool hasThumbnail(const QString& cameraId) const;
    Q_INVOKABLE void notifyUpdated(const QString& cameraId);

signals:
    void thumbnailUpdated(const QString& cameraId);

private:
    QString m_dir;
};
