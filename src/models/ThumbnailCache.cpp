// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "ThumbnailCache.h"
#include <QDir>
#include <QFile>
#include <QStandardPaths>

ThumbnailCache::ThumbnailCache(QObject* parent)
    : QObject(parent)
{
    m_dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/thumbnails";
    QDir().mkpath(m_dir);
}

QString ThumbnailCache::thumbnailPath(const QString& cameraId) const {
    if (cameraId.isEmpty())
        return {};
    return m_dir + "/" + cameraId + ".jpg";
}

bool ThumbnailCache::hasThumbnail(const QString& cameraId) const {
    return !cameraId.isEmpty() && QFile::exists(thumbnailPath(cameraId));
}

void ThumbnailCache::notifyUpdated(const QString& cameraId) {
    emit thumbnailUpdated(cameraId);
}
