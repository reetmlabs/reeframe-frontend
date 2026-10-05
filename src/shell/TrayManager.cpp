// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "TrayManager.h"

#include <QAction>
#include <QCoreApplication>
#include <QEvent>
#include <QIcon>
#include <QMenu>
#include <QQuickWindow>

/* ----- Construction ----- */

TrayManager::TrayManager(QQuickWindow* window, QObject* parent)
    : QObject(parent), m_window(window), m_tray(new QSystemTrayIcon(this)) {
    buildMenu();
    updateIcon();

    m_trayAvailable = QSystemTrayIcon::isSystemTrayAvailable();
    if (m_trayAvailable) {
        m_tray->show();
        connect(m_tray, &QSystemTrayIcon::activated, this, &TrayManager::onActivated);
    }

    // Intercept close: hide to tray if available, otherwise quit (no tray means no way to reopen).
    m_window->installEventFilter(this);
}

/* ----- Event filter ----- */

bool TrayManager::eventFilter(QObject* obj, QEvent* event) {
    if (obj == m_window && event->type() == QEvent::Close) {
        if (m_trayAvailable) {
            m_window->hide();
            syncShowHideLabel();
        } else {
            qApp->quit();
        }
        return true;
    }
    return QObject::eventFilter(obj, event);
}

/* ----- Menu ----- */

void TrayManager::buildMenu() {
    m_menu = new QMenu();

    m_showHideAction = m_menu->addAction("Hide", this, &TrayManager::onShowHide);
    m_menu->addSeparator();
    m_menu->addAction("Quit", qApp, &QCoreApplication::quit);

    m_tray->setContextMenu(m_menu);
}

/* ----- Slots ----- */

void TrayManager::onActivated(QSystemTrayIcon::ActivationReason reason) {
    if (reason == QSystemTrayIcon::DoubleClick)
        onShowHide();
}

void TrayManager::onShowHide() {
    if (m_window->isVisible()) {
        m_window->hide();
    } else {
        m_window->show();
        m_window->raise();
        m_window->requestActivate();
    }
    syncShowHideLabel();
}

/* ----- Helpers ----- */

void TrayManager::syncShowHideLabel() {
    m_showHideAction->setText(m_window->isVisible() ? "Hide" : "Show");
}

void TrayManager::updateIcon() {
    QIcon icon;
    icon.addFile(":/icons/reframe-icon-16.png",  {16,  16});
    icon.addFile(":/icons/reframe-icon-32.png",  {32,  32});
    icon.addFile(":/icons/reframe-icon-48.png",  {48,  48});
    icon.addFile(":/icons/reframe-icon-256.png", {256, 256});
    if (icon.isNull())
        icon = QIcon::fromTheme("camera-video", QIcon::fromTheme("video-display"));
    m_tray->setIcon(icon);
    m_tray->setToolTip(m_alertBadge ? "Reeframe VMS — Alert" : "Reeframe VMS");
}

/* ----- Public API ----- */

void TrayManager::setAlertBadge(bool active) {
    if (m_alertBadge == active)
        return;
    m_alertBadge = active;
    updateIcon();
}
