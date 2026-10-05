// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <QJsonDocument>
#include <QObject>
#include <QString>
#include <QVariantList>

class SiteManager;

// Fetches persisted camera events (motion/tamper/signal-loss/etc, see the
// backend's `events` table) for the timeline's event markers. One fetch is
// scoped to a single camera and date range; aggregating markers across
// several cameras at once (the matrix-wide timeline view) is the caller's
// job: issue one fetchEvents() per camera and merge the results. See
// TimelineBar.qml's event-marker wiring.
class EventModel : public QObject {
    Q_OBJECT
  public:
    explicit EventModel(SiteManager* siteManager, QObject* parent = nullptr);

    // from/to are RFC 3339 timestamps. cameraId is echoed back on both
    // signals since several fetches (one per visible camera tile) can be
    // in flight at once.
    Q_INVOKABLE void fetchEvents(const QString& cameraId, const QString& from, const QString& to);

    // Test-only seam, mirroring RecordingModel::parseDailySummaryForTest.
    // Exercises the backend's snake_case EventDto[] parsing without a real
    // network round trip.
    Q_INVOKABLE QVariantList parseEventsForTest(const QString& json) const;

  signals:
    void eventsFetched(const QString& cameraId, const QVariantList& events);
    void eventsFetchFailed(const QString& cameraId, const QString& message);

  private:
    static QVariantList parseEvents(const QJsonDocument& doc);

    SiteManager* m_siteManager;
};
