/*
Copyright (c) 2021, Hippocrates Technologies S.r.l.. All rights reserved.

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

import KeychainAccess
import OTFUtilities

public enum KeyChainKey: String {
    case auth, vendorID, user
}

public protocol KeychainServiceProtocol {
    func load(for key: KeyChainKey) -> String?
    func save(token: String, for key: KeyChainKey)
    func loadAuth() -> Auth?
    func save(auth: Auth?)
    func loadUser() -> Response.User?
    func save(user: Response.User?)
    func remove(for key: KeyChainKey)
    func reset()
}

public class TheraForgeKeychainService: KeychainServiceProtocol {
    public static let shared = TheraForgeKeychainService()

    private let keychain: Keychain = Keychain(service: "com.theraforge")

    public func load(for key: KeyChainKey) -> String? {
        return keychain[key.rawValue]
    }

    public func save(token: String, for key: KeyChainKey) {
        keychain[key.rawValue] = token
    }
    
    public func loadAuth() -> Auth? {
        guard let authString = keychain[KeyChainKey.auth.rawValue],
              let jsonData = authString.data(using: .ascii) else { return nil }
        let jsonDecoder = JSONDecoder()
        let authObject = try? jsonDecoder.decode(Auth.self, from: jsonData)
        return authObject
    }
    
    public func save(auth: Auth?) {
        guard let jsonString = auth.dictionary?.jsonStringRepresentation else { return }
        keychain[KeyChainKey.auth.rawValue] = jsonString
    }
    
    public func loadUser() -> Response.User? {
        guard let userString = keychain[KeyChainKey.user.rawValue],
              let jsonData = userString.data(using: .ascii) else { return nil }
        let jsonDecoder = JSONDecoder()
        let userObject = try? jsonDecoder.decode(Response.User.self, from: jsonData)
        return userObject
    }
    
    public func save(user: Response.User?) {
        guard let jsonString = user.dictionary?.jsonStringRepresentation else { return }
        keychain[KeyChainKey.user.rawValue] = jsonString
    }

    public func remove(for key: KeyChainKey) {
        keychain[key.rawValue] = nil
    }

    public func reset() {
        do {
            try keychain.removeAll()
        } catch {
            OTFError("Error in reset keychain: %{public}@,", error.localizedDescription)
        }
    }
}
