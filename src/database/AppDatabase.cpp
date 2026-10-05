// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "AppDatabase.h"
#include <QDebug>
#include <QDir>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>

static constexpr int kSchemaVersion = 2;

AppDatabase::AppDatabase(QObject* parent) : QObject(parent) {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    QDir().mkpath(dir);

    m_db = QSqlDatabase::addDatabase("QSQLITE", "reeframe");
    m_db.setDatabaseName(dir + "/app.db");

    if (!m_db.open())
        qFatal("AppDatabase: cannot open app.db: %s", qPrintable(m_db.lastError().text()));

    migrate();
}

AppDatabase::~AppDatabase() {
    m_db.close();
    QSqlDatabase::removeDatabase("reeframe");
}

void AppDatabase::migrate() {
    exec("PRAGMA foreign_keys = ON");

    int version = preference("schema_version", "0").toInt();

    if (version < 1) {
        exec(R"(CREATE TABLE IF NOT EXISTS preferences (
                    key   TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                ))");
        exec(R"(CREATE TABLE IF NOT EXISTS sites (
                    id         TEXT PRIMARY KEY,
                    name       TEXT NOT NULL,
                    created_at INTEGER NOT NULL
                ))");
        exec(R"(CREATE TABLE IF NOT EXISTS nodes (
                    id         TEXT PRIMARY KEY,
                    site_id    TEXT NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
                    url        TEXT NOT NULL,
                    created_at INTEGER NOT NULL
                ))");
        exec(R"(CREATE TABLE IF NOT EXISTS matrix_profiles (
                    id         TEXT PRIMARY KEY,
                    name       TEXT NOT NULL,
                    layout     TEXT NOT NULL,
                    created_at INTEGER NOT NULL
                ))");
        exec(R"(CREATE TABLE IF NOT EXISTS sessions (
                    node_id    TEXT PRIMARY KEY,
                    token      TEXT NOT NULL,
                    expires_at INTEGER NOT NULL
                ))");
        setPreference("schema_version", "1");
        version = 1;
    }

    if (version < 2) {
        exec(R"(CREATE TABLE IF NOT EXISTS tile_profiles (
                    id      TEXT PRIMARY KEY,
                    name    TEXT NOT NULL,
                    site_id TEXT NOT NULL
                ))");
        exec(R"(CREATE TABLE IF NOT EXISTS tile_formations (
                    id         TEXT PRIMARY KEY,
                    profile_id TEXT NOT NULL REFERENCES tile_profiles(id) ON DELETE CASCADE,
                    col        INTEGER NOT NULL,
                    row        INTEGER NOT NULL,
                    col_span   INTEGER NOT NULL DEFAULT 1,
                    row_span   INTEGER NOT NULL DEFAULT 1
                ))");
        exec(R"(CREATE TABLE IF NOT EXISTS tile_camera_bindings (
                    profile_id TEXT NOT NULL,
                    tile_id    TEXT NOT NULL REFERENCES tile_formations(id) ON DELETE CASCADE,
                    site_id    TEXT NOT NULL,
                    camera_id  TEXT NOT NULL DEFAULT '',
                    PRIMARY KEY (profile_id, tile_id, site_id)
                ))");
        exec(R"(CREATE TABLE IF NOT EXISTS profile_site_assignments (
                    profile_id TEXT NOT NULL REFERENCES tile_profiles(id) ON DELETE CASCADE,
                    site_id    TEXT NOT NULL,
                    PRIMARY KEY (profile_id, site_id)
                ))");
        setPreference("schema_version", "2");
        version = 2;
    }
}

QList<SiteRecord> AppDatabase::loadSites() const {
    QSqlQuery q(m_db);
    q.exec("SELECT id, name, created_at FROM sites ORDER BY created_at");
    QList<SiteRecord> rows;
    while (q.next())
        rows.append({q.value(0).toString(), q.value(1).toString(), q.value(2).toLongLong()});
    return rows;
}

void AppDatabase::insertSite(const QString& id, const QString& name, qint64 createdAt) {
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO sites (id, name, created_at) VALUES (?, ?, ?)");
    q.addBindValue(id);
    q.addBindValue(name);
    q.addBindValue(createdAt);
    q.exec();
}

void AppDatabase::deleteSite(const QString& id) {
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM sites WHERE id = ?");
    q.addBindValue(id);
    q.exec();
}

