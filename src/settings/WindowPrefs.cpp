// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "WindowPrefs.h"
#include "AppDatabase.h"

WindowPrefs::WindowPrefs(AppDatabase* db, QObject* parent) : QObject(parent), m_db(db) {
    const QString savedWidth = m_db->preference("window.width", QString());
    m_hasSavedGeometry = !savedWidth.isEmpty();
    if (m_hasSavedGeometry) {
        m_x = m_db->preference("window.x", "0").toInt();
        m_y = m_db->preference("window.y", "0").toInt();
        m_width = savedWidth.toInt();
        m_height = m_db->preference("window.height", "800").toInt();
    }
    m_maximized = m_db->preference("window.maximized", "false") == "true";
}

void WindowPrefs::setX(int v) {
    if (m_x == v)
        return;
    m_x = v;
    m_db->setPreference("window.x", QString::number(v));
    emit xChanged();
}

void WindowPrefs::setY(int v) {
    if (m_y == v)
        return;
    m_y = v;
    m_db->setPreference("window.y", QString::number(v));
    emit yChanged();
}

void WindowPrefs::setWidth(int v) {
    if (m_width == v)
        return;
    m_width = v;
    m_db->setPreference("window.width", QString::number(v));
    emit widthChanged();
}

void WindowPrefs::setHeight(int v) {
    if (m_height == v)
        return;
    m_height = v;
    m_db->setPreference("window.height", QString::number(v));
    emit heightChanged();
}

void WindowPrefs::setMaximized(bool v) {
    if (m_maximized == v)
        return;
    m_maximized = v;
    m_db->setPreference("window.maximized", v ? "true" : "false");
    emit maximizedChanged();
}
