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
import OTFCDTDatastore

public protocol NetworkServiceProtocol {
    var onReceivedMessage: ((Event) -> Void)? { get set }

    var eventSourceOnOpen: (() -> Void)? { get set }

    var eventSourceOnComplete: ((Int?, Bool?, Error?) -> Void)? { get set }

    func observeOnServerSentEvents(auth: Auth)

    func observeChangeEvent(auth: Auth)

    func login(request: Request.Login, completionHandler: @escaping (_ result: Result<Response.Login, ForgeError>) -> Void)

    func signup(request: Request.SignUp, completionHandler: @escaping (_ result: Result<Response.Login, ForgeError>) -> Void)
    
    func socialLogin(request: Request.SocialLogin, completionHandler: @escaping (_ result: Result<Response.Login, ForgeError>) -> Void)

    func signOut(completionHandler: @escaping (_ result: Result<Response.LogOut, ForgeError>) -> Void)

    func changePassword(request: Request.ChangePassword, completionHandler: @escaping (_ result: Result<Response.ChangePassword, ForgeError>) -> Void)

    func forgotPassword(request: Request.ForgotPassword, completionHandler: @escaping (_ result: Result<Response.ForgotPassword, ForgeError>) -> Void)

    func refreshToken(completionHandler: @escaping (_ result: Result<Response.Login, ForgeError>) -> Void)

    func resetPassword(request: Request.ResetPassword, completionHandler: @escaping (_ result: Result<Response.ChangePassword, ForgeError>) -> Void)
    
    func updateProfilePicture(request: Request.UploadFile, completionHandler: @escaping (Result<Response.UploadFile, ForgeError>) -> Void)
    
    func downloadProfilePicture(request: Request.DownloadFile, completionHandler: @escaping (Result<Response.FileResponse, ForgeError>) -> Void)
    
    func uploadFile(request: Request.UploadFiles, completionHandler: @escaping (Result<Response.FileResponse, ForgeError>) -> Void)
    
    func deleteFile(request: Request.FileAttachmentId, completionHandler: @escaping (Result<Response.DeleteFile, ForgeError>) -> Void)
    
    func getFileInfo(request: Request.FileAttachmentId, completionHandler: @escaping (Result<Response.FileInfo, ForgeError>) -> Void)
    
    func getRevision(request: Request.FileAttachmentId, completionHandler: @escaping (Result<Response.GetRevision, ForgeError>) -> Void)
    
    func getFileInfo(request: Request.FileRename, completionHandler: @escaping (Result<Response.FileInfo, ForgeError>) -> Void)
}

public class TheraForgeNetwork: NSObject, NetworkServiceProtocol, CDTNSURLSessionConfigurationDelegate {
    
    public static let shared: TheraForgeNetwork = TheraForgeNetwork()

    private var network = NetworkingLayer.shared

    public var onReceivedMessage: ((Event) -> Void)?

    public var eventSourceOnOpen: (() -> Void)?

    public var eventSourceOnComplete: ((Int?, Bool?, Error?) -> Void)?
    
    public static var configurations: NetworkingLayer.Configurations? {
        return NetworkingLayer.configurations
    }
    
    public static func configureNetwork(_ configs: NetworkingLayer.Configurations) {
        NetworkingLayer.configureNetwork(configs)
    }

    public override init() {
        guard NetworkingLayer.configurations != nil else {
            fatalError("Network settings not configured before accessing the network instance.")
        }
        
        super.init()
        initializeEventHandlers()
    }

    private func initializeEventHandlers() {
        network.onReceivedMessage = { event in
            self.onReceivedMessage?(event)
        }

        network.eventSourceOnComplete = { [weak self] statusCode, reconnect, error in
            self?.eventSourceOnComplete?(statusCode, reconnect, error)
        }

        network.eventSourceOnOpen = {
            self.eventSourceOnOpen?()
        }
    }

    public var currentAuth: Auth? {
        return network.currentAuth
    }

    public var identifierForVendor: String {
        return network.identifierForVendor
    }

