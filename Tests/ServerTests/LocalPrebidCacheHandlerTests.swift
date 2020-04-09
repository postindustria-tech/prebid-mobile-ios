//
//  LocalPrebidCacheHandlerTests.swift
//  PrebidMobileTests
//
//  Created by Paul Dmitryev on 28.02.2020.
//  Copyright © 2020 AppNexus. All rights reserved.
//

import XCTest
@testable import PrebidMobile

class LocalPrebidCacheHandlerTests: XCTestCase {
    private static let cache = ResponseCache()
    private static let responder = LocalPrebidCacheHandler(responseCache: cache)

    private func createRequest(forItem: String) -> ServerRequest {
        let rawReq = """
        GET \(forItem) HTTP/1.1
        User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)
        Accept-Language: en-us
        Accept-Encoding: gzip, deflate
        Connection: Keep-Alive
        """.replacingOccurrences(of: "\n", with: "\r\n")

        return ServerRequest(rawRequest: rawReq)!
    }

    override static func setUp() {
        cache.store(response: "test", withId: "123")
    }

    func testRequests() {
        let expectations: [String: SimpleServerResponses] = [
            "/123": .ok(content: "test"),
            "/321": .errorNotFound,
            "something": .errorParsing
        ]

        for (req, expResp) in expectations {
            let request = createRequest(forItem: req)
            let response = LocalPrebidCacheHandlerTests.responder.respond(toRequest: request) as? SimpleServerResponses

            XCTAssertEqual(response, expResp)
        }

    }

    func testInvalidMethod() {
        let rawReq = """
        POST /123 HTTP/1.1
        User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)
        """.replacingOccurrences(of: "\n", with: "\r\n")

        let request = ServerRequest(rawRequest: rawReq)
        let response = LocalPrebidCacheHandlerTests.responder.respond(toRequest: request)

        guard case SimpleServerResponses.errorParsing = response else {
            XCTFail("Invalid response \(response)")
            return
        }
    }
}
