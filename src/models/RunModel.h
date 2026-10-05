// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include "ApiTypes.h"
#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class SiteManager;

class RunModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
  public:
    enum Role {
        RunIdRole = Qt::UserRole + 1,
        RunStatusRole,
        RunTriggerTypeRole,
        RunTriggeredAtRole,
        RunCompletedAtRole,
        RunErrorRole,
    };
    Q_ENUM(Role)

    explicit RunModel(SiteManager* siteManager, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool loading() const { return m_loading; }

    Q_INVOKABLE void refresh(const QString& pipelineId, int limit = 50);
    Q_INVOKABLE void startPolling(const QString& pipelineId);
    Q_INVOKABLE void stopPolling();
    Q_INVOKABLE QVariantList nodeResultsForRun(const QString& runId) const;
    // Live lookup for a run already loaded into this model. Used to refresh
    // a Run Detail page's summary as polling brings in new data, rather than
    // the caller holding a static copy from when the page first opened.
    Q_INVOKABLE QVariantMap runById(const QString& runId) const;

    // Test-only: inserts/clears rows directly, bypassing the network round
    // trip refresh() normally requires. See CameraModel::insertTestCamera/
    // clearTestCameras for the pattern; nodeResults is a list of
    // {nodeId, status, startedAt, completedAt, output, error} maps.
    Q_INVOKABLE void insertTestRun(const QString& runId, const QString& status,
                                   const QString& error, const QVariantList& nodeResults);
    Q_INVOKABLE void clearTestRuns();

  signals:
    void loadingChanged();
    void countChanged();

  private:
    static RunDto fromJson(const QJsonObject& obj, const QString& nodeId);
    static NodeResultDto nodeResultFromJson(const QJsonObject& obj);
    void setLoading(bool v);
    bool hasActiveRuns() const;

    SiteManager* m_siteManager;
    QList<RunDto> m_runs;
    QString m_currentPipelineId;
    QString m_pollingPipelineId;
    QTimer m_pollTimer;
    bool m_loading = false;
};
