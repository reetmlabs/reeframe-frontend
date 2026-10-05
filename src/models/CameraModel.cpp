// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "CameraModel.h"
#include "BackendClient.h"
#include "LiveViewLogging.h"
#include "SiteManager.h"
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRestReply>

CameraModel::CameraModel(SiteManager* siteManager, QObject* parent)
    : QAbstractListModel(parent), m_siteManager(siteManager) {
    connect(siteManager, &SiteManager::activeSiteChanged, this, &CameraModel::onActiveSiteChanged);
    connect(this, &QAbstractItemModel::rowsInserted, this, &CameraModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &CameraModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &CameraModel::countChanged);
}

void CameraModel::onActiveSiteChanged() {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (client == m_statusConnectedClient) {
        refresh();
        return;
    }
    m_statusConnectedClient = client;

    QObject::disconnect(m_sessionConnection);
    QObject::disconnect(m_statusConnection);
    // A refresh() in flight against the previous site's client may never
    // reply if that client gets destroyed first, leaving loading stuck true.
    setLoading(false);
    if (client) {
        m_sessionConnection =
            connect(client, &BackendClient::sessionChanged, this, &CameraModel::refresh);
        m_statusConnection = connect(client, &BackendClient::statusChanged, this, [this, client] {
            qCDebug(lcLiveView) << "backend status" << client->status() << "wasDown" << m_wasDown;
            if (client->status() == BackendClient::Status::Error) {
                m_wasDown = true;
            } else if (client->status() == BackendClient::Status::Online) {
                const bool wasDown = m_wasDown;
                m_wasDown = false;
                refresh();
                if (wasDown) {
                    qCDebug(lcLiveView) << "backend recovered, requesting fresh relays";
                    emit backendRecovered();
                }
            }
        });
    }
    refresh();
}

int CameraModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : m_cameras.size();
}

QVariant CameraModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_cameras.size())
        return {};
    const auto& cam = m_cameras.at(index.row());
    switch (role) {
    case CameraIdRole:
        return cam.id;
    case CameraNameRole:
        return cam.name;
    case CameraLocationRole:
        return cam.location;
    case CameraEnabledRole:
        return cam.enabled;
    case CameraRtspUrlRole:
        return cam.rtspUrl;
    case CameraSubRtspUrlRole:
        return cam.subRtspUrl;
    case CameraUsernameRole:
        return cam.username;
    case CameraRecordingRole:
        return cam.recording;
    case CameraRelayUrlRole:
        return cam.relayUrl;
    case CameraMainRelayUrlRole:
        return cam.mainRelayUrl;
    case CameraCreatedAtRole:
        return cam.createdAt;
    default:
        return {};
    }
}

QHash<int, QByteArray> CameraModel::roleNames() const {
    return {
        {CameraIdRole, "cameraId"},
        {CameraNameRole, "cameraName"},
        {CameraLocationRole, "cameraLocation"},
        {CameraEnabledRole, "cameraEnabled"},
        {CameraRtspUrlRole, "cameraRtspUrl"},
        {CameraSubRtspUrlRole, "cameraSubRtspUrl"},
        {CameraUsernameRole, "cameraUsername"},
        {CameraRecordingRole, "cameraRecording"},
        {CameraRelayUrlRole, "cameraRelayUrl"},
        {CameraMainRelayUrlRole, "cameraMainRelayUrl"},
        {CameraCreatedAtRole, "cameraCreatedAt"},
    };
}

void CameraModel::refresh() {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    setLoading(true);
    const QString nodeId = client->nodeId();
    client->get("/cameras", this, [this, nodeId](QRestReply& reply) {
        setLoading(false);
        if (!reply.isSuccess())
            return;
        const auto doc = reply.readJson();
        if (!doc || !doc->isArray())
            return;
        QList<CameraDto> cameras;
        for (const auto& val : doc->array())
            cameras.append(fromJson(val.toObject(), nodeId));
        beginResetModel();
        m_cameras = std::move(cameras);
        endResetModel();
    });
}

