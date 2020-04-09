//
//  SimpleServerResponsesTest.swift
//  PrebidMobileTests
//
//  Created by Paul Dmitryev on 28.02.2020.
//  Copyright © 2020 AppNexus. All rights reserved.
//

import XCTest
@testable import PrebidMobile

class SimpleServerResponsesTest: XCTestCase {
    private func assertNoOrder<T: Hashable>(_ left: [T], _ right: [T]) {
        XCTAssertEqual(Set(left), Set(right))
    }

    func test200Response() {
        let resp = SimpleServerResponses.ok(content: "test")

        XCTAssertEqual(resp.body, "test")
        assertNoOrder(resp.headers, ["HTTP/1.1 200 OK", "Access-Control-Allow-Origin: *", "Server: Simple HTTP Server",
                                     "Content-Length: 4"])
    }

    func test404Response() {
        let resp = SimpleServerResponses.errorNotFound
        assertNoOrder(resp.headers, ["HTTP/1.1 404 Not found", "Access-Control-Allow-Origin: *",
                                     "Server: Simple HTTP Server", "Content-Length: 9"])
    }

    func test400Error() {
        let resp = SimpleServerResponses.errorParsing
        assertNoOrder(resp.headers, ["HTTP/1.1 400 Bad request", "Access-Control-Allow-Origin: *",
                                     "Server: Simple HTTP Server", "Content-Length: 11"])
    }
}
