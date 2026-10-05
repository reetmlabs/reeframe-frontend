// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// Coverage for EventModel::parseEvents()'s field-name mapping (backend
// snake_case EventDto[] -> camelCase), exercised via the
// parseEventsForTest() test-only seam, and EventTypeColors' generic
// type->color mapping.
TestCase {
    id: testCase
    name: "EventModelParsing"

    function test_mapsBackendFieldNamesToTheExpectedShape() {
        const json = JSON.stringify([
            { id: "evt-1", camera_id: "cam-1", event_type: "motion_started",
              occurred_at: "2026-07-23T10:00:00Z", payload: { confidence: 0.9 } }
        ])

        const events = EventModel.parseEventsForTest(json)
        compare(events.length, 1)
        compare(events[0].id, "evt-1")
        compare(events[0].eventType, "motion_started")
        compare(events[0].occurredAt, "2026-07-23T10:00:00Z")
        compare(events[0].payload.confidence, 0.9)
    }

    function test_emptyArrayProducesNoEvents() {
        compare(EventModel.parseEventsForTest("[]").length, 0)
    }

    function test_knownEventTypesGetStableDistinctColors() {
        const seen = {}
        for (const type of EventTypeColors.knownTypes) {
            const color = EventTypeColors.colorFor(type)
            verify(!seen[color], "two known types must not share a color: " + type)
            seen[color] = true
            compare(color !== EventTypeColors.fallbackColor, true)
        }
    }

    function test_unknownEventTypeGetsTheFallbackColor() {
        compare(EventTypeColors.colorFor("pipeline_trigger"), EventTypeColors.fallbackColor)
        compare(EventTypeColors.colorFor("some_future_type"), EventTypeColors.fallbackColor)
    }
}