void CameraModel::createCamera(const QString& name, const QString& location, const QString& rtspUrl,
                               const QString& subRtspUrl, const QString& username,
                               const QString& password, bool enabled) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client) {
        emit createCameraFailed(QStringLiteral("no active site session"));
        return;
    }
    QJsonObject obj;
    obj["name"] = name;
    obj["location"] = location;
    obj["rtsp_url"] = rtspUrl;
    obj["sub_rtsp_url"] = subRtspUrl;
    obj["username"] = username;
    obj["password"] = password;
    obj["enabled"] = enabled;
    client->post("/cameras", QJsonDocument(obj), this, [this](QRestReply& reply) {
        if (reply.isSuccess()) {
            refresh();
            emit createCameraSucceeded();
        } else {
            emit createCameraFailed(reply.errorString());
        }
    });
}

void CameraModel::updateCamera(const QString& id, const QString& name, const QString& location,
                               const QString& rtspUrl, const QString& subRtspUrl,
                               const QString& username, const QString& password, bool enabled) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    QJsonObject obj;
    obj["name"] = name;
    obj["location"] = location;
    obj["rtsp_url"] = rtspUrl;
    obj["sub_rtsp_url"] = subRtspUrl;
    obj["username"] = username;
    obj["enabled"] = enabled;
    // Only include password in the patch if the user typed a new one.
    if (!password.isEmpty())
        obj["password"] = password;
    client->patch("/cameras/" + id, QJsonDocument(obj), this, [this](QRestReply& reply) {
        if (reply.isSuccess())
            refresh();
    });
}

void CameraModel::deleteCamera(const QString& id) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    client->del("/cameras/" + id, this, [this, id](QRestReply& reply) {
        if (!reply.isSuccess())
            return;
        for (int i = 0; i < m_cameras.size(); ++i) {
            if (m_cameras.at(i).id == id) {
                beginRemoveRows({}, i, i);
                m_cameras.removeAt(i);
                endRemoveRows();
                emit cameraDeleted(id);
                return;
            }
        }
    });
}

void CameraModel::setEnabled(const QString& id, bool enabled) {
    const int i = cameraIndexById(id);
    if (i < 0)
        return;

    // Optimistic update.
    m_cameras[i].enabled = enabled;
    const auto idx = index(i);
    emit dataChanged(idx, idx, {CameraEnabledRole});

    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client) {
        emit enableRollback(id, !enabled);
        return;
    }

    QJsonObject obj;
    obj["enabled"] = enabled;
    client->patch("/cameras/" + id, QJsonDocument(obj), this,
                  [this, id, enabled](QRestReply& reply) {
                      if (reply.isSuccess())
                          return;
                      // Roll back on failure.
                      const int j = cameraIndexById(id);
                      if (j >= 0) {
                          m_cameras[j].enabled = !enabled;
                          const auto jdx = index(j);
                          emit dataChanged(jdx, jdx, {CameraEnabledRole});
                      }
                      emit enableRollback(id, !enabled);
                  });
}

void CameraModel::fetchCamera(const QString& cameraId) {
    const CameraDto* cam = findCamera(cameraId);
    if (!cam)
        return;
    auto* client = m_siteManager->clientForNode(cam->nodeId);
    if (!client)
        return;
    client->get("/cameras/" + cameraId, this, [this, cameraId](QRestReply& reply) {
        if (!reply.isSuccess())
            return;
        const auto doc = reply.readJson();
        if (!doc || !doc->isObject())
            return;
        const bool isRecording = doc->object()["recording"].toBool();
        for (int i = 0; i < m_cameras.size(); ++i) {
            if (m_cameras.at(i).id != cameraId)
                continue;
            if (m_cameras.at(i).recording == isRecording)
                return;
            m_cameras[i].recording = isRecording;
            const auto idx = index(i);
            emit dataChanged(idx, idx, {CameraRecordingRole});
            emit recordingStateChanged(cameraId, isRecording);
            return;
        }
    });
}

void CameraModel::startRecording(const QString& cameraId) {
    const CameraDto* cam = findCamera(cameraId);
    if (!cam)
        return;
    auto* client = m_siteManager->clientForNode(cam->nodeId);
    if (!client)
        return;
    client->post("/cameras/" + cameraId + "/recording/start", {}, this,
                 [this, cameraId](QRestReply& reply) {
                     if (reply.isSuccess())
                         setRecording(cameraId, true);
                 });
}

