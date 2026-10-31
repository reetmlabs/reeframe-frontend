// SPDX-FileCopyrightText: 2026 Mohammad Armoun
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import QtTest
import Reeframe

// PipelineGraphModel.load() fetches nodes, edges and the trigger config in
// three requests. It publishes the result once, after the last reply, so the
// canvas never rebuilds its nodes mid-load and destroys a node the user has
// started dragging.
TestCase {
    id: testCase
    name: "PipelineGraphModelLoad"
    when: windowShown

    property int nodesChanges: 0
    property int edgesChanges: 0
    property int triggerRequestsAtFirstNodesChange: -1
    property string pipelineId: ""

    Connections {
        target: PipelineGraphModel
        function onNodesChanged() {
            testCase.nodesChanges++
            if (testCase.triggerRequestsAtFirstNodesChange < 0)
                testCase.triggerRequestsAtFirstNodesChange =
                    EmptyBackend.requestCountFor("/pipelines/" + testCase.pipelineId + "/triggers")
        }
        function onEdgesChanged() { testCase.edgesChanges++ }
    }

    function clearAllConnections() {
        const urls = CoordinatorManager.urls()
        for (let i = 0; i < urls.length; i++)
            CoordinatorManager.removeConnection(urls[i])
    }

    function init() {
        clearAllConnections()
        // Refuses connections, so the site's token request fails at once
        // (see tst_CameraListBackgroundRefresh.qml).
        const url = "http://127.0.0.1:1/coord-" + Date.now() + "-" + Math.random()
        CoordinatorManager.addConnection(url)
        const beId = "qmltest-be-" + Date.now() + "-" + Math.random()
        SiteManager.seedRemoteSiteForTest(url, beId, "Pipeline Load", EmptyBackend.url)
        SiteManager.activeSiteIndex = SiteManager.siteIndexById(beId)
        tryCompare(SiteManager, "activeSiteStatus", 2, 3000)
    }

    function cleanup() {
        SiteManager.clearRemoteSitesForTest()
        clearAllConnections()
        wait(50)
    }

    function test_loadPublishesNodesAndEdgesOnceAfterEveryReply() {
        pipelineId = "load-test-" + Date.now()
        nodesChanges = 0
        edgesChanges = 0
        triggerRequestsAtFirstNodesChange = -1

        PipelineGraphModel.load(pipelineId)
        tryCompare(PipelineGraphModel, "loading", false, 3000)

        compare(nodesChanges, 1, "load() must publish the nodes exactly once")
        compare(edgesChanges, 1, "load() must publish the edges exactly once")
        compare(triggerRequestsAtFirstNodesChange, 1,
                "nodes must not be published before the last request has been answered")
    }
}
