# SPDX-FileCopyrightText: 2026 Mohammad Armoun
# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.22)

project(ReeframeFrontend
    VERSION 0.2.0
    DESCRIPTION "Reeframe VMS Desktop Client"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# -- Qt auto-detection --
# Finds Qt from the standard online-installer layout automatically.
# An explicit -DCMAKE_PREFIX_PATH or Qt6_DIR (set by Qt Creator's kit or the
# command line) always takes precedence over this block.
if(NOT CMAKE_PREFIX_PATH AND NOT Qt6_DIR)
    file(GLOB _qt_candidates
        "$ENV{HOME}/Qt/6.*/gcc_64"   # Linux
        "$ENV{HOME}/Qt/6.*/macos"    # macOS
        "C:/Qt/6.*/msvc2022_64"      # Windows MSVC
        "C:/Qt/6.*/mingw*"           # Windows MinGW

    )
    list(SORT _qt_candidates ORDER DESCENDING)
    if(_qt_candidates)
        list(GET _qt_candidates 0 _qt_root)
        message(STATUS "Auto-detected Qt: ${_qt_root}")
        set(CMAKE_PREFIX_PATH "${_qt_root}" CACHE PATH "" FORCE)
    endif()
endif()

# -- Qt --
find_package(Qt6 6.8 REQUIRED COMPONENTS
    Widgets
    Quick
    QuickControls2
    Network
    Multimedia
    Sql
    Svg
    Test
    QuickTest
    LinguistTools
)
qt_standard_project_setup(REQUIRES 6.8)

# Preserve build-time link paths (e.g. Qt from ~/Qt) in the installed binary's RPATH
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

# QML files in subdirectories (components/, views/, etc.) each need a qmldir.
qt_policy(SET QTP0004 NEW)

# -- QML module library --
# Holds every QML file plus the C++ types they bind to. Split out from the
# desktop executable so the Qt Quick Test runner (reeframe-fe-qmltests,
# see bottom of this file) can link the exact same "Reeframe" module instead
# of duplicating registration.
qt_add_library(reeframe-fe-core STATIC)

# `pragma Singleton` inside a .qml file is only a hint for the QML engine's
# own runtime loader (e.g. loose files opened via qmlscene). qt_add_qml_module's
# generated qmldir needs this CMake source property to actually write the
# "singleton" keyword, otherwise the type is registered as an ordinary
# (uninstantiated) component and every property access on it resolves to
# undefined at runtime with no load-time error.
set_source_files_properties(qml/DragSession.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)
set_source_files_properties(qml/PendingDeletes.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)
set_source_files_properties(qml/TimelineController.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)
set_source_files_properties(qml/EventTypeColors.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

# Every QML file in the app must be listed in QML_FILES below.
qt_add_qml_module(reeframe-fe-core
    URI "Reeframe"
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/App.qml
        qml/DragSession.qml
        qml/PendingDeletes.qml
        qml/TimelineController.qml
        qml/EventTypeColors.qml
        qml/TopBar.qml
        qml/StatusBar.qml
        qml/Sidebar.qml
        qml/components/TblIcon.qml
        qml/components/NavItem.qml
        qml/components/SubNavItem.qml
        qml/components/StatusDot.qml
        qml/components/RecordingDot.qml
        qml/components/StatusBadge.qml
        qml/components/SearchBar.qml
        qml/components/ConfirmDialog.qml
        qml/components/TypeChip.qml
        qml/components/ToggleSwitch.qml
        qml/components/Checkbox.qml
        qml/components/Toast.qml
        qml/components/PendingDeleteQueue.qml
        qml/components/RunStatusBadge.qml
        qml/components/NodeResultRow.qml
        qml/components/CameraPanel.qml
        qml/components/RecordingsPanel.qml
        qml/components/RecordingCoverageBar.qml
        qml/components/RecordingSessionRow.qml
        qml/components/DateRangeCalendar.qml
        qml/components/DockController.qml
        qml/components/DockRail.qml
        qml/components/TimelineBar.qml
        qml/components/CameraTileOverlay.qml
        qml/components/CameraTileHeader.qml
        qml/components/HoverButton.qml
        qml/components/EmptyState.qml
        qml/components/CommandPalette.qml
        qml/components/DagCanvas.qml
        qml/components/DagEdge.qml
        qml/components/DagNode.qml
        qml/components/NodeConfigPanel.qml
        qml/components/TransportConfigPanel.qml
        qml/components/TriggerConfigPanel.qml
        qml/components/ConditionConfigPanel.qml
        qml/components/ProblemsPanel.qml
        qml/components/PipelineEnableToggle.qml
        qml/dialogs/AddSiteDialog.qml
        qml/dialogs/AddCoordinatorDialog.qml
        qml/dialogs/CoordinatorLoginDialog.qml
        qml/dialogs/AddSourceDialog.qml
        qml/dialogs/AddDestinationDialog.qml
        qml/dialogs/AddPipelineDialog.qml
        qml/dialogs/EditPipelineDialog.qml
        qml/dialogs/TriggerDialog.qml
        qml/views/PipelineEditorView.qml
        qml/views/RunDetailView.qml
        qml/views/LoginView.qml
        qml/dialogs/AddCameraDialog.qml
        qml/dialogs/EditCameraDialog.qml
        qml/dialogs/SaveProfileDialog.qml
        qml/views/FullCameraView.qml
        qml/tiles/CameraTile.qml
        qml/tiles/MapTile.qml
        qml/tiles/StatsTile.qml
        qml/views/MatrixView.qml

        qml/views/PipelineListView.qml
        qml/views/SourceListView.qml
        qml/views/DestinationListView.qml
        qml/views/SiteManagerView.qml
        qml/views/CoordinatorManagerView.qml
        qml/views/SettingsView.qml
        qml/PipelineValidation.js
    SOURCES
        src/theme/ThemeManager.h
        src/theme/ThemeManager.cpp
        src/backend/ApiTypes.h
        src/backend/BackendClient.h
        src/backend/BackendClient.cpp
        src/backend/SiteManager.h
        src/backend/SiteManager.cpp
        src/backend/CoordinatorManager.h
        src/backend/CoordinatorManager.cpp
        src/backend/CoordinatorClient.h
        src/backend/CoordinatorClient.cpp
        src/database/AppDatabase.h
        src/database/AppDatabase.cpp
        src/models/CameraModel.h
        src/models/CameraModel.cpp
        src/models/MatrixProfileModel.h
        src/models/MatrixProfileModel.cpp
        src/models/ThumbnailCache.h
        src/models/ThumbnailCache.cpp
        src/models/TileLayoutModel.h
        src/models/TileLayoutModel.cpp
        src/models/SourceModel.h
        src/models/SourceModel.cpp
        src/models/DestinationModel.h
        src/models/DestinationModel.cpp
        src/models/PipelineModel.h
        src/models/PipelineModel.cpp
        src/models/PipelineGraphModel.h
        src/models/PipelineGraphModel.cpp
        src/models/RunModel.h
        src/models/RunModel.cpp
        src/models/RecordingModel.h
        src/models/RecordingModel.cpp
        src/models/EventModel.h
        src/models/EventModel.cpp
        src/models/ExportModel.h
        src/models/ExportModel.cpp
        src/video/IVideoSink.h
        src/video/LiveViewLogging.h
        src/video/LiveViewLogging.cpp
        src/video/QtMultimediaVideoSink.h
        src/video/QtMultimediaVideoSink.cpp
        src/video/VideoSinkRegistry.h
        src/video/VideoSinkRegistry.cpp
        src/video/AuthenticatedRecordingDevice.h
        src/video/AuthenticatedRecordingDevice.cpp
        src/settings/OverlayPrefs.h
        src/settings/OverlayPrefs.cpp
        src/settings/WindowPrefs.h
        src/settings/WindowPrefs.cpp
)

# -- Include paths --
target_include_directories(reeframe-fe-core PUBLIC src/theme src/backend src/database src/models src/video src/settings)

# -- Link --
target_link_libraries(reeframe-fe-core PUBLIC
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
    Qt6::Multimedia
    Qt6::Sql
    Qt6::Svg
    Qt6::Widgets
)

# -- Tabler icon SVGs -- (consumed by TblIcon.qml, part of the qml module)
qt_add_resources(reeframe-fe-core "tabler_icons"
    PREFIX "/tb"
    BASE "assets/icons/tabler"
    FILES
        assets/icons/tabler/layout-grid.svg
        assets/icons/tabler/layout-grid-filled.svg
        assets/icons/tabler/video.svg
        assets/icons/tabler/git-merge.svg
        assets/icons/tabler/world.svg
        assets/icons/tabler/settings.svg
        assets/icons/tabler/settings-filled.svg
        assets/icons/tabler/chevron-left.svg
        assets/icons/tabler/chevron-right.svg
        assets/icons/tabler/chevron-down.svg
        assets/icons/tabler/minus.svg
        assets/icons/tabler/plus.svg
        assets/icons/tabler/arrows-maximize.svg
        assets/icons/tabler/arrows-minimize.svg
        assets/icons/tabler/x.svg
        assets/icons/tabler/search.svg
        assets/icons/tabler/layout-sidebar-left-collapse.svg
        assets/icons/tabler/layout-sidebar-left-expand.svg
        assets/icons/tabler/video-plus.svg
        assets/icons/tabler/broadcast.svg
        assets/icons/tabler/send.svg
        assets/icons/tabler/player-play.svg
        assets/icons/tabler/player-pause.svg
        assets/icons/tabler/camera-filled.svg
        assets/icons/tabler/pin.svg
        assets/icons/tabler/download.svg
        assets/icons/tabler/eye.svg
        assets/icons/tabler/eye-off.svg
        assets/icons/tabler/zoom-reset.svg
)

# -- Desktop application executable --
qt_add_executable(reeframe-fe
    src/main.cpp
    src/shell/TrayManager.h
    src/shell/TrayManager.cpp
)

target_include_directories(reeframe-fe PRIVATE src/shell)
target_compile_definitions(reeframe-fe PRIVATE REEFRAME_VERSION="${PROJECT_VERSION}")

target_link_libraries(reeframe-fe PRIVATE
    reeframe-fe-core
    reeframe-fe-coreplugin
    Qt6::Widgets
)

# -- App icons embedded as Qt resources --
qt_add_resources(reeframe-fe "app_icons"
    PREFIX "/icons"
    BASE "assets/icons"
    FILES
        assets/icons/reframe-icon-16.png
        assets/icons/reframe-icon-32.png
        assets/icons/reframe-icon-48.png
        assets/icons/reframe-icon-64.png
        assets/icons/reframe-icon-128.png
        assets/icons/reframe-icon-256.png
        assets/icons/reframe-icon-512.png
        assets/icons/reframe-icon-dark-16.png
        assets/icons/reframe-icon-dark-32.png
        assets/icons/reframe-icon-dark-48.png
        assets/icons/reframe-icon-dark-64.png
        assets/icons/reframe-icon-dark-128.png
        assets/icons/reframe-icon-dark-256.png
        assets/icons/reframe-icon-dark-512.png
)

# -- Translations --
# lupdate scans reeframe-fe-core's QML_FILES (and any C++ sources) for
# qsTr() calls and merges newly-found/removed strings into the .ts files
# below; lrelease compiles them to .qm and embeds them as Qt resources
# under :/i18n/ in reeframe-fe. Supported languages: English and German.
qt_add_translations(reeframe-fe
    TS_FILES i18n/reeframe-fe_en.ts i18n/reeframe-fe_de.ts
    SOURCE_TARGETS reeframe-fe-core
)

# -- Platform --
set_target_properties(reeframe-fe PROPERTIES
    WIN32_EXECUTABLE                   TRUE
    MACOSX_BUNDLE                      TRUE
    MACOSX_BUNDLE_GUI_IDENTIFIER       io.reeframe.vms
    MACOSX_BUNDLE_BUNDLE_VERSION       ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
)

# Windows: embed ICO into the executable via CMake RC_ICONS
if(WIN32)
    set_target_properties(reeframe-fe PROPERTIES
        RC_ICONS "${CMAKE_CURRENT_SOURCE_DIR}/assets/icons/reeframe.ico"
    )
endif()

# macOS: embed ICNS into the app bundle
if(APPLE AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/icons/reeframe.icns")
    set_target_properties(reeframe-fe PROPERTIES
        MACOSX_BUNDLE_ICON_FILE reeframe.icns
    )
    target_sources(reeframe-fe PRIVATE assets/icons/reeframe.icns)
    set_source_files_properties(assets/icons/reeframe.icns PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources
    )
endif()

# Linux: install desktop entry and hicolor icons so the OS shows the correct icon
if(UNIX AND NOT APPLE)
    install(TARGETS reeframe-fe RUNTIME DESTINATION bin)
    install(FILES assets/io.reeframe.vms.desktop
        DESTINATION share/applications
    )
    foreach(SIZE 16 32 48 64 128 256)
        install(FILES "assets/icons/reframe-icon-${SIZE}.png"
            DESTINATION "share/icons/hicolor/${SIZE}x${SIZE}/apps"
            RENAME "io.reeframe.vms.png"
        )
    endforeach()
endif()

# -- Qt Quick Test harness --
# Runs TestCase .qml files under tests/qml/ against the real "Reeframe" QML
# module (App.qml, MatrixView.qml, CameraTile.qml, ...) via qmltestrunner's
# QTest::mouseClick: synthetic events injected straight into Qt's own event
# queue, so the same test works unmodified under X11, Wayland, Windows, and
# macOS with no OS-level input-automation tool required.
enable_testing()

qt_add_executable(reeframe-fe-qmltests
    tests/cpp/main.cpp
    tests/cpp/TestSetup.h
    tests/cpp/TestSetup.cpp
)

target_link_libraries(reeframe-fe-qmltests PRIVATE
    reeframe-fe-core
    reeframe-fe-coreplugin
    Qt6::QuickTest
    Qt6::Test
)

target_compile_definitions(reeframe-fe-qmltests PRIVATE
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/qml"
)

add_test(NAME qml_tests COMMAND reeframe-fe-qmltests)

# reeframe-fe-core's "Reeframe" QML module is a static plugin because it's
# built as its own library target, so each executable that links it (the
# desktop app and the test runner) must import the plugin itself.
qt_import_qml_plugins(reeframe-fe)
qt_import_qml_plugins(reeframe-fe-qmltests)
