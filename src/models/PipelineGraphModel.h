// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include "ApiTypes.h"
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <functional>

class SiteManager;

class PipelineGraphModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList nodes READ nodes NOTIFY nodesChanged)
    Q_PROPERTY(QVariantList edges READ edges NOTIFY edgesChanged)
    Q_PROPERTY(QString pipelineId READ pipelineId NOTIFY pipelineIdChanged)
    Q_PROPERTY(bool dirty READ dirty NOTIFY dirtyChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

  public:
    explicit PipelineGraphModel(SiteManager* siteManager, QObject* parent = nullptr);

    QVariantList nodes() const;
    QVariantList edges() const;
    QString pipelineId() const { return m_pipelineId; }
    bool dirty() const { return m_dirty; }
    bool loading() const { return m_loading; }

    Q_INVOKABLE void load(const QString& pipelineId);
    Q_INVOKABLE void save();

    Q_INVOKABLE QString addNode(const QString& type, double x, double y);
    Q_INVOKABLE void removeNode(const QString& nodeId);
    Q_INVOKABLE void moveNode(const QString& nodeId, double x, double y);
    Q_INVOKABLE void updateNodeLabel(const QString& nodeId, const QString& label);
    Q_INVOKABLE void updateNodeConfig(const QString& nodeId, const QVariantMap& config);

    Q_INVOKABLE QString addEdge(const QString& fromNodeId, const QString& toNodeId,
                                const QString& edgeType);
    Q_INVOKABLE void removeEdge(const QString& edgeId);

    Q_INVOKABLE QVariantMap nodeById(const QString& nodeId) const;

  signals:
    void nodesChanged();
    void edgesChanged();
    void pipelineIdChanged();
    void dirtyChanged();
    void loadingChanged();
    void saveSucceeded();
    void saveFailed(const QString& error);
    void loadFailed(const QString& error);

  private:
    static PipelineNodeDto nodeFromJson(const QJsonObject& obj);
    static PipelineEdgeDto edgeFromJson(const QJsonObject& obj);
    static QVariantMap nodeToVariant(const PipelineNodeDto& n);
    static QVariantMap edgeToVariant(const PipelineEdgeDto& e);
    QJsonObject nodeToJson(const PipelineNodeDto& n) const;
    QJsonObject edgeToJson(const PipelineEdgeDto& e) const;
    static void addTypeSpecificFields(QJsonObject& body, const PipelineNodeDto& n);
    // Translates a PipelineTrigger JSON object (from GET /pipelines/{id}/triggers)
    // back into the flat, panel-local config shape TriggerConfigPanel.qml reads,
    // the inverse of addTypeSpecificFields()'s trigger_root branch.
    static QVariantMap triggerConfigFromJson(const QJsonObject& t);

    void setDirty(bool v);
    void setLoading(bool v);
    int nodeIndex(const QString& nodeId) const;
    int edgeIndex(const QString& edgeId) const;

    // Runs a queue of async steps one at a time (each step calls next() or
    // fail() when its own network call completes). save() needs its
    // node/edge POST|PATCH|DELETE calls to happen in dependency order
    // (nodes before the edges that reference them), which a fire-and-forget
    // batch of parallel requests can't guarantee.
    using SaveStep = std::function<void(std::function<void()> next, std::function<void(QString)> fail)>;
    void runSaveSteps(QList<SaveStep> steps, int index);

    SiteManager* m_siteManager;
    QString m_pipelineId;
    QList<PipelineNodeDto> m_nodes;
    QList<PipelineEdgeDto> m_edges;
    QStringList m_deletedNodeIds;
    QStringList m_deletedEdgeIds;
    bool m_dirty = false;
    bool m_loading = false;
};
