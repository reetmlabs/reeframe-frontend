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

class SourceModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
  public:
    enum Role {
        SourceIdRole = Qt::UserRole + 1,
        SourceNameRole,
        SourceTypeRole,
        SourceEnabledRole,
    };
    Q_ENUM(Role)

    explicit SourceModel(SiteManager* siteManager, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool loading() const { return m_loading; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void createSource(const QString& name, const QString& type,
                                  const QVariantMap& config);
    Q_INVOKABLE void updateSource(const QString& id, const QString& name, const QString& type,
                                  const QVariantMap& config);
    Q_INVOKABLE void deleteSource(const QString& id);
    Q_INVOKABLE int sourceIndexById(const QString& id) const;

    // Flat [{id, name, subtitle}] list for the global command palette.
    // See CameraModel::searchableEntries for the shared shape this mirrors.
    Q_INVOKABLE QVariantList searchableEntries() const;

    // For the Edit dialog to pre-fill from. Config's credential fields are
    // masked, never the real value (see SourceDto::config).
    Q_INVOKABLE QVariantMap sourceById(const QString& id) const;

    // Test-only: inserts/clears rows directly, bypassing the network round
    // trip refresh()/deleteSource() normally require. See
    // CameraModel::insertTestCamera/clearTestCameras for the pattern.
    Q_INVOKABLE void insertTestSource(const QString& id, const QString& name,
                                      const QString& type = QString(),
                                      const QVariantMap& config = {});
    Q_INVOKABLE void clearTestSources();

  signals:
    void loadingChanged();
    void countChanged();
    void createSourceSucceeded();
    void createSourceFailed(const QString& message);
    void updateSourceSucceeded();
    void updateSourceFailed(const QString& message);
    void deleteSourceFailed(const QString& id, const QString& message);

  private:
    static SourceDto fromJson(const QJsonObject& obj, const QString& nodeId);
    void setLoading(bool v);
    void onActiveSiteChanged();

    SiteManager* m_siteManager;
    QList<SourceDto> m_sources;
    bool m_loading = false;
    // See CameraModel::m_sessionConnection for why this exists: the active
    // site's own token exchange is still in flight when activeSiteChanged
    // fires, so the first refresh() often 401s before a session exists yet.
    QMetaObject::Connection m_sessionConnection;
};