void CameraModel::stopRecording(const QString& cameraId) {
    const CameraDto* cam = findCamera(cameraId);
    if (!cam)
        return;
    auto* client = m_siteManager->clientForNode(cam->nodeId);
    if (!client)
        return;
    client->post("/cameras/" + cameraId + "/recording/stop", {}, this,
                 [this, cameraId](QRestReply& reply) {
                     if (reply.isSuccess())
                         setRecording(cameraId, false);
                 });
}

// Logs the BE's {"error": "..."} body since reply.errorString() is only
// QNetworkReply's transport-level text, which is empty for an ordinary
// non-2xx HTTP response like the BE's ApiError failures.
static QString describeFailure(QRestReply& reply) {
    const auto doc = reply.readJson();
    const QString message =
        doc && doc->isObject() ? doc->object().value("error").toString() : QString{};
    return QStringLiteral("HTTP %1%2")
        .arg(reply.httpStatus())
        .arg(message.isEmpty() ? QString{} : QStringLiteral(" - ") + message);
}

void CameraModel::startRelay(const QString& cameraId, bool sub) {
    const CameraDto* cam = findCamera(cameraId);
    if (!cam) {
        qCDebug(lcLiveView) << "relay/start skipped for" << cameraId << ": camera not loaded";
        return;
    }
    auto* client = m_siteManager->clientForNode(cam->nodeId);
    if (!client) {
        qCDebug(lcLiveView) << "relay/start skipped for" << cameraId << ": no client for node";
        return;
    }
    // The sub relay needs a configured sub-stream; fall back to main rather
    // than failing outright for a camera with only one RTSP stream.
    const bool actualSub = sub && !cam->subRtspUrl.isEmpty();
    const QString path =
        "/cameras/" + cameraId + "/relay/start?quality=" + (actualSub ? "sub" : "main");
    qCDebug(lcLiveView) << "relay/start (" << (sub ? "sub" : "main") << ") sent for" << cameraId;
    client->post(path, {}, this, [this, cameraId, sub](QRestReply& reply) {
        if (!reply.isSuccess()) {
            // No UI surface for this yet (see MatrixView's silent drag-drop/
            // tile-restore callers), so log it to make a "camera X won't show
            // live view" report diagnosable from the app's own output.
            qCWarning(lcLiveView) << "relay/start (" << (sub ? "sub" : "main") << ") failed for"
                                  << cameraId << ":" << describeFailure(reply);
            emit relayStartFailed(cameraId, sub);
            return;
        }
        const auto doc = reply.readJson();
        if (!doc || !doc->isObject()) {
            emit relayStartFailed(cameraId, sub);
            return;
        }
        const QString url = doc->object()["relay_url"].toString();
        qCDebug(lcLiveView) << "relay/start (" << (sub ? "sub" : "main") << ") ok for" << cameraId
                            << ":" << url;
        // Stored under the requested slot (sub=tile, main=full-screen)
        // regardless of whether the fallback above actually served it.
        setRelayUrl(cameraId, url, sub);
    });
}

void CameraModel::stopRelay(const QString& cameraId, bool sub) {
    const CameraDto* cam = findCamera(cameraId);
    if (!cam)
        return;
    auto* client = m_siteManager->clientForNode(cam->nodeId);
    if (!client)
        return;
    // Must match startRelay()'s own fallback decision, or this would stop a
    // (never-started) sub relay while the actual main-quality one it fell
    // back to keeps running.
    const bool actualSub = sub && !cam->subRtspUrl.isEmpty();
    const QString path =
        "/cameras/" + cameraId + "/relay/stop?quality=" + (actualSub ? "sub" : "main");
    client->post(path, {}, this, [this, cameraId, sub](QRestReply& reply) {
        if (reply.isSuccess())
            setRelayUrl(cameraId, QString{}, sub);
        else
            qWarning() << "CameraModel: relay/stop (" << (sub ? "sub" : "main") << ") failed for"
                       << cameraId << ":" << describeFailure(reply);
    });
}

void CameraModel::setRecording(const QString& cameraId, bool recording) {
    for (int i = 0; i < m_cameras.size(); ++i) {
        if (m_cameras.at(i).id == cameraId) {
            m_cameras[i].recording = recording;
            const auto idx = index(i);
            emit dataChanged(idx, idx, {CameraRecordingRole});
            emit recordingStateChanged(cameraId, recording);
            return;
        }
    }
}

