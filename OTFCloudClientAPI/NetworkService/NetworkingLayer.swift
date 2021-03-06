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

import Foundation
import UIKit

typealias NetworkResponse<T> = (Result<T, ForgeError>) -> Void

public class NetworkingLayer: NetworkServiceProtocol {

    public static let shared = NetworkingLayer()

    public private(set) var currentAuth: Auth? {
        get {
            keychainService.loadAuth()
        }
        set {
            keychainService.save(auth: newValue)
        }
    }
    public private(set) var eventSource: EventSource?
    private let logDebugInfo = true
    private let session: URLSessionProtocol
    private let keychainService: KeychainServiceProtocol
    public var onReceivedMessage: ((Event) -> Void)?
    public var eventSourceOnOpen: (() -> Void)?
    public var eventSourceOnComplete: ((Int?, Bool?, Error?) -> Void)?

    lazy var identifierForVendor: String = {
        var uuid = UUID().uuidString
        if let storedUUID = self.keychainService.load(for: .vendorID) {
            uuid = storedUUID
        } else {
            let newUUID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            self.keychainService.save(token: newUUID, for: .vendorID)
        }
        return uuid
    }()

    public struct Configurations: Codable {
        public init(APIBaseURL: URL,
                    apiKey: String,
                    // Use Apple's default timeout interval
                    timeoutInterval: TimeInterval = 60) {
            self.APIBaseURL = APIBaseURL
            self.apiKey = apiKey
            self.requestTimeout = timeoutInterval
        }
        
        public let APIBaseURL: URL
        public let apiKey: String
        public var requestTimeout: TimeInterval
    }
    
    private(set) static var configurations: Configurations!
    
    internal static func configureNetwork(_ configs: Configurations) {
        Self.configurations = configs
    }
    
    private init() {
        guard Self.configurations != nil else {
            fatalError("Network settings not configured before accessing the network instance.")
        }
        
        self.session = NetworkingLayer.createSession()
        self.keychainService = TheraForgeKeychainService.shared
    }

    init(session: URLSessionProtocol, keychainService: KeychainServiceProtocol, currentAuth: Auth?) {
        self.session = session
        self.keychainService = keychainService
        self.currentAuth = currentAuth
    }
}

// MARK: - SSE
extension NetworkingLayer {
    public func observeOnServerSentEvents(auth: Auth) {
        let header = ["Authorization": "Bearer \(auth.token)", "Client": identifierForVendor]
        var request = urlRequest(endpoint: .sseSubscribe, method: .GET, authRequired: true)
        request.timeoutInterval = 90
        eventSource = EventSource(url: request, headers: header)
        eventSource?.onOpen {
            print("SSE Opened connection to server")
            self.eventSourceOnOpen?()
        }

        eventSource?.onComplete { statusCode, reconnect, error in
            print("SSE on completion callback statusCode: \(String(describing: statusCode)) \n reconnect: \(String(describing: reconnect)) \n error: \(String(describing: error))")
            self.eventSourceOnComplete?(statusCode, reconnect, error)
        }

        eventSource?.onMessage { event in
            print("SSE on received message: \(event)")
            self.onReceivedMessage?(event)
        }

        eventSource?.addEventListener("user-connected") { event in
            print("SSE On added event listener: \(event)")
        }
        eventSource?.connect()
    }

    // swiftlint:disable trailing_closure
    public func observeChangeEvent(auth: Auth) {
        let serverURL = Self.configurations.APIBaseURL.appendingPathComponent(Endpoint.sseChanges.rawValue)
        let header = ["Authorization": "Bearer \(auth.token)", "Client": identifierForVendor]
        var request = URLRequest(url: serverURL, timeoutInterval: 90)
        request.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        request.setValue(identifierForVendor, forHTTPHeaderField: "Client")
        request.httpMethod = "GET"

        eventSource = EventSource(url: request, headers: header)

        eventSource?.onOpen {
            print("SSE Changes - Opened connection to server")
            self.eventSourceOnOpen?()
        }

        eventSource?.onComplete({ (statusCode, reconnect, error) in
            print("SSE Changes - Completed with statusCode \(statusCode?.description ?? "n/a") \n Reconnect \(reconnect?.description ?? "n/a") \n Error \(error?.description ?? "n/a")")
            self.eventSourceOnComplete?(statusCode, reconnect, error)
        })

        eventSource?.onMessage({ event in
            print("SSE Changes - On Message \(event.message)")
            self.onReceivedMessage?(event)
        })

        eventSource?.addEventListener("user-connected", handler: { _ in
            print("SSE Changes - On added event listener.")
        })

        eventSource?.connect()
    }
}

