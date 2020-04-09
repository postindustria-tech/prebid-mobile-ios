//
//  ResponseCache.swift
//  PrebidMobile
//
//  Created by Paul Dmitryev on 26.02.2020.
//

import Foundation

class ResponseCache {
    let syncQueue = DispatchQueue(label: "simple.http.server.sync")
    private var responses: [String: String] = [:]

    func store(response: String, withId cacheId: String) {
        syncQueue.sync {
            responses[cacheId] = response
        }
    }

    func getResponse(forId cacheId: String) -> String? {
        return syncQueue.sync {
            responses[cacheId]
        }
    }
}
