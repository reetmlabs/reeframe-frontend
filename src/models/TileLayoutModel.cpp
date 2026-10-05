// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "TileLayoutModel.h"
#include "AppDatabase.h"
#include <QHash>
#include <QSet>
#include <QUuid>
#include <QtAlgorithms>

TileLayoutModel::TileLayoutModel(AppDatabase* db, QObject* parent)
    : QAbstractListModel(parent), m_db(db) {}

int TileLayoutModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : m_tiles.size();
}

QVariant TileLayoutModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_tiles.size())
        return {};
    const TileItem& t = m_tiles[index.row()];
    switch (role) {
    case TileIdRole:      return t.id;
    case TileColRole:     return t.col;
    case TileRowRole:     return t.row;
    case TileColSpanRole: return t.colSpan;
    case TileRowSpanRole: return t.rowSpan;
    case TileCameraIdRole: return t.cameraId;
    }
    return {};
}

QHash<int, QByteArray> TileLayoutModel::roleNames() const {
    return {
        {TileIdRole,       "tileId"},
        {TileColRole,      "tileCol"},
        {TileRowRole,      "tileRow"},
        {TileColSpanRole,  "tileColSpan"},
        {TileRowSpanRole,  "tileRowSpan"},
        {TileCameraIdRole, "tileCameraId"},
    };
}

int TileLayoutModel::maxOccupiedRow() const {
    int max = -1;
    for (const TileItem& t : m_tiles)
        max = qMax(max, t.row + t.rowSpan - 1);
    return max;
}

QStringList TileLayoutModel::assignedCameraIds() const {
    QStringList ids;
    for (const TileItem& t : m_tiles)
        if (!t.cameraId.isEmpty())
            ids.append(t.cameraId);
    return ids;
}

void TileLayoutModel::setActiveProfileId(const QString& id) {
    if (m_activeProfileId == id)
        return;
    m_activeProfileId = id;
    loadTiles();
    emit activeProfileChanged();
}

void TileLayoutModel::setActiveSiteId(const QString& id) {
    if (m_activeSiteId == id)
        return;
    m_activeSiteId = id;
    if (!m_activeProfileId.isEmpty() && !profileIds().contains(m_activeProfileId))
        m_activeProfileId.clear();
    if (!m_activeSiteId.isEmpty()) {
        const QStringList ids = profileIds();
        if (ids.isEmpty()) {
            m_activeProfileId = createProfile("Default");
        } else if (m_activeProfileId.isEmpty()) {
            m_activeProfileId = ids.first();
        }
    }
    loadTiles();
    emit activeSiteChanged();
    emit activeProfileChanged();
}

void TileLayoutModel::loadTiles() {
    beginResetModel();
    m_tiles.clear();

    if (!m_activeProfileId.isEmpty()) {
        const auto formations = m_db->loadTileFormations(m_activeProfileId);
        const auto bindings = m_activeSiteId.isEmpty()
            ? QList<TileCameraBindingRecord>{}
            : m_db->loadTileCameraBindings(m_activeProfileId, m_activeSiteId);

        QHash<QString, QString> cameraByTile;
        for (const TileCameraBindingRecord& b : bindings)
            cameraByTile.insert(b.tileId, b.cameraId);

        for (const TileFormationRecord& f : formations)
            m_tiles.append({f.id, f.col, f.row, f.colSpan, f.rowSpan, cameraByTile.value(f.id)});
    }

    endResetModel();
    emit layoutChanged();
}

// - Tile CRUD -

QString TileLayoutModel::addTile() {
    if (m_activeProfileId.isEmpty())
        return {};

    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);

    int newRow = 0;
    for (const TileItem& t : m_tiles)
        newRow = qMax(newRow, t.row + t.rowSpan);

    m_db->insertTileFormation(id, m_activeProfileId, 0, newRow, 2, 2);

    beginInsertRows({}, m_tiles.size(), m_tiles.size());
    m_tiles.append({id, 0, newRow, 2, 2, {}});
    endInsertRows();

    emit tileAdded(id);
    emit layoutChanged();
    return id;
}

