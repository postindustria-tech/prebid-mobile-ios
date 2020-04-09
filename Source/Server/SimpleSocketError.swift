//
//  SimpleSocketError.swift
//  PrebidMobile
//
//  Created by Paul Dmitryev on 26.02.2020.
//


import Foundation

enum SimpleSocketError: Error {
    case cantCreate(code: Int32)
    case cantBind(code: Int32)
    case cantListen(code: Int32)
    case tlsSessionFailed(_ message: String)

    private func description(prefix: String, forCode code: Int32) -> String {
        // https://forums.developer.apple.com/thread/113919
        let reason = String(cString: strerror(code))
        return "\(prefix): \(code). \(reason)"
    }

    static func sslError(from status: OSStatus) -> SimpleSocketError {
        if #available(iOS 11.3, *) {
            guard let msg = SecCopyErrorMessageString(status, nil) else {
                return SimpleSocketError.tlsSessionFailed("<\(status): message is not provided>")
            }
            return SimpleSocketError.tlsSessionFailed(msg as NSString as String)
        } else {
            return SimpleSocketError.tlsSessionFailed("Some TLS error")
        }
    }

    var localizedDescription: String {
        switch self {
        case let .cantBind(code):
            return description(prefix: "Can't bind socket", forCode: code)
        case let .cantCreate(code):
            return description(prefix: "Can't create server socket", forCode: code)
        case let .cantListen(code):
            return description(prefix: "Can't listen on socket", forCode: code)
        case let .tlsSessionFailed(message):
            return "TLS Error: \(message)"
        }
    }
}