void CameraModel::setRelayUrl(const QString& cameraId, const QString& url, bool sub) {
    for (int i = 0; i < m_cameras.size(); ++i) {
        if (m_cameras.at(i).id == cameraId) {
            const int role = sub ? CameraRelayUrlRole : CameraMainRelayUrlRole;
            if (sub)
                m_cameras[i].relayUrl = url;
            else
                m_cameras[i].mainRelayUrl = url;
            const auto idx = index(i);
            emit dataChanged(idx, idx, {role});
            emit relayStateChanged(cameraId, url, sub);
            return;
        }
    }
}

const CameraDto* CameraModel::findCamera(const QString& id) const {
    for (const auto& cam : m_cameras)
        if (cam.id == id)
            return &cam;
    return nullptr;
}

QVariantMap CameraModel::cameraById(const QString& id) const {
    for (const auto& cam : m_cameras) {
        if (cam.id != id)
            continue;
        QVariantMap map;
        map["cameraId"] = cam.id;
        map["cameraName"] = cam.name;
        map["cameraLocation"] = cam.location;
        map["cameraEnabled"] = cam.enabled;
        map["cameraRtspUrl"] = cam.rtspUrl;
        map["cameraSubRtspUrl"] = cam.subRtspUrl;
        map["cameraUsername"] = cam.username;
        map["cameraRecording"] = cam.recording;
        map["cameraRelayUrl"] = cam.relayUrl;
        map["cameraMainRelayUrl"] = cam.mainRelayUrl;
        return map;
    }
    return {};
}

int CameraModel::cameraIndexById(const QString& id) const {
    for (int i = 0; i < m_cameras.size(); ++i)
        if (m_cameras.at(i).id == id)
            return i;
    return -1;
}

QString CameraModel::nextDuplicateName(const QString& baseName) const {
    auto nameTaken = [this](const QString& name) {
        for (const auto& cam : m_cameras)
            if (cam.name == name)
                return true;
        return false;
    };
    int n = 2;
    QString candidate = baseName + QStringLiteral(" %1").arg(n);
    while (nameTaken(candidate))
        candidate = baseName + QStringLiteral(" %1").arg(++n);
    return candidate;
}

QVariantList CameraModel::searchableEntries() const {
    QVariantList out;
    out.reserve(m_cameras.size());
    for (const auto& cam : m_cameras) {
        out.append(QVariantMap{
            {"id", cam.id},
            {"name", cam.name},
            {"subtitle", cam.location},
        });
    }
    return out;
}

void CameraModel::insertTestCamera(const QString& id, const QString& name, bool recording) {
    CameraDto cam;
    cam.id = id;
    cam.name = name;
    cam.enabled = true;
    cam.recording = recording;
    beginInsertRows({}, m_cameras.size(), m_cameras.size());
    m_cameras.append(cam);
    endInsertRows();
}

void CameraModel::setRelayUrlForTest(const QString& cameraId, const QString& url, bool sub) {
    setRelayUrl(cameraId, url, sub);
}

void CameraModel::clearTestCameras() {
    beginResetModel();
    m_cameras.clear();
    endResetModel();
}

CameraDto CameraModel::fromJson(const QJsonObject& obj, const QString& nodeId) {
    CameraDto cam;
    cam.id = obj["id"].toString();
    cam.name = obj["name"].toString();
    cam.location = obj["location"].toString();
    cam.rtspUrl = obj["rtsp_url"].toString();
    cam.subRtspUrl = obj["sub_rtsp_url"].toString();
    cam.username = obj["username"].toString();
    cam.enabled = obj["enabled"].toBool();
    cam.recording = obj["recording"].toBool();
    // BE naming is the opposite of what these fields look like at a glance:
    // "relay_url" is the MAIN/full-res relay, "sub_relay_url" is the
    // SUB/low-res one. That matches this model's own relayUrl (tiles, sub) vs
    // mainRelayUrl (full-screen, main) usage once mapped this way round.
    cam.relayUrl = obj["sub_relay_url"].toString();
    cam.mainRelayUrl = obj["relay_url"].toString();
    cam.createdAt = obj["created_at"].toInteger();
    cam.nodeId = nodeId;
    return cam;
}

void CameraModel::setLoading(bool v) {
    if (m_loading == v)
        return;
    m_loading = v;
    emit loadingChanged();
}
