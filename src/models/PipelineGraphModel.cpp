// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "PipelineGraphModel.h"
#include "SiteManager.h"
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRestReply>
#include <QUuid>

// The QML canvas uses its own edge-type vocabulary (normal/condition_true/
// condition_false) for rendering; the backend's EdgeType enum wire values
// are default/true_branch/false_branch. Translate at this boundary rather
// than push backend vocabulary into the QML layer.
static QString edgeTypeToWire(const QString& t) {
    if (t == "condition_true")
        return QStringLiteral("true_branch");
    if (t == "condition_false")
        return QStringLiteral("false_branch");
    return QStringLiteral("default");
}

static QString edgeTypeFromWire(const QString& t) {
    if (t == "true_branch")
        return QStringLiteral("condition_true");
    if (t == "false_branch")
        return QStringLiteral("condition_false");
    return QStringLiteral("normal");
}

// reply.errorString() is transport-level only (empty for an ordinary non-2xx
// reply). The real reason lives in the JSON body's "error" field.
static QString describeFailure(QRestReply& reply) {
    const auto doc = reply.readJson();
    const QString message =
        doc && doc->isObject() ? doc->object().value("error").toString() : QString{};
    return QStringLiteral("HTTP %1%2")
        .arg(reply.httpStatus())
        .arg(message.isEmpty() ? QString{} : QStringLiteral(" - ") + message);
}

PipelineGraphModel::PipelineGraphModel(SiteManager* siteManager, QObject* parent)
    : QObject(parent), m_siteManager(siteManager) {}

QVariantList PipelineGraphModel::nodes() const {
    QVariantList out;
    out.reserve(m_nodes.size());
    for (const auto& n : m_nodes)
        out.append(nodeToVariant(n));
    return out;
}

QVariantList PipelineGraphModel::edges() const {
    QVariantList out;
    out.reserve(m_edges.size());
    for (const auto& e : m_edges)
        out.append(edgeToVariant(e));
    return out;
}

void PipelineGraphModel::load(const QString& pipelineId) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    setLoading(true);
    if (m_pipelineId != pipelineId) {
        m_pipelineId = pipelineId;
        emit pipelineIdChanged();
    }
    m_deletedNodeIds.clear();
    m_deletedEdgeIds.clear();

    client->get("/pipelines/" + pipelineId + "/nodes", this, [this, pipelineId](QRestReply& reply) {
        if (!reply.isSuccess()) {
            setLoading(false);
            emit loadFailed(describeFailure(reply));
            return;
        }
        const auto doc = reply.readJson();
        QList<PipelineNodeDto> nodes;
        if (doc && doc->isArray()) {
            for (const auto& v : doc->array())
                nodes.append(nodeFromJson(v.toObject()));
        }
        m_nodes = std::move(nodes);
        emit nodesChanged();

        auto* client2 = m_siteManager->clientForSite(m_siteManager->activeSiteId());
        if (!client2) {
            setLoading(false);
            return;
        }
        client2->get("/pipelines/" + pipelineId + "/edges", this, [this, pipelineId](QRestReply& reply2) {
            if (!reply2.isSuccess()) {
                setLoading(false);
                emit loadFailed(describeFailure(reply2));
                return;
            }
            const auto doc2 = reply2.readJson();
            QList<PipelineEdgeDto> edges;
            if (doc2 && doc2->isArray()) {
                for (const auto& v : doc2->array())
                    edges.append(edgeFromJson(v.toObject()));
            }
            m_edges = std::move(edges);
            emit edgesChanged();

            // A trigger_root node's real config lives in a separate resource
            // (see addTypeSpecificFields()'s doc comment on the trigger_root
            // branch). Merge it into that node once both nodes and edges
            // are in hand.
            auto* client3 = m_siteManager->clientForSite(m_siteManager->activeSiteId());
            if (!client3) {
                setLoading(false);
                return;
            }
            client3->get("/pipelines/" + pipelineId + "/triggers", this, [this](QRestReply& reply3) {
                setLoading(false);
                if (!reply3.isSuccess()) {
                    emit loadFailed(describeFailure(reply3));
                    return;
                }
                const auto doc3 = reply3.readJson();
                if (doc3 && doc3->isArray() && !doc3->array().isEmpty()) {
                    const QVariantMap cfg = triggerConfigFromJson(doc3->array().at(0).toObject());
                    for (auto& n : m_nodes) {
                        if (n.type == "trigger_root") {
                            n.config = cfg;
                            break;
                        }
                    }
                    emit nodesChanged();
                }
                setDirty(false);
            });
        });
    });
}