QList<NodeRecord> AppDatabase::loadNodes(const QString& siteId) const {
    QSqlQuery q(m_db);
    q.prepare("SELECT id, site_id, url, created_at FROM nodes "
              "WHERE site_id = ? ORDER BY created_at");
    q.addBindValue(siteId);
    q.exec();
    QList<NodeRecord> rows;
    while (q.next())
        rows.append({q.value(0).toString(), q.value(1).toString(), q.value(2).toString(),
                     q.value(3).toLongLong()});
    return rows;
}

void AppDatabase::insertNode(const QString& id, const QString& siteId, const QString& url,
                             qint64 createdAt) {
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO nodes (id, site_id, url, created_at) VALUES (?, ?, ?, ?)");
    q.addBindValue(id);
    q.addBindValue(siteId);
    q.addBindValue(url);
    q.addBindValue(createdAt);
    q.exec();
}

void AppDatabase::deleteNode(const QString& id) {
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM nodes WHERE id = ?");
    q.addBindValue(id);
    q.exec();
}

QList<MatrixProfileRecord> AppDatabase::loadMatrixProfiles() const {
    QSqlQuery q(m_db);
    q.exec("SELECT id, name, layout, created_at FROM matrix_profiles ORDER BY created_at");
    QList<MatrixProfileRecord> rows;
    while (q.next())
        rows.append({q.value(0).toString(), q.value(1).toString(), q.value(2).toString(),
                     q.value(3).toLongLong()});
    return rows;
}

void AppDatabase::insertMatrixProfile(const QString& id, const QString& name, const QString& layout,
                                      qint64 createdAt) {
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO matrix_profiles (id, name, layout, created_at) VALUES (?, ?, ?, ?)");
    q.addBindValue(id);
    q.addBindValue(name);
    q.addBindValue(layout);
    q.addBindValue(createdAt);
    q.exec();
}

void AppDatabase::updateMatrixProfileLayout(const QString& id, const QString& layout) {
    QSqlQuery q(m_db);
    q.prepare("UPDATE matrix_profiles SET layout = ? WHERE id = ?");
    q.addBindValue(layout);
    q.addBindValue(id);
    q.exec();
}

void AppDatabase::deleteMatrixProfile(const QString& id) {
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM matrix_profiles WHERE id = ?");
    q.addBindValue(id);
    q.exec();
}

QString AppDatabase::preference(const QString& key, const QString& defaultValue) const {
    QSqlQuery q(m_db);
    q.prepare("SELECT value FROM preferences WHERE key = ?");
    q.addBindValue(key);
    q.exec();
    return q.next() ? q.value(0).toString() : defaultValue;
}

void AppDatabase::setPreference(const QString& key, const QString& value) {
    QSqlQuery q(m_db);
    q.prepare("INSERT OR REPLACE INTO preferences (key, value) VALUES (?, ?)");
    q.addBindValue(key);
    q.addBindValue(value);
    q.exec();
}

void AppDatabase::exec(const QString& sql) {
    QSqlQuery q(m_db);
    if (!q.exec(sql))
        qWarning() << "AppDatabase:" << q.lastError().text();
}

// - Tile profiles -

QList<TileProfileRecord> AppDatabase::loadTileProfilesForSite(const QString& siteId) const {
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, name, site_id FROM tile_profiles WHERE site_id = ?
        UNION
        SELECT tp.id, tp.name, tp.site_id FROM tile_profiles tp
          JOIN profile_site_assignments psa ON psa.profile_id = tp.id
          WHERE psa.site_id = ?
    )");
    q.addBindValue(siteId);
    q.addBindValue(siteId);
    q.exec();
    QList<TileProfileRecord> rows;
    while (q.next())
        rows.append({q.value(0).toString(), q.value(1).toString(), q.value(2).toString()});
    return rows;
}

TileProfileRecord AppDatabase::loadTileProfile(const QString& id) const {
    QSqlQuery q(m_db);
    q.prepare("SELECT id, name, site_id FROM tile_profiles WHERE id = ?");
    q.addBindValue(id);
    q.exec();
    if (q.next())
        return {q.value(0).toString(), q.value(1).toString(), q.value(2).toString()};
    return {};
}

