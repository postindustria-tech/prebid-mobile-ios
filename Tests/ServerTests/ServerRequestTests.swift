//
//  RequestParsingTests.swift
//  PrebidMobileTests
//
//  Created by Paul Dmitryev on 26.02.2020.
//  Copyright © 2020 AppNexus. All rights reserved.
//

import XCTest
@testable import PrebidMobile

class ServerRequestTests: XCTestCase {
    private static let correctExample = """
    GET /hello.html HTTP/1.1
    User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)
    Accept-Language: en-us
    Accept-Encoding: gzip, deflate
    Connection: Keep-Alive
    """.replacingOccurrences(of: "\n", with: "\r\n")

    private static let invalidFirstLine1 = """
    GET /hello.html
    User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)
    """.replacingOccurrences(of: "\n", with: "\r\n")

    private static let invalidFirstLine2 = """
    GET /hello.html HTTP/1.1 # version!
    User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)
    """.replacingOccurrences(of: "\n", with: "\r\n")

    private static let invalidNewlines = """
    GET /hello.html HTTP/1.1 # version!
    User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)
    """

    func testCorrectParsing() {
        let request = ServerRequest(rawRequest: ServerRequestTests.correctExample)
        XCTAssertEqual(request?.method.lowercased(), "get")
        XCTAssertEqual(request?.parameters.lowercased(), "/hello.html")
    }

    func testInvalidCases() {
        XCTAssertNil(ServerRequest(rawRequest: ServerRequestTests.invalidFirstLine1))
        XCTAssertNil(ServerRequest(rawRequest: ServerRequestTests.invalidFirstLine2))
        XCTAssertNil(ServerRequest(rawRequest: ServerRequestTests.invalidNewlines))
        XCTAssertNil(ServerRequest(rawRequest: nil))
        XCTAssertNil(ServerRequest(rawRequest: ""))
    }
}
