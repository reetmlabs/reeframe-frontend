// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QVariant>

class AppDatabase;

struct TileAssignment {
    int row = 0;
    int col = 0;
    int rowSpan = 1;
    int colSpan = 1;
    QString cameraId;
    QString tileType = "camera";
};

struct MatrixProfile {
    QString id;
    QString name;
    int rows = 2;
    int cols = 2;
    QList<TileAssignment> tiles;
};

class MatrixProfileModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int activeProfileIndex READ activeProfileIndex WRITE setActiveProfileIndex NOTIFY
                   activeProfileChanged)
    Q_PROPERTY(QString activeProfileId READ activeProfileId NOTIFY activeProfileChanged)
    Q_PROPERTY(int activeRows READ activeRows NOTIFY activeProfileChanged)
    Q_PROPERTY(int activeCols READ activeCols NOTIFY activeProfileChanged)
    Q_PROPERTY(QVariantList activeTiles READ activeTiles NOTIFY activeTilesChanged)
    Q_PROPERTY(int maxActiveStreams READ maxActiveStreams CONSTANT)
  public:
    enum Role {
        ProfileIdRole = Qt::UserRole + 1,
        ProfileNameRole,
        ProfileRowsRole,
        ProfileColsRole,
    };
    Q_ENUM(Role)

    explicit MatrixProfileModel(AppDatabase* db, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int activeProfileIndex() const { return m_activeIndex; }
    void setActiveProfileIndex(int i);
    QString activeProfileId() const;
    int activeRows() const;
    int activeCols() const;
    QVariantList activeTiles() const;
    int maxActiveStreams() const { return 16; }

    Q_INVOKABLE QString addProfile(const QString& name, int rows, int cols);
    Q_INVOKABLE void removeProfile(const QString& profileId);
    Q_INVOKABLE void assignCamera(const QString& profileId, int row, int col,
                                  const QString& cameraId);
    Q_INVOKABLE void clearCell(const QString& profileId, int row, int col);

  signals:
    void activeProfileChanged();
    void activeTilesChanged();

  private:
    void createDefaultProfile();
    void persistProfile(const MatrixProfile& profile);
    static QString profileToJson(const MatrixProfile& profile);
    static MatrixProfile profileFromRecord(const QString& id, const QString& name,
                                           const QString& json);
    int profileIndexById(const QString& id) const;

    AppDatabase* m_db;
    QList<MatrixProfile> m_profiles;
    int m_activeIndex = 0;
};
