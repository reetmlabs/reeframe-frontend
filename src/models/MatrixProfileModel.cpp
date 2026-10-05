// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "MatrixProfileModel.h"
#include "AppDatabase.h"
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>

MatrixProfileModel::MatrixProfileModel(AppDatabase* db, QObject* parent)
    : QAbstractListModel(parent), m_db(db) {
    for (const auto& rec : m_db->loadMatrixProfiles())
        m_profiles.append(profileFromRecord(rec.id, rec.name, rec.layout));
    if (m_profiles.isEmpty())
        createDefaultProfile();
}

int MatrixProfileModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : m_profiles.size();
}

QVariant MatrixProfileModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_profiles.size())
        return {};
    const auto& p = m_profiles.at(index.row());
    switch (role) {
    case ProfileIdRole:
        return p.id;
    case ProfileNameRole:
        return p.name;
    case ProfileRowsRole:
        return p.rows;
    case ProfileColsRole:
        return p.cols;
    default:
        return {};
    }
}

QHash<int, QByteArray> MatrixProfileModel::roleNames() const {
    return {
        {ProfileIdRole, "profileId"},
        {ProfileNameRole, "profileName"},
        {ProfileRowsRole, "profileRows"},
        {ProfileColsRole, "profileCols"},
    };
}

void MatrixProfileModel::setActiveProfileIndex(int i) {
    if (i == m_activeIndex || i < 0 || i >= m_profiles.size())
        return;
    m_activeIndex = i;
    emit activeProfileChanged();
    emit activeTilesChanged();
}

QString MatrixProfileModel::activeProfileId() const {
    if (m_activeIndex < 0 || m_activeIndex >= m_profiles.size())
        return {};
    return m_profiles.at(m_activeIndex).id;
}

int MatrixProfileModel::activeRows() const {
    if (m_activeIndex < 0 || m_activeIndex >= m_profiles.size())
        return 2;
    return m_profiles.at(m_activeIndex).rows;
}

int MatrixProfileModel::activeCols() const {
    if (m_activeIndex < 0 || m_activeIndex >= m_profiles.size())
        return 2;
    return m_profiles.at(m_activeIndex).cols;
}

QVariantList MatrixProfileModel::activeTiles() const {
    if (m_activeIndex < 0 || m_activeIndex >= m_profiles.size())
        return {};
    QVariantList result;
    for (const auto& t : m_profiles.at(m_activeIndex).tiles) {
        QVariantMap map;
        map["row"] = t.row;
        map["col"] = t.col;
        map["rowSpan"] = t.rowSpan;
        map["colSpan"] = t.colSpan;
        map["cameraId"] = t.cameraId;
        map["tileType"] = t.tileType;
        result.append(map);
    }
    return result;
}

QString MatrixProfileModel::addProfile(const QString& name, int rows, int cols) {
    MatrixProfile p;
    p.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    p.name = name;
    p.rows = rows;
    p.cols = cols;
    m_db->insertMatrixProfile(p.id, p.name, profileToJson(p), QDateTime::currentSecsSinceEpoch());
    beginInsertRows({}, m_profiles.size(), m_profiles.size());
    m_profiles.append(p);
    endInsertRows();
    return p.id;
}

void MatrixProfileModel::removeProfile(const QString& profileId) {
    const int i = profileIndexById(profileId);
    if (i < 0)
        return;
    m_db->deleteMatrixProfile(profileId);
    beginRemoveRows({}, i, i);
    m_profiles.removeAt(i);
    endRemoveRows();
    m_activeIndex = qBound(0, m_activeIndex, m_profiles.size() - 1);
    emit activeProfileChanged();
    emit activeTilesChanged();
}

void MatrixProfileModel::assignCamera(const QString& profileId, int row, int col,
                                      const QString& cameraId) {
    const int i = profileIndexById(profileId);
    if (i < 0)
        return;
    auto& tiles = m_profiles[i].tiles;
    for (auto& t : tiles) {
        if (t.row == row && t.col == col) {
            t.cameraId = cameraId;
            persistProfile(m_profiles.at(i));
            if (i == m_activeIndex)
                emit activeTilesChanged();
            return;
        }
    }
    TileAssignment t;
    t.row = row;
    t.col = col;
    t.cameraId = cameraId;
    tiles.append(t);
    persistProfile(m_profiles.at(i));
    if (i == m_activeIndex)
        emit activeTilesChanged();
}

void MatrixProfileModel::clearCell(const QString& profileId, int row, int col) {
    const int i = profileIndexById(profileId);
    if (i < 0)
        return;
    auto& tiles = m_profiles[i].tiles;
    for (int j = 0; j < tiles.size(); ++j) {
        if (tiles.at(j).row == row && tiles.at(j).col == col) {
            tiles.removeAt(j);
            persistProfile(m_profiles.at(i));
            if (i == m_activeIndex)
                emit activeTilesChanged();
            return;
        }
    }
}

void MatrixProfileModel::createDefaultProfile() {
    addProfile("2×2", 2, 2);
    m_activeIndex = 0;
}

void MatrixProfileModel::persistProfile(const MatrixProfile& profile) {
    m_db->updateMatrixProfileLayout(profile.id, profileToJson(profile));
}

QString MatrixProfileModel::profileToJson(const MatrixProfile& profile) {
    QJsonObject obj;
    obj["rows"] = profile.rows;
    obj["cols"] = profile.cols;
    QJsonArray tiles;
    for (const auto& t : profile.tiles) {
        QJsonObject tile;
        tile["row"] = t.row;
        tile["col"] = t.col;
        tile["rowSpan"] = t.rowSpan;
        tile["colSpan"] = t.colSpan;
        tile["cameraId"] = t.cameraId;
        tile["tileType"] = t.tileType;
        tiles.append(tile);
    }
    obj["tiles"] = tiles;
    return QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

MatrixProfile MatrixProfileModel::profileFromRecord(const QString& id, const QString& name,
                                                    const QString& json) {
    MatrixProfile p;
    p.id = id;
    p.name = name;
    const auto doc = QJsonDocument::fromJson(json.toUtf8());
    if (!doc.isObject())
        return p;
    const auto obj = doc.object();
    p.rows = obj["rows"].toInt(2);
    p.cols = obj["cols"].toInt(2);
    for (const auto& tv : obj["tiles"].toArray()) {
        const auto t = tv.toObject();
        TileAssignment ta;
        ta.row = t["row"].toInt();
        ta.col = t["col"].toInt();
        ta.rowSpan = t["rowSpan"].toInt(1);
        ta.colSpan = t["colSpan"].toInt(1);
        ta.cameraId = t["cameraId"].toString();
        ta.tileType = t["tileType"].toString("camera");
        p.tiles.append(ta);
    }
    return p;
}

int MatrixProfileModel::profileIndexById(const QString& id) const {
    for (int i = 0; i < m_profiles.size(); ++i)
        if (m_profiles.at(i).id == id)
            return i;
    return -1;
}
