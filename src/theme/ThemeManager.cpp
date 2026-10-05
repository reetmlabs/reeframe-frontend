// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "ThemeManager.h"

ThemeManager::ThemeManager(QObject* parent) : QObject(parent) { applyDarkPreset(); }

ThemeManager* ThemeManager::create(QQmlEngine*, QJSEngine*) {
    static ThemeManager s_instance;
    return &s_instance;
}

/* ----- Helpers ----- */

void ThemeManager::markCustom() {
    if (m_currentPreset == "custom")
        return;
    m_currentPreset = "custom";
    emit currentPresetChanged();
}

/* ----- Presets ----- */

void ThemeManager::applyPreset(const QString& name) {
    if (name == QStringLiteral("dark"))
        applyDarkPreset();
    else if (name == QStringLiteral("light"))
        applyLightPreset();
    else if (name == QStringLiteral("high-contrast"))
        applyHighContrastPreset();
}

void ThemeManager::resetToDefault() { applyDarkPreset(); }

void ThemeManager::applyDarkPreset() {
    // Aligned with Ant Design v5 dark palette for web/desktop coherence.
    m_surface = QColor("#141414");
    m_surfaceAlt = QColor("#1f1f1f");
    m_surfaceHover = QColor("#262626");
    m_surfaceCard = QColor("#0d0d0d");
    m_accent = QColor("#1677ff");
    m_accentHover = QColor("#4096ff");
    m_highlight = QColor("#ff4d4f");
    m_highlightHover = QColor("#ff7875");
    m_border = QColor("#303030");
    m_borderHover = QColor("#595959");
    m_focusRing = QColor("#69b1ff");
    m_success = QColor("#52c41a");
    m_warning = QColor("#faad14");
    m_error = QColor("#ff4d4f");
    m_info = QColor("#1677ff");
    m_textPrimary = QColor("#e8e8e8");
    m_textSecondary = QColor("#8c8c8c");
    m_textDisabled = QColor("#595959");
    m_textOnAccent = QColor("#ffffff");
    m_currentPreset = QStringLiteral("dark");
    emit themeChanged();
    emit currentPresetChanged();
}

void ThemeManager::applyLightPreset() {
    // Aligned with Ant Design v5 light palette.
    m_surface = QColor("#ffffff");
    m_surfaceAlt = QColor("#f5f5f5");
    m_surfaceHover = QColor("#f0f0f0");
    m_surfaceCard = QColor("#fafafa");
    m_accent = QColor("#1677ff");
    m_accentHover = QColor("#4096ff");
    m_highlight = QColor("#ff4d4f");
    m_highlightHover = QColor("#ff7875");
    m_border = QColor("#d9d9d9");
    m_borderHover = QColor("#bfbfbf");
    m_focusRing = QColor("#4096ff");
    m_success = QColor("#52c41a");
    m_warning = QColor("#faad14");
    m_error = QColor("#ff4d4f");
    m_info = QColor("#1677ff");
    m_textPrimary = QColor("#141414");
    m_textSecondary = QColor("#8c8c8c");
    m_textDisabled = QColor("#bfbfbf");
    m_textOnAccent = QColor("#ffffff");
    m_currentPreset = QStringLiteral("light");
    emit themeChanged();
    emit currentPresetChanged();
}

void ThemeManager::applyHighContrastPreset() {
    m_surface = QColor("#000000");
    m_surfaceAlt = QColor("#0a0a0a");
    m_surfaceHover = QColor("#111111");
    m_surfaceCard = QColor("#000000");
    m_accent = QColor("#1677ff");
    m_accentHover = QColor("#4096ff");
    m_highlight = QColor("#ff4d4f");
    m_highlightHover = QColor("#ff7875");
    m_border = QColor("#6b6b6b");
    m_borderHover = QColor("#ffffff");
    // Bright yellow keeps the focus ring distinct from both the hover border and the accent color.
    m_focusRing = QColor("#ffd666");
    m_success = QColor("#52c41a");
    m_warning = QColor("#faad14");
    m_error = QColor("#ff4d4f");
    m_info = QColor("#1677ff");
    m_textPrimary = QColor("#ffffff");
    m_textSecondary = QColor("#d9d9d9");
    m_textDisabled = QColor("#8c8c8c");
    m_textOnAccent = QColor("#ffffff");
    m_currentPreset = QStringLiteral("high-contrast");
    emit themeChanged();
    emit currentPresetChanged();
}

/* ----- Export / import ----- */

QVariantMap ThemeManager::exportColors() const {
    return {
        {"surface", m_surface.name()},
        {"surfaceAlt", m_surfaceAlt.name()},
        {"surfaceHover", m_surfaceHover.name()},
        {"surfaceCard", m_surfaceCard.name()},
        {"accent", m_accent.name()},
        {"accentHover", m_accentHover.name()},
        {"highlight", m_highlight.name()},
        {"highlightHover", m_highlightHover.name()},
        {"border", m_border.name()},
        {"borderHover", m_borderHover.name()},
        {"focusRing", m_focusRing.name()},
        {"success", m_success.name()},
        {"warning", m_warning.name()},
        {"error", m_error.name()},
        {"info", m_info.name()},
        {"textPrimary", m_textPrimary.name()},
        {"textSecondary", m_textSecondary.name()},
        {"textDisabled", m_textDisabled.name()},
        {"textOnAccent", m_textOnAccent.name()},
    };
}