// Persists the local graph against the real per-node/per-edge REST CRUD the
// backend actually exposes (there is no single "whole graph" endpoint):
// PATCH for nodes/edges already on the server, POST for ones added locally
// (capturing the server-assigned id and rewriting any edge that referenced
// the node's old local id), DELETE for ones removed locally. Steps run
// sequentially, not in parallel, so a newly created node's real id exists
// before any edge referencing it is sent.
void PipelineGraphModel::save() {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client || m_pipelineId.isEmpty()) {
        emit saveFailed(QStringLiteral("no active site session"));
        return;
    }
    setLoading(true);

    QList<SaveStep> steps;

    for (int i = 0; i < m_nodes.size(); ++i) {
        steps.append([this, i](std::function<void()> next, std::function<void(QString)> fail) {
            auto* c = m_siteManager->clientForSite(m_siteManager->activeSiteId());
            if (!c) {
                fail(QStringLiteral("no active site session"));
                return;
            }
            PipelineNodeDto& n = m_nodes[i];
            if (n.persisted) {
                QJsonObject body = nodeToJson(n);
                addTypeSpecificFields(body, n);
                c->patch("/pipelines/" + m_pipelineId + "/nodes/" + n.id, QJsonDocument(body),
                         this, [next, fail](QRestReply& reply) {
                             if (reply.isSuccess())
                                 next();
                             else
                                 fail(describeFailure(reply));
                         });
                return;
            }
            QJsonObject body = nodeToJson(n);
            body["node_type"] = n.type;
            addTypeSpecificFields(body, n);
            c->post("/pipelines/" + m_pipelineId + "/nodes", QJsonDocument(body), this,
                    [this, i, next, fail](QRestReply& reply) {
                        if (!reply.isSuccess()) {
                            fail(describeFailure(reply));
                            return;
                        }
                        const auto doc = reply.readJson();
                        const QString newId =
                            doc && doc->isObject() ? doc->object().value("id").toString() : QString{};
                        if (newId.isEmpty()) {
                            fail(QStringLiteral("create response missing id"));
                            return;
                        }
                        const QString oldId = m_nodes[i].id;
                        m_nodes[i].id = newId;
                        m_nodes[i].persisted = true;
                        for (auto& e : m_edges) {
                            if (e.fromNodeId == oldId)
                                e.fromNodeId = newId;
                            if (e.toNodeId == oldId)
                                e.toNodeId = newId;
                        }
                        next();
                    });
        });
    }

    for (const QString& id : m_deletedNodeIds) {
        steps.append([this, id](std::function<void()> next, std::function<void(QString)> fail) {
            auto* c = m_siteManager->clientForSite(m_siteManager->activeSiteId());
            if (!c) {
                fail(QStringLiteral("no active site session"));
                return;
            }
            c->del("/pipelines/" + m_pipelineId + "/nodes/" + id, this,
                  [next, fail](QRestReply& reply) {
                      if (reply.isSuccess())
                          next();
                      else
                          fail(describeFailure(reply));
                  });
        });
    }

    for (int i = 0; i < m_edges.size(); ++i) {
        steps.append([this, i](std::function<void()> next, std::function<void(QString)> fail) {
            auto* c = m_siteManager->clientForSite(m_siteManager->activeSiteId());
            if (!c) {
                fail(QStringLiteral("no active site session"));
                return;
            }
            PipelineEdgeDto& e = m_edges[i];
            if (e.persisted) {
                c->patch("/pipelines/" + m_pipelineId + "/edges/" + e.id, QJsonDocument(edgeToJson(e)),
                         this, [next, fail](QRestReply& reply) {
                             if (reply.isSuccess())
                                 next();
                             else
                                 fail(describeFailure(reply));
                         });
                return;
            }
            c->post("/pipelines/" + m_pipelineId + "/edges", QJsonDocument(edgeToJson(e)), this,
                    [this, i, next, fail](QRestReply& reply) {
                        if (!reply.isSuccess()) {
                            fail(describeFailure(reply));
                            return;
                        }
                        const auto doc = reply.readJson();
                        const QString newId =
                            doc && doc->isObject() ? doc->object().value("id").toString() : QString{};
                        if (newId.isEmpty()) {
                            fail(QStringLiteral("create response missing id"));
                            return;
                        }
                        m_edges[i].id = newId;
                        m_edges[i].persisted = true;
                        next();
                    });
        });
    }

    for (const QString& id : m_deletedEdgeIds) {
        steps.append([this, id](std::function<void()> next, std::function<void(QString)> fail) {
            auto* c = m_siteManager->clientForSite(m_siteManager->activeSiteId());
            if (!c) {
                fail(QStringLiteral("no active site session"));
                return;
            }
            c->del("/pipelines/" + m_pipelineId + "/edges/" + id, this,
                  [next, fail](QRestReply& reply) {
                      if (reply.isSuccess())
                          next();
                      else
                          fail(describeFailure(reply));
                  });
        });
    }

    if (steps.isEmpty()) {
        setLoading(false);
        setDirty(false);
        emit saveSucceeded();
        return;
    }
    runSaveSteps(steps, 0);
}

