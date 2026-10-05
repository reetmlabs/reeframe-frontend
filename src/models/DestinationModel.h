// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include "ApiTypes.h"
#include <QAbstractListModel>
#include <QList>
#include <QMetaObject>
#include <QVariantList>
#include <QVariantMap>

class SiteManager;

class DestinationModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
  public:
    enum Role {
        DestIdRole = Qt::UserRole + 1,
        DestNameRole,
        DestTypeRole,
        DestEnabledRole,
    };
    Q_ENUM(Role)

    explicit DestinationModel(SiteManager* siteManager, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool loading() const { return m_loading; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void createDestination(const QString& name, const QString& type,
                                       const QVariantMap& config);
    Q_INVOKABLE void updateDestination(const QString& id, const QString& name, const QString& type,
                                       const QVariantMap& config);
    Q_INVOKABLE void deleteDestination(const QString& id);

    // Flat [{id, name, subtitle, type}] list for the pipeline editor's
    // Transport picker. See SourceModel::searchableEntries for the shared
    // {id, name, subtitle} shape this mirrors. `type` is the same value as
    // `subtitle` (there's no separate display string), kept under its own
    // key so callers matching on it aren't coupled to what's shown on screen.
    Q_INVOKABLE QVariantList searchableEntries() const;

    // For the Edit dialog to pre-fill from. Config's credential fields are
    // masked, never the real value (see DestinationDto::config).
    Q_INVOKABLE QVariantMap destinationById(const QString& id) const;

    // Test-only: inserts/clears rows directly, bypassing the network round
    // trip refresh()/deleteDestination() normally require. See
    // CameraModel::insertTestCamera/clearTestCameras for the pattern.
    Q_INVOKABLE void insertTestDestination(const QString& id, const QString& name,
                                           const QString& type = QString(),
                                           const QVariantMap& config = {});
    Q_INVOKABLE void clearTestDestinations();

  signals:
    void loadingChanged();
    void countChanged();
    void createDestinationSucceeded();
    void createDestinationFailed(const QString& message);
    void updateDestinationSucceeded();
    void updateDestinationFailed(const QString& message);
    void deleteDestinationFailed(const QString& id, const QString& message);

  private:
    static DestinationDto fromJson(const QJsonObject& obj, const QString& nodeId);
    void setLoading(bool v);
    void onActiveSiteChanged();

    SiteManager* m_siteManager;
    QList<DestinationDto> m_destinations;
    bool m_loading = false;
    // See CameraModel::m_sessionConnection for why this exists: the active
    // site's own token exchange is still in flight when activeSiteChanged
    // fires, so the first refresh() often 401s before a session exists yet.
    QMetaObject::Connection m_sessionConnection;
};