// MARK: - API Callbacks
extension NetworkingLayer {
    public func login(request: Request.Login, completionHandler: @escaping (Result<Response.Login, ForgeError>) -> Void) {
        performRequest(endpoint: .login, method: .POST, request: request, authRequired: false, completionHandler: { [weak self] (response: Result<Response.Login, ForgeError>) in
            self?.handleResponse(response)
            completionHandler(response)
        })
    }

    public func signup(request: Request.SignUp, completionHandler: @escaping (Result<Response.Login, ForgeError>) -> Void) {
        performRequest(endpoint: .signup, method: .POST, request: request, authRequired: false, completionHandler: { [weak self] (response: Result<Response.Login, ForgeError>) in
            self?.handleResponse(response)
            completionHandler(response)
        })
    }

    public func signOut(completionHandler: @escaping (Result<Response.LogOut, ForgeError>) -> Void) {
        guard let refreshToken = keychainService.loadAuth()?.refreshToken else {
            completionHandler(.success(Response.LogOut(message: "Logged out. It can take till 1 hour to logout in all your devices.")))
            return
        }
        let request = Request.LogOut(refreshToken: refreshToken)
        performRequest(endpoint: .logout, method: .POST, request: request, authRequired: true, completionHandler: { (response: Result<Response.LogOut, ForgeError>) in
            if case .success(_) = response {
                TheraForgeKeychainService.shared.save(auth: nil)
                TheraForgeKeychainService.shared.save(user: nil)
            }
            
            completionHandler(response)
        })
    }
    
    public func socialLogin(request: Request.SocialLogin, completionHandler: @escaping (Result<Response.Login, ForgeError>) -> Void) {
        performRequest(endpoint: .socialLogin, method: .POST, request: request, authRequired: false, completionHandler: { [weak self] (response: Result<Response.Login, ForgeError>) in
            self?.handleResponse(response)
            completionHandler(response)
        })
    }
    
    public func changePassword(request: Request.ChangePassword, completionHandler: @escaping (Result<Response.ChangePassword, ForgeError>) -> Void) {
        performRequest(endpoint: .changePassword, method: .PUT, request: request, authRequired: true, completionHandler: completionHandler)
    }

    public func forgotPassword(request: Request.ForgotPassword, completionHandler: @escaping (Result<Response.ForgotPassword, ForgeError>) -> Void) {
        performRequest(endpoint: .forgotPassword, method: .POST, request: request, authRequired: false, completionHandler: completionHandler)
    }

    public func refreshToken(completionHandler: @escaping (Result<Response.Login, ForgeError>) -> Void) {
        guard let token = keychainService.loadAuth()?.refreshToken else { fatalError("Auth token not provided") }
        let request = Request.RefreshToken(refreshToken: token)
        performRequest(endpoint: .refreshToken, method: .POST, request: request, authRequired: false, completionHandler: { [weak self] (response: Result<Response.Login, ForgeError>) in
            self?.handleResponse(response)
            completionHandler(response)
        })
    }

    public func resetPassword(request: Request.ResetPassword, completionHandler: @escaping (Result<Response.ChangePassword, ForgeError>) -> Void) {
        performRequest(endpoint: .resetPassword, method: .PUT, request: request, authRequired: false, completionHandler: completionHandler)
    }
}

extension NetworkingLayer {
    // MARK: - Response handling
    private func handleResponse(_ response: Result<Response.Login, ForgeError>) {
        switch response {
        case .success(let result):
            print(result.accessToken.token, "\n", result.accessToken.refreshToken)
            self.currentAuth = result.accessToken
            self.keychainService.save(auth: result.accessToken)
            self.keychainService.save(user: result.data)
        case .failure:
            break
        }
    }
}

