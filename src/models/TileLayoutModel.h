// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QVariantMap>

class AppDatabase;

struct TileItem {
    QString id;
    int col = 0;
    int row = 0;
    int colSpan = 1;
    int rowSpan = 1;
    QString cameraId;
};

class TileLayoutModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QString activeProfileId READ activeProfileId WRITE setActiveProfileId
               NOTIFY activeProfileChanged)
    Q_PROPERTY(QString activeSiteId READ activeSiteId WRITE setActiveSiteId
               NOTIFY activeSiteChanged)
    Q_PROPERTY(int maxOccupiedRow READ maxOccupiedRow NOTIFY layoutChanged)
    Q_PROPERTY(QStringList assignedCameraIds READ assignedCameraIds NOTIFY layoutChanged)

  public:
    enum Role {
        TileIdRole = Qt::UserRole + 1,
        TileColRole,
        TileRowRole,
        TileColSpanRole,
        TileRowSpanRole,
        TileCameraIdRole,
    };
    Q_ENUM(Role)

    explicit TileLayoutModel(AppDatabase* db, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString activeProfileId() const { return m_activeProfileId; }
    void setActiveProfileId(const QString& id);
    QString activeSiteId() const { return m_activeSiteId; }
    void setActiveSiteId(const QString& id);
    int maxOccupiedRow() const;
    QStringList assignedCameraIds() const;

    Q_INVOKABLE QString addTile();
    Q_INVOKABLE void removeTile(const QString& tileId);
    Q_INVOKABLE void moveTile(const QString& tileId, int col, int row);
    // For placing a newly-created tile (see MatrixView.qml's grid drop
    // handler): unlike moveTile(), pushes tiles in the way to the right
    // (cascading) instead of rejecting on overlap.
    Q_INVOKABLE void moveTileWithPush(const QString& tileId, int col, int row);
    Q_INVOKABLE void resizeTile(const QString& tileId, int colSpan, int rowSpan);
    Q_INVOKABLE void assignCamera(const QString& tileId, const QString& cameraId);
    Q_INVOKABLE void clearCamera(const QString& tileId);

    // Called when a camera is deleted. Sweeps every profile on the active
    // site in the database (not just the one currently loaded), then updates
    // the in-memory list too so the visible profile reflects it immediately.
    Q_INVOKABLE void removeTilesForCamera(const QString& cameraId);

    Q_INVOKABLE bool hasCameraAssigned(const QString& cameraId) const;
    Q_INVOKABLE QString tileIdAt(int row) const;
    Q_INVOKABLE QVariantMap tileById(const QString& tileId) const;
    Q_INVOKABLE QStringList profileIds() const;
    Q_INVOKABLE QString profileName(const QString& profileId) const;
    Q_INVOKABLE QString createProfile(const QString& name);
    Q_INVOKABLE void renameProfile(const QString& profileId, const QString& name);
    Q_INVOKABLE void deleteProfile(const QString& profileId);
    Q_INVOKABLE void assignProfileToSite(const QString& profileId, const QString& siteId);

  signals:
    void activeProfileChanged();
    void activeSiteChanged();
    void tileAdded(const QString& tileId);
    void tileRemoved(const QString& tileId);
    void layoutChanged();

  private:
    void loadTiles();
    bool wouldOverlap(const QString& excludeId, int col, int row, int colSpan, int rowSpan) const;
    int tileIndex(const QString& tileId) const;
    // Grows m_tiles[idx]'s colSpan toward requestedColSpan, cascading a push
    // to any tile(s) blocking it (transitively), clamped to the largest
    // growth that fits within the grid's right edge.
    void growColSpanWithPush(int idx, int requestedColSpan);
    // Pushes tiles blocking [col, row, colSpan, rowSpan] to the right,
    // cascading transitively; excludeIdx is the tile being placed, which is
    // never its own blocker. Returns false without applying anything if any
    // affected tile would be pushed past the grid's right edge.
    bool pushTilesForInsert(int excludeIdx, int col, int row, int colSpan, int rowSpan);

    AppDatabase* m_db;
    QString m_activeProfileId;
    QString m_activeSiteId;
    QList<TileItem> m_tiles;
};
