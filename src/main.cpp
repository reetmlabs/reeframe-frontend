// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include <QApplication>
#include <QIcon>
#include <QLibraryInfo>
#include <QLocale>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTranslator>
#include <QtQml/qqmlextensionplugin.h>

// The "Reeframe" QML module lives in the reeframe-fe-core static library
// (shared with the Qt Quick Test runner, see tests/cpp/main.cpp). Static QML
// plugins aren't auto-discovered by qmlimportscanner unless their QML_FILES
// are scanned for this exact target, so the plugin is imported explicitly.
Q_IMPORT_QML_PLUGIN(ReeframePlugin)

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
#include "TrayManager.h"
#include "VideoSinkRegistry.h"
#include "WindowPrefs.h"

int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    app.setApplicationName("Reeframe VMS");
    app.setApplicationVersion(QStringLiteral(REEFRAME_VERSION));
    app.setOrganizationName("Reeframe");
    app.setOrganizationDomain("io.reeframe");

    app.setQuitOnLastWindowClosed(false);
    app.setDesktopFileName("io.reeframe.vms");
    QQuickStyle::setStyle("Basic");

    QIcon appIcon;
    appIcon.addFile(":/icons/reframe-icon-16.png", QSize(16, 16));
    appIcon.addFile(":/icons/reframe-icon-32.png", QSize(32, 32));
    appIcon.addFile(":/icons/reframe-icon-48.png", QSize(48, 48));
    appIcon.addFile(":/icons/reframe-icon-64.png", QSize(64, 64));
    appIcon.addFile(":/icons/reframe-icon-128.png", QSize(128, 128));
    appIcon.addFile(":/icons/reframe-icon-256.png", QSize(256, 256));
    appIcon.addFile(":/icons/reframe-icon-512.png", QSize(512, 512));
    app.setWindowIcon(appIcon);

    auto* db = new AppDatabase(&app);
    auto* thumbnailCache = new ThumbnailCache(&app);
    auto* coordinatorManager = new CoordinatorManager(db, &app);
    auto* siteManager = new SiteManager(db, coordinatorManager, &app);
    auto* cameraModel = new CameraModel(siteManager, &app);
    auto* matrixProfileModel = new MatrixProfileModel(db, &app);
    auto* tileLayoutModel = new TileLayoutModel(db, &app);
    auto* overlayPrefs = new OverlayPrefs(db, &app);
    auto* sourceModel = new SourceModel(siteManager, &app);
    auto* destinationModel = new DestinationModel(siteManager, &app);
    auto* pipelineModel = new PipelineModel(siteManager, &app);
    auto* pipelineGraphModel = new PipelineGraphModel(siteManager, &app);
    auto* runModel = new RunModel(siteManager, &app);
    auto* recordingModel = new RecordingModel(siteManager, &app);
    auto* eventModel = new EventModel(siteManager, &app);
    auto* exportModel = new ExportModel(siteManager, &app);
    auto* videoSinkRegistry = new VideoSinkRegistry(&app);
    auto* windowPrefs = new WindowPrefs(db, &app);

    QObject::connect(siteManager, &SiteManager::activeSiteChanged,
                     [siteManager, tileLayoutModel]() {
                         tileLayoutModel->setActiveSiteId(siteManager->activeSiteId());
                     });
    tileLayoutModel->setActiveSiteId(siteManager->activeSiteId());

    // A deleted camera must not leave a tile pointing at it.
    QObject::connect(cameraModel, &CameraModel::cameraDeleted, tileLayoutModel,
                     &TileLayoutModel::removeTilesForCamera);

    // Kept alive for the lifetime of main() since QApplication only holds a
    // pointer to an installed QTranslator, not ownership of it.
    QTranslator translator;
    if (translator.load(QLocale::system(), "reeframe-fe", "_", ":/i18n"))
        app.installTranslator(&translator);

    QQmlApplicationEngine engine;
    engine.addImportPath(QLibraryInfo::path(QLibraryInfo::QmlImportsPath));
    engine.rootContext()->setContextProperty("ThumbnailCache", thumbnailCache);
    engine.rootContext()->setContextProperty("SiteManager", siteManager);
    engine.rootContext()->setContextProperty("CoordinatorManager", coordinatorManager);
    engine.rootContext()->setContextProperty("CameraModel", cameraModel);
    engine.rootContext()->setContextProperty("MatrixProfileModel", matrixProfileModel);
    engine.rootContext()->setContextProperty("TileLayoutModel", tileLayoutModel);
    engine.rootContext()->setContextProperty("OverlayPrefs", overlayPrefs);
    engine.rootContext()->setContextProperty("SourceModel", sourceModel);
    engine.rootContext()->setContextProperty("DestinationModel", destinationModel);
    engine.rootContext()->setContextProperty("PipelineModel", pipelineModel);
    engine.rootContext()->setContextProperty("PipelineGraphModel", pipelineGraphModel);
    engine.rootContext()->setContextProperty("RunModel", runModel);
    engine.rootContext()->setContextProperty("RecordingModel", recordingModel);
    engine.rootContext()->setContextProperty("EventModel", eventModel);
    engine.rootContext()->setContextProperty("ExportModel", exportModel);
    engine.rootContext()->setContextProperty("VideoSinkRegistry", videoSinkRegistry);
    engine.rootContext()->setContextProperty("WindowPrefs", windowPrefs);

    engine.loadFromModule("Reeframe", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;

    auto* window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    if (window) {
        window->setIcon(appIcon);
        auto* tray = new TrayManager(window, &app);
        Q_UNUSED(tray)
    }

    return app.exec();
}
