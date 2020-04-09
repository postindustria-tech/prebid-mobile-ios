//
//  ServerRequest.swift
//  PrebidMobile
//
//  Created by Paul Dmitryev on 24.02.2020.
//

struct ServerRequest {
    let method: String
    let parameters: String

    init?(rawRequest: String?) {
        // split first line of request
        guard let request = rawRequest, let verb = request.split(separator: "\r\n").first else {
            return nil
        }

        // get command and parameters
        let splittedVerb = verb.split(separator: " ")
        guard splittedVerb.count == 3, splittedVerb[1].count>0 else {
            return nil
        }

        method = String(splittedVerb[0])
        parameters = String(splittedVerb[1])
    }
}