void PipelineGraphModel::runSaveSteps(QList<SaveStep> steps, int index) {
    if (index >= steps.size()) {
        setLoading(false);
        m_deletedNodeIds.clear();
        m_deletedEdgeIds.clear();
        setDirty(false);
        emit nodesChanged();
        emit edgesChanged();
        emit saveSucceeded();
        return;
    }
    steps[index](
        [this, steps, index]() mutable { runSaveSteps(steps, index + 1); },
        [this](QString error) {
            setLoading(false);
            emit saveFailed(error);
        });
}

QString PipelineGraphModel::addNode(const QString& type, double x, double y) {
    PipelineNodeDto n;
    n.id = "node-" + QUuid::createUuid().toString(QUuid::WithoutBraces);
    n.type = type;
    n.label = type;
    n.x = x;
    n.y = y;
    m_nodes.append(n);
    emit nodesChanged();
    setDirty(true);
    return n.id;
}

void PipelineGraphModel::removeNode(const QString& nodeId) {
    const int i = nodeIndex(nodeId);
    if (i < 0)
        return;
    if (m_nodes.at(i).persisted)
        m_deletedNodeIds.append(nodeId);
    m_nodes.removeAt(i);
    // Deleting a node cascades to its edges server-side, so edges dropped
    // here purely because they referenced this node don't need their own
    // DELETE queued; only removeEdge()'s direct removals do.
    const int before = m_edges.size();
    m_edges.removeIf(
        [&nodeId](const PipelineEdgeDto& e) { return e.fromNodeId == nodeId || e.toNodeId == nodeId; });
    emit nodesChanged();
    if (m_edges.size() != before)
        emit edgesChanged();
    setDirty(true);
}

void PipelineGraphModel::moveNode(const QString& nodeId, double x, double y) {
    const int i = nodeIndex(nodeId);
    if (i < 0)
        return;
    m_nodes[i].x = x;
    m_nodes[i].y = y;
    emit nodesChanged();
    setDirty(true);
}

void PipelineGraphModel::updateNodeLabel(const QString& nodeId, const QString& label) {
    const int i = nodeIndex(nodeId);
    if (i < 0)
        return;
    m_nodes[i].label = label;
    emit nodesChanged();
    setDirty(true);
}

void PipelineGraphModel::updateNodeConfig(const QString& nodeId, const QVariantMap& config) {
    const int i = nodeIndex(nodeId);
    if (i < 0)
        return;
    m_nodes[i].config = config;
    emit nodesChanged();
    setDirty(true);
}

QString PipelineGraphModel::addEdge(const QString& fromNodeId, const QString& toNodeId,
                                    const QString& edgeType) {
    if (fromNodeId == toNodeId)
        return {};
    for (const auto& e : m_edges) {
        if (e.fromNodeId == fromNodeId && e.toNodeId == toNodeId && e.edgeType == edgeType)
            return {};
    }
    PipelineEdgeDto e;
    e.id = "edge-" + QUuid::createUuid().toString(QUuid::WithoutBraces);
    e.fromNodeId = fromNodeId;
    e.toNodeId = toNodeId;
    e.edgeType = edgeType;
    m_edges.append(e);
    emit edgesChanged();
    setDirty(true);
    return e.id;
}

void PipelineGraphModel::removeEdge(const QString& edgeId) {
    const int i = edgeIndex(edgeId);
    if (i < 0)
        return;
    if (m_edges.at(i).persisted)
        m_deletedEdgeIds.append(edgeId);
    m_edges.removeAt(i);
    emit edgesChanged();
    setDirty(true);
}

