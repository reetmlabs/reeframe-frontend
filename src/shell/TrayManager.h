// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QObject>
#include <QSystemTrayIcon>

class QMenu;
class QAction;
class QQuickWindow;

class TrayManager : public QObject {
    Q_OBJECT

  public:
    explicit TrayManager(QQuickWindow* window, QObject* parent = nullptr);

    void setAlertBadge(bool active);

  protected:
    bool eventFilter(QObject* obj, QEvent* event) override;

  private slots:
    void onActivated(QSystemTrayIcon::ActivationReason reason);
    void onShowHide();

  private:
    /* ----- helpers ----- */
    void buildMenu();
    void updateIcon();
    void syncShowHideLabel();

    /* ----- state ----- */
    QQuickWindow* m_window;
    QSystemTrayIcon* m_tray;
    QMenu* m_menu;
    QAction* m_showHideAction;
    bool m_alertBadge = false;
    bool m_trayAvailable = false;
};