    public func observeOnServerSentEvents(auth: Auth) {
        network.observeOnServerSentEvents(auth: auth)
    }

    public func observeChangeEvent(auth: Auth) {
        network.observeChangeEvent(auth: auth)
    }

    public func login(request: Request.Login, completionHandler: @escaping (Result<Response.Login, ForgeError>) -> Void) {
        network.login(request: request, completionHandler: completionHandler)
    }

    public func signup(request: Request.SignUp, completionHandler: @escaping (Result<Response.Login, ForgeError>) -> Void) {
        network.signup(request: request, completionHandler: completionHandler)
    }
    
    public func socialLogin(request: Request.SocialLogin, completionHandler: @escaping (Result<Response.Login, ForgeError>) -> Void) {
        network.socialLogin(request: request, completionHandler: completionHandler)
    }

    public func signOut(completionHandler: @escaping (Result<Response.LogOut, ForgeError>) -> Void) {
        network.signOut(completionHandler: completionHandler)
    }

    public func changePassword(request: Request.ChangePassword, completionHandler: @escaping (Result<Response.ChangePassword, ForgeError>) -> Void) {
        network.changePassword(request: request, completionHandler: completionHandler)
    }
    
    public func deleteAccount(request: Request.DeleteAccount, completionHandler: @escaping (Result<Response.DeleteAccount, ForgeError>) -> Void) {
        network.deleteAccount(request: request, completionHandler: completionHandler)
    }

    public func forgotPassword(request: Request.ForgotPassword, completionHandler: @escaping (Result<Response.ForgotPassword, ForgeError>) -> Void) {
        network.forgotPassword(request: request, completionHandler: completionHandler)
    }

    public func refreshToken(completionHandler: @escaping (Result<Response.Login, ForgeError>) -> Void) {
        network.refreshToken(completionHandler: completionHandler)
    }

    public func resetPassword(request: Request.ResetPassword, completionHandler: @escaping (Result<Response.ChangePassword, ForgeError>) -> Void) {
        network.resetPassword(request: request, completionHandler: completionHandler)
    }
    
    public func updateProfilePicture(request: Request.UploadFile, completionHandler: @escaping (Result<Response.UploadFile, ForgeError>) -> Void) {
        network.updateProfilePicture(request: request, completionHandler: completionHandler)
    }
    
    public func downloadProfilePicture(request: Request.DownloadFile, completionHandler: @escaping (Result<Response.FileResponse, ForgeError>) -> Void) {
        network.downloadProfilePicture(request: request, completionHandler: completionHandler)
    }
    
    public func uploadFile(request: Request.UploadFiles, completionHandler: @escaping (Result<Response.FileResponse, ForgeError>) -> Void) {
        network.uploadFile(request: request, completionHandler: completionHandler)
    }
    
    public func deleteFile(request: Request.FileAttachmentId, completionHandler: @escaping (Result<Response.DeleteFile, ForgeError>) -> Void) {
        network.deleteFile(request: request, completionHandler: completionHandler)
    }
    
    public func getFileInfo(request: Request.FileAttachmentId, completionHandler: @escaping (Result<Response.FileInfo, ForgeError>) -> Void) {
        network.getFileInfo(request: request, completionHandler: completionHandler)
    }
    
    public func getRevision(request: Request.FileAttachmentId, completionHandler: @escaping (Result<Response.GetRevision, ForgeError>) -> Void) {
        network.getRevision(request: request, completionHandler: completionHandler)
    }
    
    public func getFileInfo(request: Request.FileRename, completionHandler: @escaping (Result<Response.FileInfo, ForgeError>) -> Void) {
        network.getFileInfo(request: request, completionHandler: completionHandler)
    }

    // MARK: - CDTNSURLSessionConfigurationDelegate
    public func customiseNSURLSessionConfiguration(_ config: URLSessionConfiguration) {
        config.tlsMinimumSupportedProtocolVersion = tls_protocol_version_t.TLSv13
        config.tlsMaximumSupportedProtocolVersion = tls_protocol_version_t.TLSv13
    }
}
