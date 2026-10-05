// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QList>
#include <QObject>
#include <QSqlDatabase>
#include <QString>

struct SiteRecord {
    QString id;
    QString name;
    qint64 createdAt;
};

struct NodeRecord {
    QString id;
    QString siteId;
    QString url;
    qint64 createdAt;
};

struct MatrixProfileRecord {
    QString id;
    QString name;
    QString layout; // JSON blob
    qint64 createdAt;
};

struct TileProfileRecord {
    QString id;
    QString name;
    QString siteId;
};

struct TileFormationRecord {
    QString id;
    QString profileId;
    int col = 0;
    int row = 0;
    int colSpan = 1;
    int rowSpan = 1;
};

struct TileCameraBindingRecord {
    QString profileId;
    QString tileId;
    QString siteId;
    QString cameraId;
};

class AppDatabase : public QObject {
    Q_OBJECT
  public:
    explicit AppDatabase(QObject* parent = nullptr);
    ~AppDatabase();

    QList<SiteRecord> loadSites() const;
    void insertSite(const QString& id, const QString& name, qint64 createdAt);
    void deleteSite(const QString& id); // cascades to nodes

    QList<NodeRecord> loadNodes(const QString& siteId) const;
    void insertNode(const QString& id, const QString& siteId, const QString& url, qint64 createdAt);
    void deleteNode(const QString& id);

    QList<MatrixProfileRecord> loadMatrixProfiles() const;
    void insertMatrixProfile(const QString& id, const QString& name, const QString& layout,
                             qint64 createdAt);
    void updateMatrixProfileLayout(const QString& id, const QString& layout);
    void deleteMatrixProfile(const QString& id);

    // - Tile profiles -
    QList<TileProfileRecord> loadTileProfilesForSite(const QString& siteId) const;
    TileProfileRecord loadTileProfile(const QString& id) const;
    void insertTileProfile(const QString& id, const QString& name, const QString& siteId);
    void renameTileProfile(const QString& id, const QString& name);
    void deleteTileProfile(const QString& id); // cascades to formations + assignments

    // - Tile formations -
    QList<TileFormationRecord> loadTileFormations(const QString& profileId) const;
    void insertTileFormation(const QString& id, const QString& profileId,
                             int col, int row, int colSpan, int rowSpan);
    void updateTileFormation(const QString& id, int col, int row, int colSpan, int rowSpan);
    void deleteTileFormation(const QString& id); // cascades to camera bindings

    // - Camera bindings -
    QList<TileCameraBindingRecord> loadTileCameraBindings(const QString& profileId,
                                                           const QString& siteId) const;
    void upsertTileCameraBinding(const QString& profileId, const QString& tileId,
                                  const QString& siteId, const QString& cameraId);

    // Deletes every tile formation bound to cameraId on siteId, across all
    // profiles (not just whichever one is currently loaded into
    // TileLayoutModel). Cascades to their camera bindings via FK.
    void deleteTileFormationsForCamera(const QString& siteId, const QString& cameraId);

    // - Profile–site assignments -
    void insertProfileSiteAssignment(const QString& profileId, const QString& siteId);

    QString preference(const QString& key, const QString& defaultValue = {}) const;
    void setPreference(const QString& key, const QString& value);

  private:
    void migrate();
    void exec(const QString& sql);

    QSqlDatabase m_db;
};
