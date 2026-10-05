// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include "ApiTypes.h"
#include <QAbstractListModel>
#include <QList>
#include <QVariantList>
#include <QVariantMap>

class SiteManager;

class PipelineModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
  public:
    enum Role {
        PipelineIdRole = Qt::UserRole + 1,
        PipelineNameRole,
        PipelineDescriptionRole,
        PipelineTypeRole,
        PipelineEnabledRole,
        PipelineCreatedAtRole,
        PipelineUpdatedAtRole,
        PipelineValidationErrorCountRole,
        PipelineValidationWarningCountRole,
    };
    Q_ENUM(Role)

    explicit PipelineModel(SiteManager* siteManager, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool loading() const { return m_loading; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void createPipeline(const QString& name, const QString& description,
                                    const QString& type);
    Q_INVOKABLE void updatePipeline(const QString& id, const QString& name,
                                    const QString& description);
    Q_INVOKABLE void deletePipeline(const QString& id);
    Q_INVOKABLE void setEnabled(const QString& id, bool enabled);
    Q_INVOKABLE void triggerPipeline(const QString& id, const QVariantMap& params);
    Q_INVOKABLE QVariantMap pipelineById(const QString& id) const;
    Q_INVOKABLE int pipelineIndexById(const QString& id) const;

    // Flat [{id, name, subtitle}] list for the global command palette.
    // See CameraModel::searchableEntries for the shared shape this mirrors.
    Q_INVOKABLE QVariantList searchableEntries() const;

    // Test-only: inserts/clears rows directly, bypassing the network round
    // trip refresh()/deletePipeline() normally require. See
    // CameraModel::insertTestCamera/clearTestCameras for the pattern.
    Q_INVOKABLE void insertTestPipeline(const QString& id, const QString& name,
                                        int validationErrorCount = 0, int validationWarningCount = 0);
    Q_INVOKABLE void clearTestPipelines();

  signals:
    void loadingChanged();
    void countChanged();
    void enableRollback(const QString& id, bool previousValue, const QString& message);
    void triggered(const QString& pipelineId);
    void updatePipelineSucceeded(const QString& id, const QString& name, const QString& description);
    void updatePipelineFailed(const QString& message);
    void deletePipelineFailed(const QString& id, const QString& message);

  private:
    static PipelineDto fromJson(const QJsonObject& obj, const QString& nodeId);
    void setLoading(bool v);
    int indexById(const QString& id) const;

    SiteManager* m_siteManager;
    QList<PipelineDto> m_pipelines;
    bool m_loading = false;
};
