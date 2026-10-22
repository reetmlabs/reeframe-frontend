// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include "ApiTypes.h"
#include <QAbstractListModel>
#include <QList>
#include <QMetaObject>
#include <QVariantList>

class SiteManager;
class BackendClient;

class CameraModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    // The active site's backend rejects every token this app can get for it.
    Q_PROPERTY(bool authRejected READ authRejected NOTIFY authRejectedChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
  public:
    enum Role {
        CameraIdRole = Qt::UserRole + 1,
        CameraNameRole,
        CameraLocationRole,
        CameraEnabledRole,
        CameraRtspUrlRole,
        CameraSubRtspUrlRole,
        CameraUsernameRole,
        CameraRecordingRole,
        CameraSubRestreamUrlRole,
        CameraMainRestreamUrlRole,
        CameraCreatedAtRole,
    };
    Q_ENUM(Role)

    explicit CameraModel(SiteManager* siteManager, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool loading() const { return m_loading; }
    bool authRejected() const { return m_authRejected; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void createCamera(const QString& name, const QString& location,
                                  const QString& rtspUrl, const QString& subRtspUrl,
                                  const QString& username, const QString& password, bool enabled);
    Q_INVOKABLE void updateCamera(const QString& id, const QString& name, const QString& location,
                                  const QString& rtspUrl, const QString& subRtspUrl,
                                  const QString& username, const QString& password, bool enabled);
    Q_INVOKABLE void deleteCamera(const QString& id);
    Q_INVOKABLE void setEnabled(const QString& id, bool enabled);
    Q_INVOKABLE void startRecording(const QString& cameraId);
    Q_INVOKABLE void stopRecording(const QString& cameraId);
    // sub=true is the low-res restream matrix tiles use; sub=false is the
    // main/full-res restream the full-screen view uses. The BE starts a
    // live-only pipeline on demand for either quality; no recording
    // session is required (see CameraDto::recording).
    Q_INVOKABLE void startRestream(const QString& cameraId, bool sub = false);
    Q_INVOKABLE void stopRestream(const QString& cameraId, bool sub = false);
    Q_INVOKABLE void fetchCamera(const QString& cameraId);
    Q_INVOKABLE QVariantMap cameraById(const QString& id) const;
    Q_INVOKABLE int cameraIndexById(const QString& id) const;

    // Returns "{baseName} 2", or the next unused numeric suffix, to seed a
    // unique name when duplicating a camera from the right-click menu.
    Q_INVOKABLE QString nextDuplicateName(const QString& baseName) const;

    // Flat [{id, name, subtitle}] list for the global command palette, a
    // shape shared with PipelineModel's and SourceModel's equivalents so
    // the palette can merge all three without knowing each model's layout.
    Q_INVOKABLE QVariantList searchableEntries() const;

    // Test-only: inserts a row directly, bypassing the network round trip
    // refresh() normally requires.
    Q_INVOKABLE void insertTestCamera(const QString& id, const QString& name,
                                      bool recording = false);

    // Test-only: emits restreamStateChanged as if startRestream() had just
    // succeeded, bypassing the network round trip.
    Q_INVOKABLE void setRestreamUrlForTest(const QString& cameraId, const QString& url,
                                        bool sub = true);

    // Test-only: clears all rows directly. Needed since CameraModel is one
    // shared instance across every test file in a qmltests run.
    Q_INVOKABLE void clearTestCameras();

  signals:
    void loadingChanged();
    void authRejectedChanged();
    void countChanged();
    void cameraDeleted(const QString& cameraId);
    void enableRollback(const QString& id, bool previousValue);
    void recordingStateChanged(const QString& cameraId, bool recording);
    void restreamStateChanged(const QString& cameraId, const QString& restreamUrl, bool sub);
    void restreamStartFailed(const QString& cameraId, bool sub);
    void createCameraSucceeded();
    void createCameraFailed(const QString& error);
    // Fired when the active site's backend transitions from Error back to
    // Online. Tiles should request a fresh restream regardless of what URL
    // they still hold, since a backend restart kills an on-demand restream
    // no matter how briefly it was down.
    void backendRecovered();

  private:
    static CameraDto fromJson(const QJsonObject& obj, const QString& nodeId);
    void setLoading(bool v);
    void setAuthRejected(bool v);
    void setRecording(const QString& cameraId, bool recording);
    void setRestreamUrl(const QString& cameraId, const QString& url, bool sub);
    const CameraDto* findCamera(const QString& id) const;
    void onActiveSiteChanged();

    SiteManager* m_siteManager;
    QList<CameraDto> m_cameras;
    bool m_loading = false;
    // Whether the active client has returned a camera list yet. Only fetches
    // before that show as loading, so background refreshes don't swap the
    // empty state for "Loading..." and back.
    bool m_hasFetchedForClient = false;
    // The active site's token exchange can still be in flight when
    // activeSiteChanged fires, so the first refresh() may 401 before a
    // session exists; this connection retries once one does. Re-subscribed
    // on every site change since the client itself gets destroyed/recreated.
    QMetaObject::Connection m_sessionConnection;
    // Retries refresh() once the active site's client recovers to Online,
    // covering both a late-starting BE and a BE that drops and reconnects.
    QMetaObject::Connection m_statusConnection;
    QMetaObject::Connection m_tokenRejectedConnection;
    bool m_authRejected = false;
    // The client m_statusConnection targets. A Coordinator site can re-emit
    // activeSiteChanged for the same client while it settles; rebuilding the
    // connection on every one of those risks dropping a status change mid-teardown.
    BackendClient* m_statusConnectedClient = nullptr;
    // Whether the active client is currently in Status::Error, so the next
    // Online transition can tell a real recovery apart from a redundant one.
    bool m_wasDown = false;
};
