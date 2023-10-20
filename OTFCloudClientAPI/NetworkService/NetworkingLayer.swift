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
import OTFUtilities

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
        var request = urlRequest(endpoint: Endpoint.sseSubscribe, method: .GET, authRequired: true)
        request.timeoutInterval = 90
        eventSource = EventSource(url: request, headers: header)
        eventSource?.onOpen {
            OTFLog("SSE Opened connection to server")
            self.eventSourceOnOpen?()
        }

        eventSource?.onComplete { statusCode, reconnect, error in
            OTFError("error: %{public}@", error?.localizedDescription ?? "")
            OTFLog("SSE on completion callback statusCode: %{public}@", reconnect ?? false, statusCode ?? 0)
            self.eventSourceOnComplete?(statusCode, reconnect, error)
        }

        eventSource?.onMessage { event in
            OTFLog("SSE on received message: %{public}@", event.type.rawValue)
            self.onReceivedMessage?(event)
        }

        eventSource?.addEventListener("user-connected") { event in
            OTFLog("SSE On added event listener: %{public}@", event.type.rawValue)
        }
        
        eventSource?.connect()
    }

    // swiftlint:disable trailing_closure
    public func observeChangeEvent(auth: Auth) {
        let serverURL = Self.configurations.APIBaseURL.appendingPathComponent(Endpoint.sseChanges.path)
        let header = ["Authorization": "Bearer \(auth.token)", "Client": identifierForVendor]
        var request = URLRequest(url: serverURL, timeoutInterval: 90)
        request.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        request.setValue(identifierForVendor, forHTTPHeaderField: "Client")
        request.httpMethod = "GET"

        eventSource = EventSource(url: request, headers: header)

        eventSource?.onOpen {
            OTFLog("SSE Changes - Opened connection to server")
            self.eventSourceOnOpen?()
        }

        eventSource?.onComplete({ (statusCode, reconnect, error) in
            OTFError("error: %{public}@", error?.localizedDescription ?? "")
            OTFLog("SSE on completion callback statusCode: %{public}@", reconnect ?? false, statusCode ?? 0)
            self.eventSourceOnComplete?(statusCode, reconnect, error)
        })

        eventSource?.onMessage({ event in
            OTFLog("SSE Changes - On Message : %{public}@", event.message)
            self.onReceivedMessage?(event)
        })

        eventSource?.addEventListener("user-connected", handler: { _ in
            OTFLog("SSE Changes - On added event listener.")
        })

        eventSource?.connect()
    }
}

// MARK: - API Callbacks
extension NetworkingLayer {
    // MARK: - Auth APIs
    public func login(request: Request.Login, completionHandler: @escaping (Result<Response.Login, ForgeError>) -> Void) {
        performRequest(endpoint: Endpoint.login, method: .POST, request: request, authRequired: false, completionHandler: { [weak self] (response: Result<Response.Login, ForgeError>) in
            self?.handleResponse(response)
            completionHandler(response)
        })
    }

