//
//  LocalCacheServer.swift
//  PrebidMobile
//
//  Created by Paul Dmitryev on 26.02.2020.
//

import Foundation

struct LocalCacheServer {
    private let server: SimpleServer
    private let cache: ResponseCache
    private let handler: LocalPrebidCacheHandler

    init(port: UInt16) {
        let certs: CFArray?
        if let certUrl = Bundle(for: Prebid.self).url(forResource: "lh-pi", withExtension: "p12"),
            let certData = try? Data(contentsOf: certUrl),
            let sslCertificate = try? TlsSession.loadP12Certificate(fromData: certData, withPassword: "pi12345") {
            certs = sslCertificate
        } else {
            certs = nil
        }

        cache = ResponseCache()
        handler = LocalPrebidCacheHandler(responseCache: cache)
        server = SimpleServer(port: port, handler: handler, certificates: certs)
    }

    @discardableResult
    func start() -> Bool {
        guard !server.started else {
            return true
        }
        return server.start()
    }

    func cache(response: String, withId respId: String) {
        cache.store(response: response, withId: respId)
    }
}