extension NetworkingLayer {
    // MARK: - Common methods
    private func urlRequest(endpoint: Endpoint,
                            method: HTTPMethod,
                            parameters: [String: Any]? = nil,
                            parameterData: Data? = nil,
                            authRequired: Bool) -> URLRequest {
        var request = URLRequest(url: Self.configurations.APIBaseURL.appendingPathComponent("\(Endpoint.apiVersion)" + endpoint.rawValue), cachePolicy: URLRequest.CachePolicy.reloadIgnoringCacheData)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let parameters = parameters {
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: JSONSerialization.WritingOptions.prettyPrinted)
        }
        if let parameterData = parameterData {
            request.httpBody = parameterData
        }
        if authRequired {
            request.addValue("\(NetworkingLayer.shared.identifierForVendor)", forHTTPHeaderField: "Client")
            
            if let currentAuth = currentAuth {
                request.addValue("Bearer \(currentAuth.token)", forHTTPHeaderField: "Authorization")
            } else if let auth = keychainService.loadAuth() {
                request.addValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
            }
        }
        request.addValue("\(Self.configurations.apiKey)", forHTTPHeaderField: "API-KEY")
        request.httpMethod = method.rawValue
        return request
    }

    private func performRequest<Request: Encodable, Response: Decodable>(endpoint: Endpoint,
                                                                         method: HTTPMethod,
                                                                         request: Request,
                                                                         authRequired: Bool,
                                                                         completionHandler: @escaping NetworkResponse<Response>) {
        // Because the input is always codable, it is safe to force unwrap the JSON serialization results
        var urlRequest: URLRequest!
        if method != .GET {
            do {
                let parameters = try JSONEncoder().encode(request)
                urlRequest = self.urlRequest(endpoint: endpoint, method: method,
                                             parameterData: parameters, authRequired: authRequired)
            } catch {
                completionHandler(.failure(ForgeError(nsError: error as NSError)))
            }

        } else {
            urlRequest = self.urlRequest(endpoint: endpoint, method: method,
                                         parameterData: nil, authRequired: authRequired)
        }
        
        switch endpoint {
        case .refreshToken:
            performURLRequest(urlRequest, completionHandler: completionHandler)
        default:
            checkAuthAndPerformURLRequest(urlRequest, authRequired: authRequired,
                                          completionHandler: completionHandler)
        }
    }

    private func checkAuthAndPerformURLRequest<T: Decodable>(_ request: URLRequest,
                                                             authRequired: Bool,
                                                             completionHandler: @escaping NetworkResponse<T>) {
        if authRequired {
            if let currentAuth = currentAuth {
                if !currentAuth.isValid() {
                    // If we need auth and there is no valid access token, then attempt to refresh it
                    refreshToken { (result: Result<Response.Login, ForgeError>) in
                        switch result {
                        case .success:
                            self.performURLRequest(request, completionHandler: completionHandler)
                        case .failure(let error):
                            completionHandler(.failure(error))
                        }
                    }
                } else {
                    performURLRequest(request, completionHandler: completionHandler)
                }
            } else {
                completionHandler(.failure(ForgeError.missingCredential))
            }
        } else {
            performURLRequest(request, completionHandler: completionHandler)
        }
    }

    private func performURLRequest<T: Decodable>(_ request: URLRequest,
                                                 completionHandler: @escaping NetworkResponse<T>) {
        let log = logDebugInfo
        if log {
            NSLog("request \(request)")
        }

        session.dataTask(request: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if log {
                NSLog("response \(response?.description ?? "n/a")")
                if let data = data, let string = String(data: data, encoding: .utf8) {
                    NSLog("response string:\n \(string)")
                }
            }
            if let error = error {
                completionHandler(.failure(error.forgeError))
            } else {
                if let httpResponse = response as? HTTPURLResponse {
                    if let data = data {
                        do {
                            switch httpResponse.statusCode {
                            case 200...299:
                                let object: T = try JSONDecoder().decode(T.self, from: data)
                                completionHandler(.success(object))
                            case 400...499:
                                let errorData = try JSONDecoder().decode(ForgeError.ErrorData.self, from: data)
                                completionHandler(.failure(ForgeError(error: errorData)))
                            case 500...599:
                                completionHandler(.failure(ForgeError.unknownErrorCode))
                            default:
                                completionHandler(.failure(ForgeError.unknownErrorCode))
                            }
                        } catch let error {
                            completionHandler(.failure(error.forgeError))
                        }
                    } else { // END: if-let data
                        completionHandler(.failure(ForgeError.empty))
                    }
                } else {// END: if HTTPURLResponse
                    completionHandler(.failure(ForgeError.unknown))
                }
            }// END: last else statement
        }.resume()
    }
}

extension NetworkingLayer {
    static func createSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.tlsMinimumSupportedProtocolVersion = tls_protocol_version_t.TLSv13
        configuration.tlsMaximumSupportedProtocolVersion = tls_protocol_version_t.TLSv13
        return URLSession(configuration: configuration)
    }
}
