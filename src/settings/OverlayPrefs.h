// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QObject>
#include <QStringList>
#include <QtQml/qqml.h>

class AppDatabase;

class OverlayPrefs : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString slotTl READ slotTl WRITE setSlotTl NOTIFY slotTlChanged)
    Q_PROPERTY(QString slotTc READ slotTc WRITE setSlotTc NOTIFY slotTcChanged)
    Q_PROPERTY(QString slotTr READ slotTr WRITE setSlotTr NOTIFY slotTrChanged)
    Q_PROPERTY(QString slotBl READ slotBl WRITE setSlotBl NOTIFY slotBlChanged)
    Q_PROPERTY(QString slotBc READ slotBc WRITE setSlotBc NOTIFY slotBcChanged)
    Q_PROPERTY(QString slotBr READ slotBr WRITE setSlotBr NOTIFY slotBrChanged)
    Q_PROPERTY(QString customTl READ customTl WRITE setCustomTl NOTIFY customTlChanged)
    Q_PROPERTY(QString customTc READ customTc WRITE setCustomTc NOTIFY customTcChanged)
    Q_PROPERTY(QString customTr READ customTr WRITE setCustomTr NOTIFY customTrChanged)
    Q_PROPERTY(QString customBl READ customBl WRITE setCustomBl NOTIFY customBlChanged)
    Q_PROPERTY(QString customBc READ customBc WRITE setCustomBc NOTIFY customBcChanged)
    Q_PROPERTY(QString customBr READ customBr WRITE setCustomBr NOTIFY customBrChanged)
    Q_PROPERTY(int fontSize READ fontSize WRITE setFontSize NOTIFY fontSizeChanged)
    Q_PROPERTY(QString textColor READ textColor WRITE setTextColor NOTIFY textColorChanged)
    Q_PROPERTY(double bgOpacity READ bgOpacity WRITE setBgOpacity NOTIFY bgOpacityChanged)
    Q_PROPERTY(bool headerShowClose READ headerShowClose WRITE setHeaderShowClose NOTIFY
                   headerShowCloseChanged)
    Q_PROPERTY(bool headerShowExpand READ headerShowExpand WRITE setHeaderShowExpand NOTIFY
                   headerShowExpandChanged)
    Q_PROPERTY(QStringList excludedCameras READ excludedCameras NOTIFY excludedCamerasChanged)
    Q_PROPERTY(bool cameraPanelOpen READ cameraPanelOpen WRITE setCameraPanelOpen NOTIFY
                   cameraPanelOpenChanged)
    Q_PROPERTY(bool recordingsPanelOpen READ recordingsPanelOpen WRITE setRecordingsPanelOpen NOTIFY
                   recordingsPanelOpenChanged)
    Q_PROPERTY(bool timelineOpen READ timelineOpen WRITE setTimelineOpen NOTIFY timelineOpenChanged)
    // Persists which dock panel is frontmost; App.qml's DockController only tracks each panel's open/closed state.
    Q_PROPERTY(
        QString frontDockPanel READ frontDockPanel WRITE setFrontDockPanel NOTIFY frontDockPanelChanged)

  public:
    explicit OverlayPrefs(AppDatabase* db, QObject* parent = nullptr);

    QString slotTl() const { return m_slotTl; }
    QString slotTc() const { return m_slotTc; }
    QString slotTr() const { return m_slotTr; }
    QString slotBl() const { return m_slotBl; }
    QString slotBc() const { return m_slotBc; }
    QString slotBr() const { return m_slotBr; }
    QString customTl() const { return m_customTl; }
    QString customTc() const { return m_customTc; }
    QString customTr() const { return m_customTr; }
    QString customBl() const { return m_customBl; }
    QString customBc() const { return m_customBc; }
    QString customBr() const { return m_customBr; }
    int fontSize() const { return m_fontSize; }
    QString textColor() const { return m_textColor; }
    double bgOpacity() const { return m_bgOpacity; }
    bool headerShowClose() const { return m_headerShowClose; }
    bool headerShowExpand() const { return m_headerShowExpand; }
    QStringList excludedCameras() const { return m_excludedCameras; }
    bool cameraPanelOpen() const { return m_cameraPanelOpen; }
    bool recordingsPanelOpen() const { return m_recordingsPanelOpen; }
    bool timelineOpen() const { return m_timelineOpen; }
    QString frontDockPanel() const { return m_frontDockPanel; }

    void setSlotTl(const QString& v);
    void setSlotTc(const QString& v);
    void setSlotTr(const QString& v);
    void setSlotBl(const QString& v);
    void setSlotBc(const QString& v);
    void setSlotBr(const QString& v);
    void setCustomTl(const QString& v);
    void setCustomTc(const QString& v);
    void setCustomTr(const QString& v);
    void setCustomBl(const QString& v);
    void setCustomBc(const QString& v);
    void setCustomBr(const QString& v);
    void setFontSize(int v);
    void setTextColor(const QString& v);
    void setBgOpacity(double v);
    void setHeaderShowClose(bool v);
    void setHeaderShowExpand(bool v);
    void setCameraPanelOpen(bool v);
    void setRecordingsPanelOpen(bool v);
    void setTimelineOpen(bool v);
    void setFrontDockPanel(const QString& v);

    Q_INVOKABLE void setExcluded(const QString& cameraId, bool excluded);

  signals:
    void slotTlChanged();
    void slotTcChanged();
    void slotTrChanged();
    void slotBlChanged();
    void slotBcChanged();
    void slotBrChanged();
    void customTlChanged();
    void customTcChanged();
    void customTrChanged();
    void customBlChanged();
    void customBcChanged();
    void customBrChanged();
    void fontSizeChanged();
    void textColorChanged();
    void bgOpacityChanged();
    void headerShowCloseChanged();
    void headerShowExpandChanged();
    void excludedCamerasChanged();
    void cameraPanelOpenChanged();
    void recordingsPanelOpenChanged();
    void timelineOpenChanged();
    void frontDockPanelChanged();

  private:
    QString load(const QString& key, const QString& defaultValue) const;
    void save(const QString& key, const QString& value);
    void saveExcluded();

    AppDatabase* m_db;
    QString m_slotTl, m_slotTc, m_slotTr;
    QString m_slotBl, m_slotBc, m_slotBr;
    QString m_customTl, m_customTc, m_customTr;
    QString m_customBl, m_customBc, m_customBr;
    int m_fontSize = 10;
    QString m_textColor;
    double m_bgOpacity = 0.55;
    bool m_headerShowClose = true;
    bool m_headerShowExpand = true;
    bool m_cameraPanelOpen = false;
    bool m_recordingsPanelOpen = false;
    bool m_timelineOpen = true;
    QString m_frontDockPanel;
    QStringList m_excludedCameras;
};