QVariantMap PipelineGraphModel::nodeById(const QString& nodeId) const {
    const int i = nodeIndex(nodeId);
    if (i < 0)
        return {};
    return nodeToVariant(m_nodes.at(i));
}

PipelineNodeDto PipelineGraphModel::nodeFromJson(const QJsonObject& obj) {
    PipelineNodeDto n;
    n.id = obj["id"].toString();
    n.type = obj["node_type"].toString();
    n.label = obj["label"].toString();
    if (n.type == "action" || n.type == "device_control") {
        if (obj["action_config"].isObject())
            n.config = obj["action_config"].toObject().toVariantMap();
    } else if (n.type == "transport") {
        QVariantMap cfg;
        if (obj["transport_config"].isObject())
            cfg = obj["transport_config"].toObject().toVariantMap();
        const QString destId = obj["destination_id"].toString();
        if (!destId.isEmpty())
            cfg["destination_id"] = destId;
        const QString contactListId = obj["contact_list_id"].toString();
        if (!contactListId.isEmpty())
            cfg["contact_list_id"] = contactListId;
        n.config = cfg;
    } else if (n.type == "condition") {
        const QString expr = obj["condition_expr"].toString();
        if (!expr.isEmpty())
            n.config = QVariantMap{{"condition_expr", expr}};
    }
    n.x = obj["pos_x"].toDouble();
    n.y = obj["pos_y"].toDouble();
    n.persisted = true;
    return n;
}

PipelineEdgeDto PipelineGraphModel::edgeFromJson(const QJsonObject& obj) {
    PipelineEdgeDto e;
    e.id = obj["id"].toString();
    e.fromNodeId = obj["from_node_id"].toString();
    e.toNodeId = obj["to_node_id"].toString();
    e.edgeType = edgeTypeFromWire(obj["edge_type"].toString());
    e.persisted = true;
    return e;
}

QVariantMap PipelineGraphModel::nodeToVariant(const PipelineNodeDto& n) {
    return {{"id", n.id},
            {"type", n.type},
            {"label", n.label},
            {"config", n.config},
            {"x", n.x},
            {"y", n.y}};
}

QVariantMap PipelineGraphModel::edgeToVariant(const PipelineEdgeDto& e) {
    return {{"id", e.id},
            {"fromNodeId", e.fromNodeId},
            {"toNodeId", e.toNodeId},
            {"edgeType", e.edgeType}};
}

// Shared PATCH/POST body fields. node_type (POST-only, immutable after
// creation) and the type-specific fields from addTypeSpecificFields() are
// layered on top of this by save().
QJsonObject PipelineGraphModel::nodeToJson(const PipelineNodeDto& n) const {
    QJsonObject obj;
    obj["label"] = n.label;
    obj["pos_x"] = n.x;
    obj["pos_y"] = n.y;
    return obj;
}

