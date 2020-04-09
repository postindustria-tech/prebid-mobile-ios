//
//  LocalCacheServer.swift
//  PrebidMobile
//
//  Created by Paul Dmitryev on 26.02.2020.
//
//  Partially based on https://github.com/viktorasl/swifter/
//

import Foundation


private func throwIfError(_ status: OSStatus) throws {
    guard status == noErr else {
        throw SimpleSocketError.sslError(from: status)
    }
}

open class TlsSession {
    /// Imports .p12 certificate fil
    ///
    /// See [SecPKCS12Import](https://developer.apple.com/documentation/security/1396915-secpkcs12import).
    ///
    /// - Parameter _data: .p12 certificate file content
    /// - Parameter password: password used when importing certificate
    public static func loadP12Certificate(fromData data: Data, withPassword password: String) throws -> CFArray {
        var items: CFArray?
        let options = [kSecImportExportPassphrase: password]
        try throwIfError(SecPKCS12Import(data as NSData, options as NSDictionary, &items))
        let castedItems = (items! as [AnyObject])[0]
        let secIdentity = castedItems[kSecImportItemIdentity] as! SecIdentity
        let certChain = castedItems[kSecImportItemCertChain] as! [SecCertificate]
        let certs = [secIdentity] + certChain.dropFirst().map { $0 as Any }
        return certs as CFArray
    }

    private let context: SSLContext
    private var connPtr = UnsafeMutablePointer<Int32>.allocate(capacity: 1)

    init(connectionRef: Int32, certificate: CFArray) throws {
        guard let newContext = SSLCreateContext(nil, .serverSide, .streamType) else {
            throw SimpleSocketError.tlsSessionFailed("Can't create SSL context")
        }
        context = newContext
        connPtr.pointee = connectionRef
        try throwIfError(SSLSetIOFuncs(context, sslRead, sslWrite))
        try throwIfError(SSLSetConnection(context, connPtr))
        try throwIfError(SSLSetCertificate(context, certificate))
    }

    func close() {
        SSLClose(context)
        connPtr.deallocate()
    }

    func handshake() throws {
        var status: OSStatus = -1
        repeat {
            status = SSLHandshake(context)
        } while status == errSSLWouldBlock
        try throwIfError(status)
    }

    /// Write up to `length` bytes to TLS session from a buffer `pointer` points to.
    ///
    /// - Returns: The number of bytes written
    /// - Throws: SocketError.tlsSessionFailed if unable to write to the session
    func writeBuffer(_ pointer: UnsafeRawPointer, length: Int) throws -> Int {
        var written = 0
        try throwIfError(SSLWrite(context, pointer, length, &written))
        return written
    }

    /// Read up to `length` bytes from TLS session into an existing buffer
    ///
    /// - Parameter into: The buffer to read into (must be at least length bytes in size)
    /// - Returns: The number of bytes read
    /// - Throws: SocketError.tlsSessionFailed if unable to read from the session
    func read(into buffer: UnsafeMutablePointer<UInt8>, length: Int) throws -> Int {
        var received = 0
        try throwIfError(SSLRead(context, buffer, length, &received))
        return received
    }
}

private func sslWrite(connection: SSLConnectionRef, data: UnsafeRawPointer,
                      dataLength: UnsafeMutablePointer<Int>) -> OSStatus {
    let fPtr = connection.assumingMemoryBound(to: Int32.self).pointee
    let bytesToWrite = dataLength.pointee

    let written = Darwin.write(fPtr, data, bytesToWrite)

    dataLength.pointee = written
    if written > 0 {
        return written < bytesToWrite ? errSSLWouldBlock : noErr
    }
    if written == 0 {
        return errSSLClosedGraceful
    }

    dataLength.pointee = 0
    return errno == EAGAIN ? errSSLWouldBlock : errSecIO
}

private func sslRead(connection: SSLConnectionRef, data: UnsafeMutableRawPointer,
                     dataLength: UnsafeMutablePointer<Int>) -> OSStatus {
    let fPtr = connection.assumingMemoryBound(to: Int32.self).pointee
    let bytesToRead = dataLength.pointee
    let read = recv(fPtr, data, bytesToRead, 0)

    dataLength.pointee = read
    if read > 0 {
        return read < bytesToRead ? errSSLWouldBlock : noErr
    }

    if read == 0 {
        return errSSLClosedGraceful
    }

    dataLength.pointee = 0
    switch errno {
    case ENOENT:
        return errSSLClosedGraceful
    case EAGAIN:
        return errSSLWouldBlock
    case ECONNRESET:
        return errSSLClosedAbort
    default:
        return errSecIO
    }
}
