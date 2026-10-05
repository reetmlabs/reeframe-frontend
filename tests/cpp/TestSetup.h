// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QObject>

class QQmlEngine;
class AppDatabase;
class SiteManager;
class CoordinatorManager;
class CameraModel;
class MatrixProfileModel;
class TileLayoutModel;
class OverlayPrefs;
class SourceModel;
class DestinationModel;
class PipelineModel;
class PipelineGraphModel;
class RunModel;
class RecordingModel;
class EventModel;
class ExportModel;
class ThumbnailCache;
class VideoSinkRegistry;

// Registers the same C++ context properties as src/main.cpp so QML test
// files can drive the real "Reeframe" module views (App.qml, MatrixView.qml,
// ...) exactly as they run in production, without duplicating the wiring.
class TestSetup : public QObject {
    Q_OBJECT
  public:
    TestSetup();

  public slots:
    void qmlEngineAvailable(QQmlEngine* engine);

  private:
    AppDatabase* m_db = nullptr;
    ThumbnailCache* m_thumbnailCache = nullptr;
    SiteManager* m_siteManager = nullptr;
    CoordinatorManager* m_coordinatorManager = nullptr;
    CameraModel* m_cameraModel = nullptr;
    MatrixProfileModel* m_matrixProfileModel = nullptr;
    TileLayoutModel* m_tileLayoutModel = nullptr;
    OverlayPrefs* m_overlayPrefs = nullptr;
    SourceModel* m_sourceModel = nullptr;
    DestinationModel* m_destinationModel = nullptr;
    PipelineModel* m_pipelineModel = nullptr;
    PipelineGraphModel* m_pipelineGraphModel = nullptr;
    RunModel* m_runModel = nullptr;
    RecordingModel* m_recordingModel = nullptr;
    EventModel* m_eventModel = nullptr;
    ExportModel* m_exportModel = nullptr;
    VideoSinkRegistry* m_videoSinkRegistry = nullptr;
};
