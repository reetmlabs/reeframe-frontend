.pragma library

// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

// Portable, plain-JS pipeline validation with no Qt/QML dependency, so this same
// logic can run unmodified in the web app against the identical node/edge shape
// (see PipelineGraphModel.nodes/.edges for that shape).

// Returns the ids of every node in at least one cycle, or an empty array if
// the graph is acyclic. Kahn's algorithm: repeatedly remove nodes with no
// remaining incoming edge; whatever's left once nothing more can be removed
// is exactly the set of nodes participating in a cycle.
function findCycleNodeIds(nodes, edges) {
    const remaining = new Set(nodes.map((n) => n.id))
    const incomingCount = new Map()
    for (const id of remaining) incomingCount.set(id, 0)
    for (const e of edges) {
        if (incomingCount.has(e.toNodeId))
            incomingCount.set(e.toNodeId, incomingCount.get(e.toNodeId) + 1)
    }

    let progressed = true
    while (progressed) {
        progressed = false
        for (const id of Array.from(remaining)) {
            if (incomingCount.get(id) !== 0) continue
            remaining.delete(id)
            progressed = true
            for (const e of edges) {
                if (e.fromNodeId === id && remaining.has(e.toNodeId))
                    incomingCount.set(e.toNodeId, incomingCount.get(e.toNodeId) - 1)
            }
        }
    }
    return Array.from(remaining)
}

function checkStructural(nodes, edges) {
    const problems = []

    const triggerNodes = nodes.filter((n) => n.type === "trigger_root")
    if (triggerNodes.length === 0) {
        problems.push({ severity: "error", category: "structural", nodeId: null,
                         message: "No trigger node found." })
    } else if (triggerNodes.length > 1) {
        problems.push({ severity: "error", category: "structural", nodeId: null,
                         nodeIds: triggerNodes.map((n) => n.id),
                         message: "More than one trigger node found." })
    }

    const cycleIds = findCycleNodeIds(nodes, edges)
    if (cycleIds.length > 0) {
        problems.push({ severity: "error", category: "structural", nodeId: null,
                         nodeIds: cycleIds, message: "Cycle detected in the pipeline graph." })
    }

    for (const n of nodes) {
        if (n.type === "condition") {
            const out = edges.filter((e) => e.fromNodeId === n.id)
            const hasTrue = out.some((e) => e.edgeType === "condition_true")
            const hasFalse = out.some((e) => e.edgeType === "condition_false")
            if (out.length !== 2 || !hasTrue || !hasFalse) {
                problems.push({ severity: "error", category: "structural", nodeId: n.id,
                                 message: "Condition node must have exactly one true and one false outgoing edge." })
            }
        } else if (n.type === "transport" || n.type === "device_control") {
            if (edges.some((e) => e.fromNodeId === n.id)) {
                problems.push({ severity: "error", category: "structural", nodeId: n.id,
                                 message: "This node type cannot have an outgoing edge." })
            }
        }
    }

    return problems
}

// A node missing a value its type needs to do anything (distinct from
// checkStructural's edge/branch-shape rules above). Only fields with no
// sensible default are checked here (e.g. a stat trigger's threshold/cooldown
// always have one committed already, so there's nothing to flag).
function checkConfigIncomplete(nodes) {
    const problems = []

    for (const n of nodes) {
        const cfg = n.config || {}

        if (n.type === "trigger_root") {
            if (!cfg.trigger_type) {
                problems.push({ severity: "error", category: "config_incomplete", nodeId: n.id,
                                 message: "Trigger type not selected." })
            } else if (cfg.trigger_type === "schedule" && !cfg.cron) {
                problems.push({ severity: "error", category: "config_incomplete", nodeId: n.id,
                                 message: "Schedule trigger requires a cron expression." })
            }
        } else if (n.type === "condition") {
            if (!cfg.condition_expr) {
                problems.push({ severity: "error", category: "config_incomplete", nodeId: n.id,
                                 message: "Condition node requires an expression." })
            }
        } else if (n.type === "transport") {
            if (!cfg.destination_id) {
                problems.push({ severity: "error", category: "config_incomplete", nodeId: n.id,
                                 message: "Transport node requires a destination." })
            }
        } else if (n.type === "action" || n.type === "device_control") {
            if (!cfg.action_type) {
                problems.push({ severity: "error", category: "config_incomplete", nodeId: n.id,
                                 message: "Action type not selected." })
            }
        }
    }

    return problems
}

