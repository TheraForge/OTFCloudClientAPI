/*
 Copyright (c) 2024, Hippocrates Technologies Sagl. All rights reserved.

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.

 3. Neither the name of the copyright holder(s) nor the names of any contributor(s) may
 be used to endorse or promote products derived from this software without specific
 prior written permission. No license is granted to the trademarks of the copyright
 holders even if such marks are included in this software.

 4. Commercial redistribution in any form requires an explicit license agreement with the
 copyright holder(s). Please contact support@hippocratestech.com for further information
 regarding licensing.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
 OF SUCH DAMAGE.
 */

import Foundation

public struct ForgeError: Codable, Error {
    public var error: ErrorData

    public init(nsError: NSError) {
        self.error = ErrorData(statusCode: nsError.code, name: "", message: nsError.localizedDescription, code: nil)
    }

    public init(error: ErrorData) {
        self.error = error
    }

    public struct ErrorData: Codable {
        public init(statusCode: Int?, name: String?, message: String, code: String?) {
            self.statusCode = statusCode
            self.name = name
            self.message = message
            self.code = code
        }

        public var statusCode: Int?
        public let name: String?
        public var message: String
        public let code: String?
    }

    public static let emailNotVerified = {
        ForgeError(error: .init(statusCode: 601,
                                name: "Email Not Verified",
                                message: "Please verify your email",
                                code: nil))
    }()
    
    public static let empty = {
        return ForgeError(error: .init(statusCode: 500,
                                       name: "Empty",
                                       message: "There is no data in the response",
                                       code: nil))
    }()

    public static let unknown = {
        ForgeError(error: .init(statusCode: 500,
                                name: "Unknown",
                                message: "Something went wrong...",
                                code: nil))
    }()

    public static let unknownErrorCode = {
        ForgeError(error: .init(statusCode: 500,
                                name: "Unknown Error Code",
                                message: "Something went wrong...",
                                code: nil))
    }()

    public static let missingCredential = {
        ForgeError(error: .init(statusCode: 403,
                                name: "Missing Credential",
                                message: "There is no credential for a request that requires authentication",
                                code: nil))
    }()
    
    public static let invalidResponse = {
        ForgeError(error: .init(statusCode: 400,
                                name: "Invalid Response",
                                message: "The response format is not valid.",
                                code: nil))
    }()
}

public extension Error {
    var forgeError: ForgeError {
        ForgeError(nsError: self as NSError)
    }
}
