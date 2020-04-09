//
//  CacheServerTest.swift
//  PrebidMobileTests
//
//  Created by Paul Dmitryev on 27.02.2020.
//  Copyright © 2020 AppNexus. All rights reserved.
//

import XCTest
@testable import PrebidMobile

class LocalCacheServerTests: XCTestCase {
    func testExample() {
        let server = LocalCacheServer(port: 12345)
        server.cache(response: "test", withId: "123")

        guard server.start() else {
            XCTFail("Can't start server")
            return
        }

        let exp1 = expectation(description: "NormalRequest")
        let exp2 = expectation(description: "NotFoundRequest")

        let url1 = URL(string: "https://localhost.postindustria.com:12345/123")!
        let task1 = URLSession.shared.dataTask(with: url1) { data, response, error in
            XCTAssertNil(error)
            XCTAssertNotNil(data)
            // validate content
            if let respData = data, let response = String(data: respData, encoding: .utf8) {
                XCTAssertEqual(response, "test")
            }

            // validate CORS header
            if let httpResp = response as? HTTPURLResponse {
                XCTAssertEqual(httpResp.allHeaderFields["Access-Control-Allow-Origin"] as? String, "*")
            } else {
                XCTFail("Can\'t cast response")
            }
            exp1.fulfill()
        }
        task1.resume()

        let url2 = URL(string: "https://localhost.postindustria.com:12345/321")!
        let task2 = URLSession.shared.dataTask(with: url2) { _, response, _ in
            let resp = response as? HTTPURLResponse
            XCTAssertEqual(resp?.statusCode, 404)
            exp2.fulfill()
        }
        task2.resume()

        waitForExpectations(timeout: 5)
    }
}
