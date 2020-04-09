//
//  SimpleServer.swift
//  PrebidMobile
//
//  Created by Paul Dmitryev on 26.02.2020.
//

import Foundation
import Dispatch


class SimpleServer {
    private let serverSocket: ServerSocket?
    private let workQueue = DispatchQueue(label: "simple.http.server.worker", qos: .userInteractive, attributes: .concurrent)

    private(set) var started = false
    private let respCache = ResponseCache()
    private let handler: ServerResponseHandler
    private let cert: CFArray?

    init(port: UInt16, handler: ServerResponseHandler, certificates: CFArray?) {
        self.handler = handler
        cert = certificates
        do {
            serverSocket = try ServerSocket(port: port)
        } catch {
            Log.error("Error creating socket: \(error)")
            serverSocket = nil
        }
    }

    deinit {
        serverSocket?.close()
    }

    func start() -> Bool {
        guard let certificates = cert else {
            return false
        }

        guard !started else {
            return true
        }

        guard let socket = serverSocket else {
            return false
        }

        do {
            try socket.bindAndListen()
        } catch {
            Log.error("Error binding server: \(error)")
            return false
        }

        started = true
        Log.info("Local cache server started")

        workQueue.async { [weak self] in
            guard let strongSelf = self else {
                return
            }

            repeat {
                let client = socket.acceptClientConnection()
                defer {
                    client.close()
                }
                client.startTlsSession(certificate: certificates)

                if let parsedRequest = ServerRequest(rawRequest: client.readRequest()) {
                    let response = strongSelf.handler.respond(toRequest: parsedRequest)
                    let respData = response.headers.joined(separator: "\n") + "\r\n\r\n" + response.body
                    Log.info("Serving local response")
                    client.writeResponse(respData)
                }
            } while socket.isRunning
        }

        return true
    }
}