void TileLayoutModel::removeTile(const QString& tileId) {
    const int idx = tileIndex(tileId);
    if (idx < 0)
        return;

    m_db->deleteTileFormation(tileId); // cascades camera bindings via FK

    beginRemoveRows({}, idx, idx);
    m_tiles.removeAt(idx);
    endRemoveRows();

    emit tileRemoved(tileId);
    emit layoutChanged();
}

void TileLayoutModel::moveTile(const QString& tileId, int col, int row) {
    const int idx = tileIndex(tileId);
    if (idx < 0)
        return;

    col = qMax(0, qMin(col, 7));
    row = qMax(0, row);

    const TileItem& t = m_tiles[idx];
    const int colSpan = qMin(t.colSpan, 8 - col);

    if (wouldOverlap(tileId, col, row, colSpan, t.rowSpan))
        return;

    m_db->updateTileFormation(tileId, col, row, colSpan, t.rowSpan);
    m_tiles[idx].col = col;
    m_tiles[idx].row = row;
    m_tiles[idx].colSpan = colSpan;

    const QModelIndex mi = index(idx);
    emit dataChanged(mi, mi, {TileColRole, TileRowRole, TileColSpanRole});
    emit layoutChanged();
}

void TileLayoutModel::moveTileWithPush(const QString& tileId, int col, int row) {
    const int idx = tileIndex(tileId);
    if (idx < 0)
        return;

    col = qMax(0, qMin(col, 7));
    row = qMax(0, row);

    const TileItem& t = m_tiles[idx];
    const int colSpan = qMin(t.colSpan, 8 - col);

    if (!pushTilesForInsert(idx, col, row, colSpan, t.rowSpan))
        return; // no room even after cascading; tile stays at addTile()'s spot

    m_db->updateTileFormation(tileId, col, row, colSpan, t.rowSpan);
    m_tiles[idx].col = col;
    m_tiles[idx].row = row;
    m_tiles[idx].colSpan = colSpan;

    const QModelIndex mi = index(idx);
    emit dataChanged(mi, mi, {TileColRole, TileRowRole, TileColSpanRole});
    emit layoutChanged();
}

bool TileLayoutModel::pushTilesForInsert(int excludeIdx, int col, int row, int colSpan,
                                          int rowSpan) {
    QSet<int> affected;
    bool changed = true;
    while (changed) {
        changed = false;
        for (int i = 0; i < m_tiles.size(); ++i) {
            if (i == excludeIdx || affected.contains(i))
                continue;
            const TileItem& t = m_tiles[i];

            const bool blockedByInsert = t.row < row + rowSpan && row < t.row + t.rowSpan &&
                                         t.col < col + colSpan && col < t.col + t.colSpan;

            bool blockedByPushed = false;
            for (int a : std::as_const(affected)) {
                const TileItem& p = m_tiles[a];
                const int pushedCol = p.col + colSpan;
                if (t.row < p.row + p.rowSpan && p.row < t.row + t.rowSpan &&
                    t.col < pushedCol + p.colSpan && pushedCol < t.col + t.colSpan) {
                    blockedByPushed = true;
                    break;
                }
            }

            if (blockedByInsert || blockedByPushed) {
                affected.insert(i);
                changed = true;
            }
        }
    }

    // Insertion is all-or-nothing. Unlike a resize's growth, there's no
    // meaningful "insert with less width" fallback, so refuse outright if
    // any affected tile can't be pushed the full amount.
    for (int a : std::as_const(affected)) {
        const TileItem& t = m_tiles[a];
        if (t.col + colSpan + t.colSpan > 8)
            return false;
    }

    for (int a : std::as_const(affected)) {
        m_tiles[a].col += colSpan;
        const TileItem& t = m_tiles[a];
        m_db->updateTileFormation(t.id, t.col, t.row, t.colSpan, t.rowSpan);
        emit dataChanged(index(a), index(a), {TileColRole});
    }
    if (!affected.isEmpty())
        emit layoutChanged();
    return true;
}