// The backend keys node config by node type rather than accepting one
// generic blob: action/device_control nodes carry a typed, internally-
// tagged action_config (the config panel already builds it in that exact
// {action_type, ...fields} wire shape); transport nodes reference a
// pre-created Destination by id plus an optional nested transport_config of
// minijinja template overrides; condition nodes carry a flat condition_expr
// string; a trigger_root node's trigger config isn't a node field at all:
// saving it here transparently creates/updates the pipeline's one row in the
// separate pipeline_triggers resource (see PipelineRepo::upsert_node_trigger
// on the backend), which is what the resource manager and trigger evaluator
// actually consult.
void PipelineGraphModel::addTypeSpecificFields(QJsonObject& body, const PipelineNodeDto& n) {
    if (n.type == "action" || n.type == "device_control") {
        if (!n.config.isEmpty())
            body["action_config"] = QJsonObject::fromVariantMap(n.config);
    } else if (n.type == "transport") {
        const QString destId = n.config.value("destination_id").toString();
        if (!destId.isEmpty())
            body["destination_id"] = destId;
        const QString contactListId = n.config.value("contact_list_id").toString();
        if (!contactListId.isEmpty())
            body["contact_list_id"] = contactListId;

        QJsonObject transportCfg;
        static const QStringList templateKeys = {
            QStringLiteral("path_template"),
            QStringLiteral("filename_template"),
            QStringLiteral("message_template"),
        };
        for (const auto& key : templateKeys) {
            const QString v = n.config.value(key).toString();
            if (!v.isEmpty())
                transportCfg[key] = v;
        }
        if (!transportCfg.isEmpty())
            body["transport_config"] = transportCfg;
    } else if (n.type == "condition") {
        const QString expr = n.config.value("condition_expr").toString();
        if (!expr.isEmpty())
            body["condition_expr"] = expr;
    } else if (n.type == "trigger_root") {
        const QString triggerType = n.config.value("trigger_type").toString();
        if (!triggerType.isEmpty()) {
            QJsonObject cfg;
            cfg["trigger_type"] = triggerType;
            QJsonObject trigger;

            if (triggerType == "schedule") {
                QJsonObject mode;
                mode["mode"] = "cron";
                mode["expression"] = n.config.value("cron").toString();
                cfg["mode"] = mode;
                const QString tz = n.config.value("timezone").toString();
                if (!tz.isEmpty())
                    cfg["timezone"] = tz;
            } else if (triggerType == "event") {
                cfg["filter"] = n.config.value("filter").toString();
                const QString srcId = n.config.value("source_id").toString();
                if (!srcId.isEmpty())
                    trigger["source_id"] = srcId;
            } else if (triggerType == "stat") {
                static const QHash<QString, QString> metricToWire = {
                    {"disk", "disk_usage_percent"},
                    {"ram", "ram_usage_percent"},
                    {"cpu", "cpu_usage_percent"},
                };
                cfg["metric"] =
                    metricToWire.value(n.config.value("metric").toString(), "disk_usage_percent");
                cfg["operator"] = "greater_than";
                cfg["threshold"] = n.config.value("threshold_pct").toDouble();
                cfg["cooldown_secs"] = n.config.value("cooldown_secs").toInt();
            }
            // manual: no further fields.

            trigger["config"] = cfg;
            trigger["enabled"] = true;
            body["trigger"] = trigger;
        }
    }
}

QVariantMap PipelineGraphModel::triggerConfigFromJson(const QJsonObject& t) {
    QVariantMap cfg;
    const QJsonObject config = t.value("config").toObject();
    const QString triggerType = config.value("trigger_type").toString();
    cfg["trigger_type"] = triggerType;

    if (triggerType == "schedule") {
        const QJsonObject mode = config.value("mode").toObject();
        if (mode.value("mode").toString() == "cron")
            cfg["cron"] = mode.value("expression").toString();
        const QString tz = config.value("timezone").toString();
        if (!tz.isEmpty())
            cfg["timezone"] = tz;
    } else if (triggerType == "event") {
        cfg["filter"] = config.value("filter").toString();
        const QString srcId = t.value("source_id").toString();
        if (!srcId.isEmpty())
            cfg["source_id"] = srcId;
    } else if (triggerType == "stat") {
        static const QHash<QString, QString> metricFromWire = {
            {"disk_usage_percent", "disk"},
            {"ram_usage_percent", "ram"},
            {"cpu_usage_percent", "cpu"},
        };
        cfg["metric"] = metricFromWire.value(config.value("metric").toString(), "disk");
        cfg["threshold_pct"] = config.value("threshold").toDouble();
        cfg["cooldown_secs"] = config.value("cooldown_secs").toInt();
    }
    // manual: no further fields.

    return cfg;
}

QJsonObject PipelineGraphModel::edgeToJson(const PipelineEdgeDto& e) const {
    QJsonObject obj;
    obj["from_node_id"] = e.fromNodeId;
    obj["to_node_id"] = e.toNodeId;
    obj["edge_type"] = edgeTypeToWire(e.edgeType);
    return obj;
}

void PipelineGraphModel::setDirty(bool v) {
    if (m_dirty == v)
        return;
    m_dirty = v;
    emit dirtyChanged();
}

void PipelineGraphModel::setLoading(bool v) {
    if (m_loading == v)
        return;
    m_loading = v;
    emit loadingChanged();
}

int PipelineGraphModel::nodeIndex(const QString& nodeId) const {
    for (int i = 0; i < m_nodes.size(); ++i)
        if (m_nodes.at(i).id == nodeId)
            return i;
    return -1;
}

int PipelineGraphModel::edgeIndex(const QString& edgeId) const {
    for (int i = 0; i < m_edges.size(); ++i)
        if (m_edges.at(i).id == edgeId)
            return i;
    return -1;
}
