// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QObject>

class AppDatabase;

class WindowPrefs : public QObject {
    Q_OBJECT

    Q_PROPERTY(int x READ x WRITE setX NOTIFY xChanged)
    Q_PROPERTY(int y READ y WRITE setY NOTIFY yChanged)
    Q_PROPERTY(int width READ width WRITE setWidth NOTIFY widthChanged)
    Q_PROPERTY(int height READ height WRITE setHeight NOTIFY heightChanged)
    Q_PROPERTY(bool maximized READ maximized WRITE setMaximized NOTIFY maximizedChanged)
    Q_PROPERTY(bool hasSavedGeometry READ hasSavedGeometry CONSTANT)

  public:
    explicit WindowPrefs(AppDatabase* db, QObject* parent = nullptr);

    int x() const { return m_x; }
    int y() const { return m_y; }
    int width() const { return m_width; }
    int height() const { return m_height; }
    bool maximized() const { return m_maximized; }
    bool hasSavedGeometry() const { return m_hasSavedGeometry; }

    void setX(int v);
    void setY(int v);
    void setWidth(int v);
    void setHeight(int v);
    void setMaximized(bool v);

  signals:
    void xChanged();
    void yChanged();
    void widthChanged();
    void heightChanged();
    void maximizedChanged();

  private:
    AppDatabase* m_db;
    int m_x = 0;
    int m_y = 0;
    int m_width = 1280;
    int m_height = 800;
    bool m_maximized = false;
    bool m_hasSavedGeometry = false;
};