void TileLayoutModel::resizeTile(const QString& tileId, int colSpan, int rowSpan) {
    const int idx = tileIndex(tileId);
    if (idx < 0)
        return;

    const TileItem& t = m_tiles[idx];
    colSpan = qBound(1, colSpan, 8 - t.col);
    rowSpan = qMax(1, rowSpan);

    // Widening alone pushes anything in the way to the right (see
    // growColSpanWithPush) instead of rejecting outright. Growing taller
    // keeps the plain reject-on-overlap behavior below, since nothing
    // needs a vertical push.
    if (colSpan > t.colSpan && rowSpan <= t.rowSpan) {
        growColSpanWithPush(idx, colSpan);
        return;
    }

    if (wouldOverlap(tileId, t.col, t.row, colSpan, rowSpan))
        return;

    m_db->updateTileFormation(tileId, t.col, t.row, colSpan, rowSpan);
    m_tiles[idx].colSpan = colSpan;
    m_tiles[idx].rowSpan = rowSpan;

    const QModelIndex mi = index(idx);
    emit dataChanged(mi, mi, {TileColSpanRole, TileRowSpanRole});
    emit layoutChanged();
}

void TileLayoutModel::growColSpanWithPush(int idx, int requestedColSpan) {
    const TileItem original = m_tiles[idx];
    int delta = requestedColSpan - original.colSpan;
    if (delta <= 0)
        return;

    // Find the largest delta (<= requested) that fits once every tile it
    // would transitively push is accounted for, shrinking delta and
    // rechecking until stable.
    QSet<int> affected;
    while (delta > 0) {
        QSet<int> candidate;
        bool changed = true;
        while (changed) {
            changed = false;
            for (int i = 0; i < m_tiles.size(); ++i) {
                if (i == idx || candidate.contains(i))
                    continue;
                const TileItem& t = m_tiles[i];

                const bool blockedByResize =
                    t.row < original.row + original.rowSpan &&
                    original.row < t.row + t.rowSpan &&
                    t.col < original.col + original.colSpan + delta &&
                    original.col < t.col + t.colSpan;

                bool blockedByPushed = false;
                for (int a : std::as_const(candidate)) {
                    const TileItem& p = m_tiles[a];
                    const int pushedCol = p.col + delta;
                    if (t.row < p.row + p.rowSpan && p.row < t.row + t.rowSpan &&
                        t.col < pushedCol + p.colSpan && pushedCol < t.col + t.colSpan) {
                        blockedByPushed = true;
                        break;
                    }
                }

                if (blockedByResize || blockedByPushed) {
                    candidate.insert(i);
                    changed = true;
                }
            }
        }

        int maxDelta = 8 - original.col - original.colSpan;
        for (int a : std::as_const(candidate))
            maxDelta = qMin(maxDelta, 8 - m_tiles[a].col - m_tiles[a].colSpan);

        if (maxDelta >= delta) {
            affected = candidate;
            break;
        }
        if (maxDelta <= 0)
            return; // no room to grow at all
        delta = maxDelta;
    }

    m_tiles[idx].colSpan = original.colSpan + delta;
    m_db->updateTileFormation(original.id, original.col, original.row, m_tiles[idx].colSpan,
                              original.rowSpan);
    emit dataChanged(index(idx), index(idx), {TileColSpanRole});

    for (int a : std::as_const(affected)) {
        m_tiles[a].col += delta;
        const TileItem& t = m_tiles[a];
        m_db->updateTileFormation(t.id, t.col, t.row, t.colSpan, t.rowSpan);
        emit dataChanged(index(a), index(a), {TileColRole});
    }
    emit layoutChanged();
}

void TileLayoutModel::assignCamera(const QString& tileId, const QString& cameraId) {
    const int idx = tileIndex(tileId);
    if (idx < 0 || m_activeProfileId.isEmpty() || m_activeSiteId.isEmpty())
        return;

    m_db->upsertTileCameraBinding(m_activeProfileId, tileId, m_activeSiteId, cameraId);
    m_tiles[idx].cameraId = cameraId;

    const QModelIndex mi = index(idx);
    emit dataChanged(mi, mi, {TileCameraIdRole});
    emit layoutChanged();
}

