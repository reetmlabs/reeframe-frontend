// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

#include "EventModel.h"
#include "SiteManager.h"
#include <QJsonArray>
#include <QJsonObject>
#include <QRestReply>
#include <QUrl>
#include <QVariantMap>

// Mirrors RecordingModel.cpp's own describeFailure(): reply.errorString() is
// transport-level only (empty for ordinary non-2xx replies). The real
// reason lives in the JSON body's "error" field.
static QString describeFailure(QRestReply& reply) {
    const auto doc = reply.readJson();
    const QString message =
        doc && doc->isObject() ? doc->object().value("error").toString() : QString{};
    return QStringLiteral("HTTP %1%2")
        .arg(reply.httpStatus())
        .arg(message.isEmpty() ? QString{} : QStringLiteral(" - ") + message);
}

EventModel::EventModel(SiteManager* siteManager, QObject* parent)
    : QObject(parent), m_siteManager(siteManager) {}

void EventModel::fetchEvents(const QString& cameraId, const QString& from, const QString& to) {
    auto* client = m_siteManager->clientForSite(m_siteManager->activeSiteId());
    if (!client)
        return;
    const QString path = QString("/cameras/%1/events?from=%2&to=%3")
                             .arg(cameraId, QString(QUrl::toPercentEncoding(from)),
                                  QString(QUrl::toPercentEncoding(to)));
    client->get(path, this, [this, cameraId](QRestReply& reply) {
        if (!reply.isSuccess()) {
            emit eventsFetchFailed(cameraId, describeFailure(reply));
            return;
        }
        const auto doc = reply.readJson();
        if (!doc || !doc->isArray()) {
            emit eventsFetchFailed(cameraId, QStringLiteral("unexpected response shape"));
            return;
        }
        emit eventsFetched(cameraId, parseEvents(*doc));
    });
}

QVariantList EventModel::parseEventsForTest(const QString& json) const {
    return parseEvents(QJsonDocument::fromJson(json.toUtf8()));
}

// Maps the backend's snake_case EventDto[] onto a camelCase shape:
// {id, eventType, occurredAt, payload}.
QVariantList EventModel::parseEvents(const QJsonDocument& doc) {
    QVariantList events;
    if (!doc.isArray())
        return events;

    for (const auto& val : doc.array()) {
        const auto obj = val.toObject();
        QVariantMap event;
        event["id"] = obj.value("id").toString();
        event["eventType"] = obj.value("event_type").toString();
        event["occurredAt"] = obj.value("occurred_at").toString();
        event["payload"] = obj.value("payload").toVariant();
        events.append(event);
    }
    return events;
}
