//
//  ServerSocket.swift
//  PrebidMobile
//
//  Created by Paul Dmitryev on 26.02.2020.
//

import Foundation
import Darwin.C


class ServerSocket {
    private let zero: Int8 = 0

    private var sockAddr: sockaddr_in
    private let cSocket: Int32
    private let socklen: UInt8

    var isRunning = false

    init(port: UInt16) throws {
        let htonsPort = (port << 8) + (port >> 8)

        let sock_stream = SOCK_STREAM

        cSocket = socket(AF_INET, Int32(sock_stream), 0)

        guard self.cSocket > -1 else {
            throw SimpleSocketError.cantCreate(code: Darwin.errno)
        }

        socklen = UInt8(socklen_t(MemoryLayout<sockaddr_in>.size))
        sockAddr = sockaddr_in()
        sockAddr.sin_family = sa_family_t(AF_INET)
        sockAddr.sin_port = in_port_t(htonsPort)
        // bind address to localhost only
        sockAddr.sin_addr = in_addr(s_addr: UInt32(0x7f_00_00_01).bigEndian)
        sockAddr.sin_zero = (zero, zero, zero, zero, zero, zero, zero, zero)

        #if os(macOS)
        sockAddr.sin_len = socklen
        #endif
    }

    public func bindAndListen() throws {
        try withUnsafePointer(to: &self.sockAddr) { sockaddrInPtr in
            let sockaddrPtr = UnsafeRawPointer(sockaddrInPtr).assumingMemoryBound(to: sockaddr.self)
            guard bind(self.cSocket, sockaddrPtr, socklen_t(self.socklen)) > -1 else {
                throw SimpleSocketError.cantBind(code: Darwin.errno)
            }
        }

        guard listen(self.cSocket, 5) > -1 else {
            throw SimpleSocketError.cantListen(code: Darwin.errno)
        }

        isRunning = true
    }

    public func acceptClientConnection() -> ClientConnection {
        return ClientConnection(sock: self.cSocket)
    }

    public func close() {
        Darwin.close(cSocket)
        isRunning = false
    }
}

class ClientConnection {
    private let clientSocket: Int32
    private let bufferMax = 2048
    private var readBuffer: [UInt8]
    private var tls: TlsSession?

    init(sock: Int32) {
        var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let addr = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1)
        let addrSockAddr = UnsafeMutablePointer<sockaddr>(OpaquePointer(addr))
        readBuffer = Array(repeating: UInt8(0), count: bufferMax)
        clientSocket = accept(sock, addrSockAddr, &length)
    }

    private func send(_ socket: Int32, _ output: String) throws {
        _ = try output.withCString { (bytes) in
            let length = Int(strlen(bytes))

            if let ssl = tls {
                _ = try ssl.writeBuffer(bytes, length: length)
                return
            }

            Darwin.send(socket, bytes, length, 0)
        }
    }

    func startTlsSession(certificate: CFArray) {
        do {
            tls = try TlsSession(connectionRef: clientSocket, certificate: certificate)
            try tls?.handshake()
        } catch {
            
        }
    }

    func readRequest() -> String? {
        let readBufPtr = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: bufferMax)
        defer {
            readBufPtr.deallocate()
        }
        guard let session = tls else {
            Log.error("Can't get session")
            return nil
        }
        guard let count = try? session.read(into: readBufPtr.baseAddress!, length: bufferMax) else {
            return nil
        }
        let result = [UInt8](readBufPtr[0..<count])
        return String(bytes: result, encoding: .utf8)
    }

    func writeResponse(_ string: String) {
        guard let session = tls else {
            Log.error("Can't get session")
            return
        }

        let data = ArraySlice(string.utf8)
        let length = data.count
        do {
            try data.withUnsafeBufferPointer { buffer in
                guard let pointer = buffer.baseAddress else {
                    return
                }
                var sent = 0
                while sent < length {
                    sent += try session.writeBuffer(pointer + sent, length: Int(length - sent))
                }
            }
        } catch {
            Log.error("Error writing response: \(error)")
        }
    }

    func respond(withHeaders: String, andContent: String = "") {
        let response = withHeaders + "\r\n\r\n" + andContent
        do {
            try send(clientSocket, response)
        } catch {
            Log.error("Error sending response \(error)")
        }
        close()
    }

    func close() {
        tls?.close()
        Darwin.close(clientSocket)
    }
}
