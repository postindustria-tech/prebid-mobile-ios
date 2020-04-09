//
//  ServerResponse.swift
//  PrebidMobile
//
//  Created by Paul Dmitryev on 24.02.2020.
//

protocol ServerResponse {
    var headers: [String] { get }
    var body: String { get }
}

enum SimpleServerResponses: Equatable {
    case ok(content: String)
    case errorNotFound
    case errorParsing
}

extension SimpleServerResponses: ServerResponse {
    var headers: [String] {
        let code: Int
        switch self {
        case .ok:
            code = 200
        case .errorNotFound:
            code = 404
        case .errorParsing:
            code = 400
        }

        let respText = code == 200 ? "OK" : body

        return ["HTTP/1.1 \(code) \(respText)",
                "Access-Control-Allow-Origin: *",
                "Server: Simple HTTP Server",
                "Content-Length: \(body.count)"
        ]
    }

    var body: String {
        switch self {
        case let .ok(content):
            return content
        case .errorNotFound:
            return "Not found"
        case .errorParsing:
            return "Bad request"
        }
    }
}