// Nodes unreachable from the trigger by following edges forward. This covers
// any node in a sub-graph that never traces back to the root (e.g. two nodes
// chained to each other but to nothing else), not only nodes with zero edges.
// Skipped when there isn't exactly one trigger, since checkStructural already
// covers that case and "reachable from the root" has no single meaning then.
function checkDisconnected(nodes, edges) {
    const triggerNodes = nodes.filter((n) => n.type === "trigger_root")
    if (triggerNodes.length !== 1) return []

    const reachable = new Set([triggerNodes[0].id])
    let progressed = true
    while (progressed) {
        progressed = false
        for (const e of edges) {
            if (reachable.has(e.fromNodeId) && !reachable.has(e.toNodeId)) {
                reachable.add(e.toNodeId)
                progressed = true
            }
        }
    }

    const problems = []
    for (const n of nodes) {
        if (!reachable.has(n.id)) {
            problems.push({ severity: "warning", category: "disconnected", nodeId: n.id,
                             message: "This node is not reachable from the trigger." })
        }
    }
    return problems
}

// Only these action types carry a camera_id, and only as a bare string inside
// the config JSON. Nothing enforces it still points at a real Camera the way
// a real foreign key would, so a deleted Camera leaves it silently dangling.
const CAMERA_ID_ACTION_TYPES = new Set([
    "extract_clip", "snapshot", "ptz_move", "start_recording", "stop_recording", "set_stream_quality",
])

function checkDanglingCameraReference(nodes, cameraIds) {
    const problems = []
    const validIds = new Set(cameraIds)

    for (const n of nodes) {
        const cfg = n.config || {}
        if (!CAMERA_ID_ACTION_TYPES.has(cfg.action_type)) continue
        if (!cfg.camera_id) continue
        if (!validIds.has(cfg.camera_id)) {
            problems.push({ severity: "error", category: "dangling_camera", nodeId: n.id,
                             message: "This node's camera no longer exists." })
        }
    }

    return problems
}

// Only these two action types originate a footage artifact from a camera.
// Every other artifact-producing action (Transcode, Merge Clips, Compress,
// Encrypt, Watermark) only transforms an artifact one of these, or another
// pass-through, already produced further upstream.
const ARTIFACT_SOURCE_ACTION_TYPES = new Set(["extract_clip", "snapshot"])
const ARTIFACT_PASS_THROUGH_ACTION_TYPES = new Set(["transcode", "merge_clips"])

// Whether nodeId is itself an artifact source, or descends from one via any
// chain of incoming edges. `visited` guards against a cycle already flagged
// by checkStructural sending this into a loop instead of terminating.
function isOrDescendsFromArtifactSource(nodeId, nodes, edges, visited) {
    if (visited.has(nodeId)) return false
    visited.add(nodeId)

    const node = nodes.find((n) => n.id === nodeId)
    if (node && ARTIFACT_SOURCE_ACTION_TYPES.has((node.config || {}).action_type)) return true

    return edges.some((e) => e.toNodeId === nodeId
        && isOrDescendsFromArtifactSource(e.fromNodeId, nodes, edges, visited))
}

function checkMissingArtifactSource(nodes, edges) {
    const problems = []

    for (const n of nodes) {
        const cfg = n.config || {}
        if (!ARTIFACT_PASS_THROUGH_ACTION_TYPES.has(cfg.action_type)) continue

        const incoming = edges.filter((e) => e.toNodeId === n.id)
        const producingBranches = incoming.filter((e) =>
            isOrDescendsFromArtifactSource(e.fromNodeId, nodes, edges, new Set()))

        if (producingBranches.length === 0) {
            problems.push({ severity: "error", category: "missing_artifact_source", nodeId: n.id,
                             message: "This node has no Extract Clip or Snapshot upstream to provide footage." })
        } else if (cfg.action_type === "merge_clips" && producingBranches.length === 1) {
            problems.push({ severity: "warning", category: "missing_artifact_source", nodeId: n.id,
                             message: "Only one clip feeds this node — there's nothing to merge." })
        }
    }

    return problems
}

function computeProblems(nodes, edges, cameraIds) {
    return checkStructural(nodes, edges)
        .concat(checkConfigIncomplete(nodes))
        .concat(checkDisconnected(nodes, edges))
        .concat(checkDanglingCameraReference(nodes, cameraIds))
        .concat(checkMissingArtifactSource(nodes, edges))
}
