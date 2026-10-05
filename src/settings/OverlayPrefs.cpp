// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "OverlayPrefs.h"
#include "AppDatabase.h"
#include <QJsonArray>
#include <QJsonDocument>

OverlayPrefs::OverlayPrefs(AppDatabase* db, QObject* parent) : QObject(parent), m_db(db) {
    m_slotTl = load("overlay.slot_tl", "none");
    m_slotTc = load("overlay.slot_tc", "none");
    m_slotTr = load("overlay.slot_tr", "none");
    m_slotBl = load("overlay.slot_bl", "timestamp");
    m_slotBc = load("overlay.slot_bc", "none");
    m_slotBr = load("overlay.slot_br", "location");
    m_customTl = load("overlay.custom_tl", "");
    m_customTc = load("overlay.custom_tc", "");
    m_customTr = load("overlay.custom_tr", "");
    m_customBl = load("overlay.custom_bl", "");
    m_customBc = load("overlay.custom_bc", "");
    m_customBr = load("overlay.custom_br", "");
    m_fontSize = load("overlay.font_size", "10").toInt();
    m_textColor = load("overlay.text_color", "#ffffff");
    m_bgOpacity = load("overlay.bg_opacity", "0.55").toDouble();
    m_headerShowClose = load("header.show_close", "true") == "true";
    m_headerShowExpand = load("header.show_expand", "true") == "true";
    // Defaults below only apply on first launch; any stored value always wins after that.
    m_cameraPanelOpen = load("cameraPanel.open", "true") == "true";
    m_recordingsPanelOpen = load("recordingsPanel.open", "false") == "true";
    m_timelineOpen = load("timeline.open", "true") == "true";
    m_frontDockPanel = load("dock.front_panel", "cameras");

    const auto doc = QJsonDocument::fromJson(load("overlay.excluded_cameras", "[]").toUtf8());
    if (doc.isArray()) {
        for (const auto& v : doc.array())
            m_excludedCameras.append(v.toString());
    }
}

QString OverlayPrefs::load(const QString& key, const QString& defaultValue) const {
    return m_db->preference(key, defaultValue);
}

void OverlayPrefs::save(const QString& key, const QString& value) {
    m_db->setPreference(key, value);
}

void OverlayPrefs::saveExcluded() {
    QJsonArray arr;
    for (const auto& id : m_excludedCameras)
        arr.append(id);
    save("overlay.excluded_cameras", QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

void OverlayPrefs::setSlotTl(const QString& v) {
    if (m_slotTl == v)
        return;
    m_slotTl = v;
    save("overlay.slot_tl", v);
    emit slotTlChanged();
}

void OverlayPrefs::setSlotTc(const QString& v) {
    if (m_slotTc == v)
        return;
    m_slotTc = v;
    save("overlay.slot_tc", v);
    emit slotTcChanged();
}

void OverlayPrefs::setSlotTr(const QString& v) {
    if (m_slotTr == v)
        return;
    m_slotTr = v;
    save("overlay.slot_tr", v);
    emit slotTrChanged();
}

void OverlayPrefs::setSlotBl(const QString& v) {
    if (m_slotBl == v)
        return;
    m_slotBl = v;
    save("overlay.slot_bl", v);
    emit slotBlChanged();
}

void OverlayPrefs::setSlotBc(const QString& v) {
    if (m_slotBc == v)
        return;
    m_slotBc = v;
    save("overlay.slot_bc", v);
    emit slotBcChanged();
}

void OverlayPrefs::setSlotBr(const QString& v) {
    if (m_slotBr == v)
        return;
    m_slotBr = v;
    save("overlay.slot_br", v);
    emit slotBrChanged();
}

void OverlayPrefs::setCustomTl(const QString& v) {
    if (m_customTl == v)
        return;
    m_customTl = v;
    save("overlay.custom_tl", v);
    emit customTlChanged();
}

void OverlayPrefs::setCustomTc(const QString& v) {
    if (m_customTc == v)
        return;
    m_customTc = v;
    save("overlay.custom_tc", v);
    emit customTcChanged();
}

void OverlayPrefs::setCustomTr(const QString& v) {
    if (m_customTr == v)
        return;
    m_customTr = v;
    save("overlay.custom_tr", v);
    emit customTrChanged();
}

void OverlayPrefs::setCustomBl(const QString& v) {
    if (m_customBl == v)
        return;
    m_customBl = v;
    save("overlay.custom_bl", v);
    emit customBlChanged();
}

void OverlayPrefs::setCustomBc(const QString& v) {
    if (m_customBc == v)
        return;
    m_customBc = v;
    save("overlay.custom_bc", v);
    emit customBcChanged();
}

void OverlayPrefs::setCustomBr(const QString& v) {
    if (m_customBr == v)
        return;
    m_customBr = v;
    save("overlay.custom_br", v);
    emit customBrChanged();
}

void OverlayPrefs::setFontSize(int v) {
    if (m_fontSize == v)
        return;
    m_fontSize = v;
    save("overlay.font_size", QString::number(v));
    emit fontSizeChanged();
}

void OverlayPrefs::setTextColor(const QString& v) {
    if (m_textColor == v)
        return;
    m_textColor = v;
    save("overlay.text_color", v);
    emit textColorChanged();
}

void OverlayPrefs::setBgOpacity(double v) {
    if (qFuzzyCompare(m_bgOpacity, v))
        return;
    m_bgOpacity = v;
    save("overlay.bg_opacity", QString::number(v, 'f', 2));
    emit bgOpacityChanged();
}

void OverlayPrefs::setHeaderShowClose(bool v) {
    if (m_headerShowClose == v)
        return;
    m_headerShowClose = v;
    save("header.show_close", v ? "true" : "false");
    emit headerShowCloseChanged();
}

void OverlayPrefs::setHeaderShowExpand(bool v) {
    if (m_headerShowExpand == v)
        return;
    m_headerShowExpand = v;
    save("header.show_expand", v ? "true" : "false");
    emit headerShowExpandChanged();
}

void OverlayPrefs::setCameraPanelOpen(bool v) {
    if (m_cameraPanelOpen == v)
        return;
    m_cameraPanelOpen = v;
    save("cameraPanel.open", v ? "true" : "false");
    emit cameraPanelOpenChanged();
}

void OverlayPrefs::setRecordingsPanelOpen(bool v) {
    if (m_recordingsPanelOpen == v)
        return;
    m_recordingsPanelOpen = v;
    save("recordingsPanel.open", v ? "true" : "false");
    emit recordingsPanelOpenChanged();
}

void OverlayPrefs::setTimelineOpen(bool v) {
    if (m_timelineOpen == v)
        return;
    m_timelineOpen = v;
    save("timeline.open", v ? "true" : "false");
    emit timelineOpenChanged();
}

void OverlayPrefs::setFrontDockPanel(const QString& v) {
    if (m_frontDockPanel == v)
        return;
    m_frontDockPanel = v;
    save("dock.front_panel", v);
    emit frontDockPanelChanged();
}

void OverlayPrefs::setExcluded(const QString& cameraId, bool excluded) {
    const bool had = m_excludedCameras.contains(cameraId);
    if (excluded == had)
        return;
    if (excluded)
        m_excludedCameras.append(cameraId);
    else
        m_excludedCameras.removeAll(cameraId);
    saveExcluded();
    emit excludedCamerasChanged();
}
