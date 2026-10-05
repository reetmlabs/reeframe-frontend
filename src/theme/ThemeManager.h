// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QColor>
#include <QObject>
#include <QStringList>
#include <QVariantMap>
#include <QtQml/qqml.h>

// Exposed to QML as the singleton "Theme".
// Spacing, radius, font, and duration tokens are design constants.
class ThemeManager : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(Theme)
    QML_SINGLETON

    // - Surfaces -
    Q_PROPERTY(QColor surface READ surface WRITE setSurface NOTIFY surfaceChanged)
    Q_PROPERTY(QColor surfaceAlt READ surfaceAlt WRITE setSurfaceAlt NOTIFY surfaceAltChanged)
    Q_PROPERTY(
        QColor surfaceHover READ surfaceHover WRITE setSurfaceHover NOTIFY surfaceHoverChanged)
    Q_PROPERTY(QColor surfaceCard READ surfaceCard WRITE setSurfaceCard NOTIFY surfaceCardChanged)

    // - Accent -
    Q_PROPERTY(QColor accent READ accent WRITE setAccent NOTIFY accentChanged)
    Q_PROPERTY(QColor accentHover READ accentHover WRITE setAccentHover NOTIFY accentHoverChanged)
    Q_PROPERTY(QColor highlight READ highlight WRITE setHighlight NOTIFY highlightChanged)
    Q_PROPERTY(QColor highlightHover READ highlightHover WRITE setHighlightHover NOTIFY
                   highlightHoverChanged)

    // - Borders -
    Q_PROPERTY(QColor border READ border WRITE setBorder NOTIFY borderChanged)
    Q_PROPERTY(QColor borderHover READ borderHover WRITE setBorderHover NOTIFY borderHoverChanged)
    Q_PROPERTY(QColor focusRing READ focusRing WRITE setFocusRing NOTIFY focusRingChanged)

    // - Semantic -
    Q_PROPERTY(QColor success READ success WRITE setSuccess NOTIFY successChanged)
    Q_PROPERTY(QColor warning READ warning WRITE setWarning NOTIFY warningChanged)
    Q_PROPERTY(QColor error READ error WRITE setError NOTIFY errorChanged)
    Q_PROPERTY(QColor info READ info WRITE setInfo NOTIFY infoChanged)

    // - Text -
    Q_PROPERTY(QColor textPrimary READ textPrimary WRITE setTextPrimary NOTIFY textPrimaryChanged)
    Q_PROPERTY(
        QColor textSecondary READ textSecondary WRITE setTextSecondary NOTIFY textSecondaryChanged)
    Q_PROPERTY(
        QColor textDisabled READ textDisabled WRITE setTextDisabled NOTIFY textDisabledChanged)
    Q_PROPERTY(
        QColor textOnAccent READ textOnAccent WRITE setTextOnAccent NOTIFY textOnAccentChanged)

    // - Spacing (design constants) -
    Q_PROPERTY(int spaceXs READ spaceXs CONSTANT)
    Q_PROPERTY(int spaceS READ spaceS CONSTANT)
    Q_PROPERTY(int spaceM READ spaceM CONSTANT)
    Q_PROPERTY(int spaceL READ spaceL CONSTANT)
    Q_PROPERTY(int spaceXl READ spaceXl CONSTANT)
    Q_PROPERTY(int space2xl READ space2xl CONSTANT)
    Q_PROPERTY(int space3xl READ space3xl CONSTANT)

    // - Radius (design constants) -
    Q_PROPERTY(int radiusS READ radiusS CONSTANT)
    Q_PROPERTY(int radiusM READ radiusM CONSTANT)
    Q_PROPERTY(int radiusL READ radiusL CONSTANT)

    // - Font sizes (design constants) -
    Q_PROPERTY(int fontXs READ fontXs CONSTANT)
    Q_PROPERTY(int fontS READ fontS CONSTANT)
    Q_PROPERTY(int fontM READ fontM CONSTANT)
    Q_PROPERTY(int fontL READ fontL CONSTANT)
    Q_PROPERTY(int fontXl READ fontXl CONSTANT)
    Q_PROPERTY(int font2xl READ font2xl CONSTANT)

    // - Animation durations ms (design constants) -
    Q_PROPERTY(int durationFast READ durationFast CONSTANT)
    Q_PROPERTY(int durationNormal READ durationNormal CONSTANT)
    Q_PROPERTY(int durationSlow READ durationSlow CONSTANT)

    // - Layout (design constants) -
    Q_PROPERTY(int sidebarWidth READ sidebarWidth CONSTANT)
    Q_PROPERTY(int sidebarCollapsedWidth READ sidebarCollapsedWidth CONSTANT)

    // - Preset management -
    Q_PROPERTY(QString currentPreset READ currentPreset NOTIFY currentPresetChanged)
    Q_PROPERTY(QStringList presets READ presets CONSTANT)
    Q_PROPERTY(bool isDark READ isDark NOTIFY themeChanged)

  public:
    explicit ThemeManager(QObject* parent = nullptr);
    static ThemeManager* create(QQmlEngine* qmlEngine, QJSEngine* jsEngine);

    // Invokable from QML
    Q_INVOKABLE void applyPreset(const QString& name);
    Q_INVOKABLE void resetToDefault();
    Q_INVOKABLE QVariantMap exportColors() const;
    Q_INVOKABLE void importColors(const QVariantMap& colors);

    // Color getters
    QColor surface() const { return m_surface; }
    QColor surfaceAlt() const { return m_surfaceAlt; }
    QColor surfaceHover() const { return m_surfaceHover; }
    QColor surfaceCard() const { return m_surfaceCard; }
    QColor accent() const { return m_accent; }
    QColor accentHover() const { return m_accentHover; }
    QColor highlight() const { return m_highlight; }
    QColor highlightHover() const { return m_highlightHover; }
    QColor border() const { return m_border; }
    QColor borderHover() const { return m_borderHover; }
    QColor focusRing() const { return m_focusRing; }
    QColor success() const { return m_success; }
    QColor warning() const { return m_warning; }
    QColor error() const { return m_error; }
    QColor info() const { return m_info; }
    QColor textPrimary() const { return m_textPrimary; }
    QColor textSecondary() const { return m_textSecondary; }
    QColor textDisabled() const { return m_textDisabled; }
    QColor textOnAccent() const { return m_textOnAccent; }

    // Color setters
    void setSurface(const QColor& v);
    void setSurfaceAlt(const QColor& v);
    void setSurfaceHover(const QColor& v);
    void setSurfaceCard(const QColor& v);
    void setAccent(const QColor& v);
    void setAccentHover(const QColor& v);
    void setHighlight(const QColor& v);
    void setHighlightHover(const QColor& v);
    void setBorder(const QColor& v);
    void setBorderHover(const QColor& v);
    void setFocusRing(const QColor& v);
    void setSuccess(const QColor& v);
    void setWarning(const QColor& v);
    void setError(const QColor& v);
    void setInfo(const QColor& v);
    void setTextPrimary(const QColor& v);
    void setTextSecondary(const QColor& v);
    void setTextDisabled(const QColor& v);
    void setTextOnAccent(const QColor& v);

    // Spacing constants
    int spaceXs() const { return 4; }
    int spaceS() const { return 8; }
    int spaceM() const { return 12; }
    int spaceL() const { return 16; }
    int spaceXl() const { return 24; }
    int space2xl() const { return 32; }
    int space3xl() const { return 48; }

    // Radius constants
    int radiusS() const { return 4; }
    int radiusM() const { return 8; }
    int radiusL() const { return 12; }

    // Font size constants
    int fontXs() const { return 10; }
    int fontS() const { return 12; }
    int fontM() const { return 14; }
    int fontL() const { return 16; }
    int fontXl() const { return 20; }
    int font2xl() const { return 28; }

    // Duration constants
    int durationFast() const { return 100; }
    int durationNormal() const { return 200; }
    int durationSlow() const { return 300; }

    // Layout constants
    int sidebarWidth() const { return 220; }
    int sidebarCollapsedWidth() const { return 48; }

    // Preset
    QString currentPreset() const { return m_currentPreset; }
    bool isDark() const { return m_surface.lightnessF() < 0.5; }
    QStringList presets() const {
        return {QStringLiteral("dark"), QStringLiteral("high-contrast")};
    }

  signals:
    void surfaceChanged();
    void surfaceAltChanged();
    void surfaceHoverChanged();
    void surfaceCardChanged();
    void accentChanged();
    void accentHoverChanged();
    void highlightChanged();
    void highlightHoverChanged();
    void borderChanged();
    void borderHoverChanged();
    void focusRingChanged();
    void successChanged();
    void warningChanged();
    void errorChanged();
    void infoChanged();
    void textPrimaryChanged();
    void textSecondaryChanged();
    void textDisabledChanged();
    void textOnAccentChanged();
    void currentPresetChanged();
    void themeChanged();

  private:
    void markCustom();
    void applyDarkPreset();
    void applyLightPreset();
    void applyHighContrastPreset();

    QColor m_surface;
    QColor m_surfaceAlt;
    QColor m_surfaceHover;
    QColor m_surfaceCard;
    QColor m_accent;
    QColor m_accentHover;
    QColor m_highlight;
    QColor m_highlightHover;
    QColor m_border;
    QColor m_borderHover;
    QColor m_focusRing;
    QColor m_success;
    QColor m_warning;
    QColor m_error;
    QColor m_info;
    QColor m_textPrimary;
    QColor m_textSecondary;
    QColor m_textDisabled;
    QColor m_textOnAccent;
    QString m_currentPreset;
};