void ThemeManager::importColors(const QVariantMap& colors) {
    auto get = [&](const QString& key, QColor& field) {
        auto it = colors.find(key);
        if (it != colors.end())
            field = QColor(it->toString());
    };
    get("surface", m_surface);
    get("surfaceAlt", m_surfaceAlt);
    get("surfaceHover", m_surfaceHover);
    get("surfaceCard", m_surfaceCard);
    get("accent", m_accent);
    get("accentHover", m_accentHover);
    get("highlight", m_highlight);
    get("highlightHover", m_highlightHover);
    get("border", m_border);
    get("borderHover", m_borderHover);
    get("focusRing", m_focusRing);
    get("success", m_success);
    get("warning", m_warning);
    get("error", m_error);
    get("info", m_info);
    get("textPrimary", m_textPrimary);
    get("textSecondary", m_textSecondary);
    get("textDisabled", m_textDisabled);
    get("textOnAccent", m_textOnAccent);
    m_currentPreset = QStringLiteral("custom");
    emit themeChanged();
    emit currentPresetChanged();
}

/* ----- Setters ----- */

void ThemeManager::setSurface(const QColor& v) {
    if (m_surface == v)
        return;
    m_surface = v;
    markCustom();
    emit surfaceChanged();
}

void ThemeManager::setSurfaceAlt(const QColor& v) {
    if (m_surfaceAlt == v)
        return;
    m_surfaceAlt = v;
    markCustom();
    emit surfaceAltChanged();
}

void ThemeManager::setSurfaceHover(const QColor& v) {
    if (m_surfaceHover == v)
        return;
    m_surfaceHover = v;
    markCustom();
    emit surfaceHoverChanged();
}

void ThemeManager::setSurfaceCard(const QColor& v) {
    if (m_surfaceCard == v)
        return;
    m_surfaceCard = v;
    markCustom();
    emit surfaceCardChanged();
}

void ThemeManager::setAccent(const QColor& v) {
    if (m_accent == v)
        return;
    m_accent = v;
    markCustom();
    emit accentChanged();
}

void ThemeManager::setAccentHover(const QColor& v) {
    if (m_accentHover == v)
        return;
    m_accentHover = v;
    markCustom();
    emit accentHoverChanged();
}

void ThemeManager::setHighlight(const QColor& v) {
    if (m_highlight == v)
        return;
    m_highlight = v;
    markCustom();
    emit highlightChanged();
}

void ThemeManager::setHighlightHover(const QColor& v) {
    if (m_highlightHover == v)
        return;
    m_highlightHover = v;
    markCustom();
    emit highlightHoverChanged();
}

void ThemeManager::setBorder(const QColor& v) {
    if (m_border == v)
        return;
    m_border = v;
    markCustom();
    emit borderChanged();
}

void ThemeManager::setBorderHover(const QColor& v) {
    if (m_borderHover == v)
        return;
    m_borderHover = v;
    markCustom();
    emit borderHoverChanged();
}

void ThemeManager::setFocusRing(const QColor& v) {
    if (m_focusRing == v)
        return;
    m_focusRing = v;
    markCustom();
    emit focusRingChanged();
}

void ThemeManager::setSuccess(const QColor& v) {
    if (m_success == v)
        return;
    m_success = v;
    markCustom();
    emit successChanged();
}

void ThemeManager::setWarning(const QColor& v) {
    if (m_warning == v)
        return;
    m_warning = v;
    markCustom();
    emit warningChanged();
}

void ThemeManager::setError(const QColor& v) {
    if (m_error == v)
        return;
    m_error = v;
    markCustom();
    emit errorChanged();
}

void ThemeManager::setInfo(const QColor& v) {
    if (m_info == v)
        return;
    m_info = v;
    markCustom();
    emit infoChanged();
}

void ThemeManager::setTextPrimary(const QColor& v) {
    if (m_textPrimary == v)
        return;
    m_textPrimary = v;
    markCustom();
    emit textPrimaryChanged();
}

void ThemeManager::setTextSecondary(const QColor& v) {
    if (m_textSecondary == v)
        return;
    m_textSecondary = v;
    markCustom();
    emit textSecondaryChanged();
}

void ThemeManager::setTextDisabled(const QColor& v) {
    if (m_textDisabled == v)
        return;
    m_textDisabled = v;
    markCustom();
    emit textDisabledChanged();
}

void ThemeManager::setTextOnAccent(const QColor& v) {
    if (m_textOnAccent == v)
        return;
    m_textOnAccent = v;
    markCustom();
    emit textOnAccentChanged();
}