    public func signup(request: Request.SignUp, completionHandler: @escaping (Result<Response.Login, ForgeError>) -> Void) {
        performRequest(endpoint: Endpoint.signup, method: .POST, request: request, authRequired: false, completionHandler: { [weak self] (response: Result<Response.Login, ForgeError>) in
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
        performRequest(endpoint: Endpoint.logout, method: .POST, request: request, authRequired: true, completionHandler: { (response: Result<Response.LogOut, ForgeError>) in
            if case .success(_) = response {
                TheraForgeKeychainService.shared.save(auth: nil)
                TheraForgeKeychainService.shared.save(user: nil)
            }
            
            completionHandler(response)
        })
    }
    
    public func socialLogin(request: Request.SocialLogin, completionHandler: @escaping (Result<Response.Login, ForgeError>) -> Void) {
        performRequest(endpoint: Endpoint.socialLogin, method: .POST, request: request, authRequired: false, completionHandler: { [weak self] (response: Result<Response.Login, ForgeError>) in
            self?.handleResponse(response)
            completionHandler(response)
        })
    }
    
    public func changePassword(request: Request.ChangePassword, completionHandler: @escaping (Result<Response.ChangePassword, ForgeError>) -> Void) {
        performRequest(endpoint: Endpoint.changePassword, method: .PUT, request: request, authRequired: true, completionHandler: completionHandler)
    }
    
    public func deleteAccount(request: Request.DeleteAccount, completionHandler: @escaping (Result<Response.DeleteAccount, ForgeError>) -> Void) {
        performRequest(endpoint: Endpoint.deleteAccount(userId: request.userId), method: .DELETE, request: request, authRequired: true, completionHandler: completionHandler)
    }

    public func forgotPassword(request: Request.ForgotPassword, completionHandler: @escaping (Result<Response.ForgotPassword, ForgeError>) -> Void) {
        performRequest(endpoint: Endpoint.forgotPassword, method: .POST, request: request, authRequired: false, completionHandler: completionHandler)
    }

    public func refreshToken(completionHandler: @escaping (Result<Response.Login, ForgeError>) -> Void) {
        guard let token = keychainService.loadAuth()?.refreshToken else { fatalError("Auth token not provided") }
        let request = Request.RefreshToken(refreshToken: token)
        performRequest(endpoint: Endpoint.refreshToken, method: .POST, request: request, authRequired: false, completionHandler: { [weak self] (response: Result<Response.Login, ForgeError>) in
            self?.handleResponse(response)
            completionHandler(response)
        })
    }

    public func resetPassword(request: Request.ResetPassword, completionHandler: @escaping (Result<Response.ChangePassword, ForgeError>) -> Void) {
        performRequest(endpoint: Endpoint.resetPassword, method: .PUT, request: request, authRequired: false, completionHandler: completionHandler)
    }
    
    // MARK: - File management
    public func updateProfilePicture(request: Request.UploadFile, completionHandler: @escaping (Result<Response.UploadFile, ForgeError>) -> Void) {
        do {
            let endpoint = Endpoint.fileUpload(userId: request.userId, type: request.location)
            let request = try multipartFormRequest(endpoint: endpoint, method: .POST, parameterData: request.uploadFile, authRequired: true)
            performURLRequest(request, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(.init(nsError: error as NSError)))
        }
    }
    
    public func downloadProfilePicture(request: Request.DownloadFile, completionHandler: @escaping (Result<Response.FileResponse, ForgeError>) -> Void) {
        do {
            let endPoint = Endpoint.getUploadFile
            let params = ["attachmentID": request.attachmentID,
                          "meta": request.meta]
            let request = try urlRequestWithqueryItems(endpoint: endPoint, method: .GET, parameters: params, requestBody: nil, authRequired: true)
            checkAuthAndPerformURLRequest(request, authRequired: true, expectJSONResponse: false, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(.init(nsError: error as NSError)))
        }
    }
    
    public func uploadFile(request: Request.UploadFiles, completionHandler: @escaping (Result<Response.FileResponse, ForgeError>) -> Void) {
        do {
            let endPoint = Endpoint.uploadFile
            let params = ["type": request.type.rawValue,
                          "fileName": request.fileName,
                          "meta": request.meta,
                          "encryptedFileKey": request.encryptedFileKey ?? "",
                          "hashFileKey": request.hashFileKey]
            let request = try urlRequestWithqueryItems(endpoint: endPoint, method: .PUT, parameters: params,
                                                       requestBody: request.data, authRequired: true)
            checkAuthAndPerformURLRequest(request, authRequired: true, expectJSONResponse: false, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(.init(nsError: error as NSError)))
        }
    }
    
    public func deleteFile(request: Request.FileAttachmentId, completionHandler: @escaping (Result<Response.DeleteFile, ForgeError>) -> Void) {
            let params = ["attachmentID": request.attachmentID]
        performRequest(endpoint: Endpoint.deleteFile, method: .DELETE, request: request, authRequired: true, containHeaders: true, parameters: params, completionHandler: completionHandler)
    }
    
    public func getFileInfo(request: Request.FileAttachmentId, completionHandler: @escaping (Result<Response.FileInfo, ForgeError>) -> Void) {
            let params = ["attachmentID": request.attachmentID]
        performRequest(endpoint: Endpoint.getFileInfo, method: .GET, request: request, authRequired: true, containHeaders: true, parameters: params, completionHandler: completionHandler)
    }
    
    public func getRevision(request: Request.FileAttachmentId, completionHandler: @escaping (Result<Response.GetRevision, ForgeError>) -> Void) {
            let params = ["attachmentID": request.attachmentID]
        performRequest(endpoint: Endpoint.getFileRevision, method: .GET, request: request, authRequired: true, containHeaders: true, parameters: params, completionHandler: completionHandler)
    }
    
    public func getFileInfo(request: Request.FileRename, completionHandler: @escaping (Result<Response.FileInfo, ForgeError>) -> Void) {
            let params = ["attachmentID": request.attachmentID,
                          "name": request.name]
        performRequest(endpoint: Endpoint.fileRename, method: .GET, request: request, authRequired: true, containHeaders: true, parameters: params, completionHandler: completionHandler)
    }
}

extension NetworkingLayer {
    // MARK: - Response handling
    private func handleResponse(_ response: Result<Response.Login, ForgeError>) {
        switch response {
        case .success(let result):
            OTFLog("Access token : %{public}@", result.accessToken.token)
            OTFLog("Refresh access token : %{public}@", result.accessToken.refreshToken)
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
    private func urlRequest(endpoint: EndpointImplementable,
                            method: HTTPMethod,
                            containHeaders: Bool? = false,
                            parameters: [String: Any]? = nil,
                            parameterData: Data? = nil,
                            authRequired: Bool) -> URLRequest {
        var request = URLRequest(url: Self.configurations.APIBaseURL.appendingPathComponent("\(Endpoint.apiVersion)" + endpoint.path), cachePolicy: URLRequest.CachePolicy.reloadIgnoringCacheData)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let parameters = parameters {
            if containHeaders == false {
                request.httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: JSONSerialization.WritingOptions.prettyPrinted)
            } else {
                for (type, value) in parameters {
                    if let value = value as? String {
                        request.addValue(value, forHTTPHeaderField: type)
                    }
                }
            }
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
    
    private func urlRequestWithHeader(endpoint: EndpointImplementable,
                                      method: HTTPMethod,
                                      parameters: [String: Any]? = nil,
                                      parameterData: Data? = nil,
                                      authRequired: Bool) -> URLRequest {
        var request = URLRequest(url: Self.configurations.APIBaseURL.appendingPathComponent("\(Endpoint.apiVersion)" + endpoint.path), cachePolicy: URLRequest.CachePolicy.reloadIgnoringCacheData)
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.addValue("image/png", forHTTPHeaderField: "Content-Type")
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
    
    func urlRequestWithqueryItems(endpoint: Endpoint,
                                  method: HTTPMethod,
                                  parameters: [String: String]?,
                                  requestBody: Data?,
                                  authRequired: Bool) throws -> URLRequest {
        let error = ForgeError(error: .init(statusCode: 400, name: NSCocoaErrorDomain, message: "Invalid URL request", code: nil))
        let url = Self.configurations.APIBaseURL.appendingPathComponent("\(Endpoint.apiVersion)" + endpoint.path)
        guard let urlComponents = URLComponents(string: url.absoluteString) else {
            throw error
        }
        
        guard let finalURL = urlComponents.url else {
            throw error
        }
        
        var request = URLRequest(url: finalURL, cachePolicy: URLRequest.CachePolicy.reloadIgnoringCacheData)
        request.httpMethod = method.rawValue
        request.addValue("\(Self.configurations.apiKey)", forHTTPHeaderField: "API-KEY")
        
        if let parameterData = requestBody {
            request.httpBody = parameterData
            if let type = parameters?["fileName"] {
                if type.contains("png") {
                    request.addValue("image/png", forHTTPHeaderField: "Content-Type")
                } else {
                    request.addValue("application/pdf", forHTTPHeaderField: "Content-Type")
                }
            }
        }
        
        guard authRequired else {
            return request
        }
        
        if let parameters = parameters {
            for (type, value) in parameters {
                request.addValue(value, forHTTPHeaderField: type)
            }
        }
        
        request.addValue("\(NetworkingLayer.shared.identifierForVendor)", forHTTPHeaderField: "Client")
        
        if let currentAuth = currentAuth {
            request.addValue("Bearer \(currentAuth.token)", forHTTPHeaderField: "Authorization")
        } else if let auth = keychainService.loadAuth() {
            request.addValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    func multipartFormRequest(endpoint: EndpointImplementable,
                              method: HTTPMethod,
                              parameters: [String: Any]? = nil,
                              parameterData: Data,
                              authRequired: Bool) throws -> URLRequest {
        let url = Self.configurations.APIBaseURL.appendingPathComponent(Endpoint.apiVersion + endpoint.path)
        guard case let Endpoint.fileUpload(_, attachmentLocation) = endpoint,
              var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ForgeError(error: .init(statusCode: 400, name: NSCocoaErrorDomain, message: "Invalid URL request", code: nil))
        }
        
        urlComponents.queryItems = [URLQueryItem(name: "type", value: attachmentLocation.rawValue)]
        var request = URLRequest(url: urlComponents.url!, cachePolicy: .reloadIgnoringCacheData)
        let fileName = "file"
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = ""
        body += "--\(boundary)\r\n"
        body += "Content-Disposition:form-data; name=\"\(fileName)\""
        
        let fileContent = parameterData.base64EncodedString()
        body += "; filename=\"\(fileName)\"\r\n" + "Content-Type: \"content-type header\"\r\n\r\n\(fileContent)\r\n"
        body += "--\(boundary)--\r\n"
        
        let postData = body.data(using: .utf8)
        request.httpBody = postData
        
        if authRequired {
            request.addValue("\(NetworkingLayer.shared.identifierForVendor)", forHTTPHeaderField: "Client")
            
            if let currentAuth = currentAuth {
                request.addValue("Bearer \(currentAuth.token)", forHTTPHeaderField: "Authorization")
            } else if let auth = keychainService.loadAuth() {
                request.addValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
            }
        }
        
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.addValue("\(Self.configurations.apiKey)", forHTTPHeaderField: "API-KEY")
        request.httpMethod = method.rawValue
        return request
    }

    private func performRequest<Request: Encodable, Response: Decodable>(endpoint: EndpointImplementable,
                                                                         method: HTTPMethod,
                                                                         request: Request,
                                                                         authRequired: Bool,
                                                                         containHeaders: Bool? = false,
                                                                         parameters: [String: Any]? = nil,
                                                                         completionHandler: @escaping NetworkResponse<Response>) {
        // Because the input is always codable, it is safe to force unwrap the JSON serialization results
        var urlRequest: URLRequest!
        if method == .POST {
            do {
                let parameters = try JSONEncoder().encode(request)
                urlRequest = self.urlRequest(endpoint: endpoint, method: method, containHeaders: containHeaders,
                                             parameterData: parameters, authRequired: authRequired)
            } catch {
                completionHandler(.failure(ForgeError(nsError: error as NSError)))
            }

        } else if method  == .DELETE {
            urlRequest = self.urlRequest(endpoint: endpoint, method: method, containHeaders: containHeaders,
                                         parameters: parameters, authRequired: authRequired)
        } else if method == .PUT {
            
            do {
                let parameters = try JSONEncoder().encode(request)
                urlRequest = self.urlRequestWithHeader(endpoint: endpoint, method: method,
                                                       parameterData: parameters, authRequired: authRequired)
            } catch {
                completionHandler(.failure(ForgeError(nsError: error as NSError)))
            }
            
        } else {
            urlRequest = self.urlRequest(endpoint: endpoint, method: method, containHeaders: containHeaders, parameters: parameters, authRequired: authRequired)
        }
        
        switch endpoint {
        case Endpoint.refreshToken:
            performURLRequest(urlRequest, completionHandler: completionHandler)
        default:
            checkAuthAndPerformURLRequest(urlRequest,
                                          authRequired: authRequired,
                                          expectJSONResponse: true,
                                          completionHandler: completionHandler)
        }
    }
    
    private func checkAuthAndPerformURLRequest<T: Decodable>(_ request: URLRequest,
                                                             authRequired: Bool,
                                                             expectJSONResponse: Bool,
                                                             completionHandler: @escaping NetworkResponse<T>) {
        if authRequired {
            if let currentAuth = currentAuth {
                if !currentAuth.isValid() {
                    // If we need auth and there is no valid access token, then attempt to refresh it
                    refreshToken { [unowned self] (result: Result<Response.Login, ForgeError>) in
                        switch result {
                        case .success:
                            if expectJSONResponse {
                                performURLRequest(request, completionHandler: completionHandler)
                            } else {
                                performMultipartURLRequest(request, completionHandler: completionHandler)
                            }
                        case .failure(let error):
                            completionHandler(.failure(error))
                        }
                    }
                } else {
                    if expectJSONResponse {
                        performURLRequest(request, completionHandler: completionHandler)
                    } else {
                        performMultipartURLRequest(request, completionHandler: completionHandler)
                    }
                }
            } else {
                completionHandler(.failure(ForgeError.missingCredential))
            }
        } else {
            if expectJSONResponse {
                performURLRequest(request, completionHandler: completionHandler)
            } else {
                performMultipartURLRequest(request, completionHandler: completionHandler)
            }
        }
    }
    
    private func performMultipartURLRequest<T: Decodable>(_ request: URLRequest,
                                                          completionHandler: @escaping NetworkResponse<T>) {
        let log = logDebugInfo
        session.dataTask(request: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if log {
                OTFLog("Response: %{public}@", response?.description ?? "N/A")
                if let data = data, let string = String(data: data, encoding: .utf8) {
                    OTFLog("Response string:\n", string)
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
                                if let contentType = (httpResponse.allHeaderFields["Content-Type"] as? String)?.components(separatedBy: "boundary=").last,
                                   let multiparts = data.multipartArray(withBoundary: contentType) {
                                    let corruptDataError = ForgeError(error: .init(statusCode: 403, name: "Not found", message: "Data is corrupt.", code: nil))
                                    guard let attachmentPart = multiparts.first(where: { $0.contentType.contains("attachment") }) else {
                                        completionHandler(.failure(corruptDataError))
                                        return
                                    }
                                    
                                    guard let metadataPart = multiparts.first(where: { $0.contentType.contains("metadata") }) else {
                                        completionHandler(.failure(corruptDataError))
                                        return
                                    }
                                    
                                    let metadata = try JSONDecoder().decode(Response.Metadata.self, from: metadataPart.body)
                                    let finalResponse = Response.FileResponse(metadata: metadata, data: attachmentPart.body)
                                    completionHandler(.success(finalResponse as! T))
                                } else {
                                    completionHandler(.failure(ForgeError(error: .init(statusCode: 403, name: "Not found", message: "Boundary value not found", code: nil))))
                                }
                                
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
    
    private func performURLRequest<T: Decodable>(_ request: URLRequest,
                                                 completionHandler: @escaping NetworkResponse<T>) {
        let log = logDebugInfo
        session.dataTask(request: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if log {
                OTFLog("Response: %{public}@", response?.description ?? "N/A")
                if let data = data, let string = String(data: data, encoding: .utf8) {
                    OTFLog("Response string:\n", string)
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
