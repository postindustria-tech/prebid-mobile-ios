//
//  ServerResponseHandler.swift
//  PrebidMobile
//
//  Created by Paul Dmitryev on 26.02.2020.
//

import Foundation

protocol ServerResponseHandler {
    func respond(toRequest: ServerRequest?) -> ServerResponse
}

class LocalPrebidCacheHandler: ServerResponseHandler {
    private let respCache: ResponseCache

    init(responseCache: ResponseCache) {
        respCache = responseCache
    }

    func respond(toRequest: ServerRequest?) -> ServerResponse {
        guard let request = toRequest, request.method.lowercased() == "get" else {
            return SimpleServerResponses.errorParsing
        }
        guard request.parameters.starts(with: "/") else {
            return SimpleServerResponses.errorParsing
        }
        let cacheKey = String(request.parameters.dropFirst())
        if let cachedResponse = respCache.getResponse(forId: cacheKey) {
            return SimpleServerResponses.ok(content: cachedResponse)
        } else {
            return SimpleServerResponses.errorNotFound
        }
    }
}
