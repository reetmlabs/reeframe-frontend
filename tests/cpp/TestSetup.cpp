// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "TestSetup.h"

#include <QCoreApplication>
#include <QQmlContext>
#include <QQmlEngine>

#include "AppDatabase.h"
#include "CameraModel.h"
#include "CoordinatorManager.h"
#include "DestinationModel.h"
#include "ExportModel.h"
#include "MatrixProfileModel.h"
#include "OverlayPrefs.h"
#include "PipelineGraphModel.h"
#include "PipelineModel.h"
#include "RecordingModel.h"
#include "EventModel.h"
#include "RunModel.h"
#include "SiteManager.h"
#include "SourceModel.h"
#include "ThumbnailCache.h"
#include "TileLayoutModel.h"
#include "VideoSinkRegistry.h"

// QUICK_TEST_MAIN_WITH_SETUP constructs TestSetup *before* the
// QCoreApplication/QGuiApplication instance exists, so nothing here may touch
// QStandardPaths, QSqlDatabase, or anything else that requires qApp. All of
// that is deferred to qmlEngineAvailable(), which runs once the app and
// QQmlEngine both exist.
TestSetup::TestSetup() = default;

void TestSetup::qmlEngineAvailable(QQmlEngine* engine) {
    if (!m_db) {
        // Distinct app/org name so AppDatabase (QStandardPaths::AppLocalDataLocation)
        // resolves to its own SQLite file instead of the real app.db.
        QCoreApplication::setOrganizationName("Reeframe");
        QCoreApplication::setApplicationName("Reeframe VMS Tests");

        m_db = new AppDatabase(this);
        m_thumbnailCache = new ThumbnailCache(this);
        m_coordinatorManager = new CoordinatorManager(m_db, this);
        m_siteManager = new SiteManager(m_db, m_coordinatorManager, this);
        m_cameraModel = new CameraModel(m_siteManager, this);
        m_matrixProfileModel = new MatrixProfileModel(m_db, this);
        m_tileLayoutModel = new TileLayoutModel(m_db, this);
        m_overlayPrefs = new OverlayPrefs(m_db, this);
        m_sourceModel = new SourceModel(m_siteManager, this);
        m_destinationModel = new DestinationModel(m_siteManager, this);
        m_pipelineModel = new PipelineModel(m_siteManager, this);
        m_pipelineGraphModel = new PipelineGraphModel(m_siteManager, this);
        m_runModel = new RunModel(m_siteManager, this);
        m_recordingModel = new RecordingModel(m_siteManager, this);
        m_eventModel = new EventModel(m_siteManager, this);
        m_exportModel = new ExportModel(m_siteManager, this);
        m_videoSinkRegistry = new VideoSinkRegistry(this);

        QObject::connect(m_siteManager, &SiteManager::activeSiteChanged, this, [this]() {
            m_tileLayoutModel->setActiveSiteId(m_siteManager->activeSiteId());
        });
        QObject::connect(m_cameraModel, &CameraModel::cameraDeleted, m_tileLayoutModel,
                         &TileLayoutModel::removeTilesForCamera);
    }

    engine->rootContext()->setContextProperty("ThumbnailCache", m_thumbnailCache);
    engine->rootContext()->setContextProperty("SiteManager", m_siteManager);
    engine->rootContext()->setContextProperty("CoordinatorManager", m_coordinatorManager);
    engine->rootContext()->setContextProperty("CameraModel", m_cameraModel);
    engine->rootContext()->setContextProperty("MatrixProfileModel", m_matrixProfileModel);
    engine->rootContext()->setContextProperty("TileLayoutModel", m_tileLayoutModel);
    engine->rootContext()->setContextProperty("OverlayPrefs", m_overlayPrefs);
    engine->rootContext()->setContextProperty("SourceModel", m_sourceModel);
    engine->rootContext()->setContextProperty("DestinationModel", m_destinationModel);
    engine->rootContext()->setContextProperty("PipelineModel", m_pipelineModel);
    engine->rootContext()->setContextProperty("PipelineGraphModel", m_pipelineGraphModel);
    engine->rootContext()->setContextProperty("RunModel", m_runModel);
    engine->rootContext()->setContextProperty("RecordingModel", m_recordingModel);
    engine->rootContext()->setContextProperty("EventModel", m_eventModel);
    engine->rootContext()->setContextProperty("ExportModel", m_exportModel);
    engine->rootContext()->setContextProperty("VideoSinkRegistry", m_videoSinkRegistry);
}