void AppDatabase::insertTileProfile(const QString& id, const QString& name, const QString& siteId) {
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO tile_profiles (id, name, site_id) VALUES (?, ?, ?)");
    q.addBindValue(id);
    q.addBindValue(name);
    q.addBindValue(siteId);
    q.exec();
}

void AppDatabase::renameTileProfile(const QString& id, const QString& name) {
    QSqlQuery q(m_db);
    q.prepare("UPDATE tile_profiles SET name = ? WHERE id = ?");
    q.addBindValue(name);
    q.addBindValue(id);
    q.exec();
}

void AppDatabase::deleteTileProfile(const QString& id) {
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM tile_profiles WHERE id = ?");
    q.addBindValue(id);
    q.exec();
}

// - Tile formations -

QList<TileFormationRecord> AppDatabase::loadTileFormations(const QString& profileId) const {
    QSqlQuery q(m_db);
    q.prepare("SELECT id, profile_id, col, row, col_span, row_span "
              "FROM tile_formations WHERE profile_id = ?");
    q.addBindValue(profileId);
    q.exec();
    QList<TileFormationRecord> rows;
    while (q.next())
        rows.append({q.value(0).toString(), q.value(1).toString(),
                     q.value(2).toInt(), q.value(3).toInt(),
                     q.value(4).toInt(), q.value(5).toInt()});
    return rows;
}

void AppDatabase::insertTileFormation(const QString& id, const QString& profileId,
                                       int col, int row, int colSpan, int rowSpan) {
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO tile_formations (id, profile_id, col, row, col_span, row_span) "
              "VALUES (?, ?, ?, ?, ?, ?)");
    q.addBindValue(id);
    q.addBindValue(profileId);
    q.addBindValue(col);
    q.addBindValue(row);
    q.addBindValue(colSpan);
    q.addBindValue(rowSpan);
    q.exec();
}

void AppDatabase::updateTileFormation(const QString& id, int col, int row, int colSpan, int rowSpan) {
    QSqlQuery q(m_db);
    q.prepare("UPDATE tile_formations SET col = ?, row = ?, col_span = ?, row_span = ? WHERE id = ?");
    q.addBindValue(col);
    q.addBindValue(row);
    q.addBindValue(colSpan);
    q.addBindValue(rowSpan);
    q.addBindValue(id);
    q.exec();
}

void AppDatabase::deleteTileFormation(const QString& id) {
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM tile_formations WHERE id = ?");
    q.addBindValue(id);
    q.exec();
}

// - Camera bindings -

QList<TileCameraBindingRecord> AppDatabase::loadTileCameraBindings(const QString& profileId,
                                                                     const QString& siteId) const {
    QSqlQuery q(m_db);
    q.prepare("SELECT profile_id, tile_id, site_id, camera_id "
              "FROM tile_camera_bindings WHERE profile_id = ? AND site_id = ?");
    q.addBindValue(profileId);
    q.addBindValue(siteId);
    q.exec();
    QList<TileCameraBindingRecord> rows;
    while (q.next())
        rows.append({q.value(0).toString(), q.value(1).toString(),
                     q.value(2).toString(), q.value(3).toString()});
    return rows;
}

void AppDatabase::upsertTileCameraBinding(const QString& profileId, const QString& tileId,
                                           const QString& siteId, const QString& cameraId) {
    QSqlQuery q(m_db);
    q.prepare("INSERT OR REPLACE INTO tile_camera_bindings "
              "(profile_id, tile_id, site_id, camera_id) VALUES (?, ?, ?, ?)");
    q.addBindValue(profileId);
    q.addBindValue(tileId);
    q.addBindValue(siteId);
    q.addBindValue(cameraId);
    q.exec();
}

void AppDatabase::deleteTileFormationsForCamera(const QString& siteId, const QString& cameraId) {
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM tile_formations WHERE id IN "
              "(SELECT tile_id FROM tile_camera_bindings WHERE site_id = ? AND camera_id = ?)");
    q.addBindValue(siteId);
    q.addBindValue(cameraId);
    q.exec();
}

// - Profile–site assignments -

void AppDatabase::insertProfileSiteAssignment(const QString& profileId, const QString& siteId) {
    QSqlQuery q(m_db);
    q.prepare("INSERT OR IGNORE INTO profile_site_assignments (profile_id, site_id) VALUES (?, ?)");
    q.addBindValue(profileId);
    q.addBindValue(siteId);
    q.exec();
}