void TileLayoutModel::clearCamera(const QString& tileId) {
    assignCamera(tileId, {});
}

void TileLayoutModel::removeTilesForCamera(const QString& cameraId) {
    if (cameraId.isEmpty())
        return;

    // Sweeps every profile on the site, including ones not currently
    // loaded into m_tiles.
    m_db->deleteTileFormationsForCamera(m_activeSiteId, cameraId);

    // Iterate backwards so removeAt() doesn't invalidate indices still
    // to be checked, and so the active profile's own view of m_tiles
    // matches what the sweep above just did to the database.
    for (int i = m_tiles.size() - 1; i >= 0; --i) {
        if (m_tiles.at(i).cameraId != cameraId)
            continue;
        const QString tileId = m_tiles.at(i).id;
        beginRemoveRows({}, i, i);
        m_tiles.removeAt(i);
        endRemoveRows();
        emit tileRemoved(tileId);
    }
    emit layoutChanged();
}

// - Profile management -

bool TileLayoutModel::hasCameraAssigned(const QString& cameraId) const {
    if (cameraId.isEmpty())
        return false;
    for (const TileItem& t : m_tiles)
        if (t.cameraId == cameraId)
            return true;
    return false;
}

QString TileLayoutModel::tileIdAt(int row) const {
    if (row < 0 || row >= m_tiles.size())
        return {};
    return m_tiles.at(row).id;
}

QVariantMap TileLayoutModel::tileById(const QString& tileId) const {
    const int idx = tileIndex(tileId);
    if (idx < 0)
        return {};
    const TileItem& t = m_tiles.at(idx);
    return {
        {"col", t.col},
        {"row", t.row},
        {"colSpan", t.colSpan},
        {"rowSpan", t.rowSpan},
        {"cameraId", t.cameraId},
    };
}

QStringList TileLayoutModel::profileIds() const {
    if (m_activeSiteId.isEmpty())
        return {};
    QStringList ids;
    for (const TileProfileRecord& p : m_db->loadTileProfilesForSite(m_activeSiteId))
        ids.append(p.id);
    return ids;
}

QString TileLayoutModel::profileName(const QString& profileId) const {
    return m_db->loadTileProfile(profileId).name;
}

QString TileLayoutModel::createProfile(const QString& name) {
    if (m_activeSiteId.isEmpty())
        return {};
    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_db->insertTileProfile(id, name, m_activeSiteId);
    return id;
}

void TileLayoutModel::renameProfile(const QString& profileId, const QString& name) {
    m_db->renameTileProfile(profileId, name);
    if (profileId == m_activeProfileId)
        emit activeProfileChanged();
}

void TileLayoutModel::deleteProfile(const QString& profileId) {
    m_db->deleteTileProfile(profileId); // cascades formations + site assignments
    if (profileId == m_activeProfileId) {
        m_activeProfileId.clear();
        loadTiles();
        emit activeProfileChanged();
    }
}

void TileLayoutModel::assignProfileToSite(const QString& profileId, const QString& siteId) {
    m_db->insertProfileSiteAssignment(profileId, siteId);
}

// - Helpers -

bool TileLayoutModel::wouldOverlap(const QString& excludeId, int col, int row,
                                    int colSpan, int rowSpan) const {
    for (const TileItem& t : m_tiles) {
        if (t.id == excludeId)
            continue;
        if (col < t.col + t.colSpan && col + colSpan > t.col
            && row < t.row + t.rowSpan && row + rowSpan > t.row)
            return true;
    }
    return false;
}

int TileLayoutModel::tileIndex(const QString& tileId) const {
    for (int i = 0; i < m_tiles.size(); ++i)
        if (m_tiles[i].id == tileId)
            return i;
    return -1;
}
