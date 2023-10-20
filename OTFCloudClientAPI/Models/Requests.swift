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

public enum Request {
    
    public enum AttachmentLocation: String, Codable {
        case profile = "Profile"
        case documents = "Documents"
        case consentForm = "ConsentForm"
        case settings = "Settings"
    }
    
    public struct Login: Codable {
        public init(email: String, password: String) {
            self.email = email
            self.password = password
        }

        public let email: String
        public let password: String
    }

    public struct LogOut: Codable {
        public init(refreshToken: String) {
            self.refreshToken = refreshToken
        }

        public let refreshToken: String
    }

    public struct SignUp: Codable {
        public init(email: String, password: String, first_name: String, last_name: String, type: UserType, dob: String, gender: String, phoneNo: String, encryptedMasterKey: String, publicKey: String, encryptedDefaultStorageKey: String,encryptedConfidentialStorageKey: String) {
            self.email = email
            self.password = password
            self.first_name = first_name
            self.last_name = last_name
            self.type = type
            self.dob = dob
            self.gender = gender
            self.phoneNo = phoneNo
            self.encryptedMasterKey = encryptedMasterKey
            self.publicKey = publicKey
            self.encryptedConfidentialStorageKey = encryptedConfidentialStorageKey
            self.encryptedDefaultStorageKey = encryptedDefaultStorageKey
        }
        
        public let email: String
        public let password: String
        public let first_name: String
        public let last_name: String
        public let type: UserType
        public let dob: String
        public let gender: String
        public let phoneNo: String
        public let encryptedMasterKey: String
        public let publicKey: String
        public let encryptedDefaultStorageKey: String
        public let encryptedConfidentialStorageKey: String
    }
    
    public struct SocialLogin: Codable {
        public init(userType: UserType,
                    socialType: Request.SocialLogin.SocialType,
                    authType: Request.SocialLogin.AuthType,
                    identityToken: String) {
            self.userType = userType
            self.socialType = socialType
            self.requestType = authType
            self.identityToken = identityToken
        }
        
        // swiftlint:disable:next nesting
        public enum SocialType: String, Codable {
            case gmail, apple
        }
        
        // swiftlint:disable:next nesting
        public enum AuthType: String, Codable, CaseIterable {
            case login, signup
        }
        
        public let userType: UserType
        public let socialType: SocialType
        public let requestType: AuthType
        public let identityToken: String
    }

    public struct ChangePassword: Codable {
        public init(email: String, password: String, newPassword: String) {
            self.email = email
            self.password = password
            self.newPassword = newPassword
        }

        public let email: String
        public let password: String
        public let newPassword: String
    }

    public struct ForgotPassword: Codable {
        public init(email: String) {
            self.email = email
        }

        public let email: String
    }
    
    public struct DeleteAccount: Codable {
        public init(userId: String) {
            self.userId = userId
        }

        public let userId: String
    }

    public struct RefreshToken: Codable {
        public init(refreshToken: String) {
            self.refreshToken = refreshToken
        }

        public let refreshToken: String
    }

    public struct ResetPassword: Codable {
        public init(email: String, code: String, newPassword: String) {
            self.email = email
            self.code = code
            self.newPassword = newPassword
        }

        public let email: String
        public let code: String
        public let newPassword: String
    }

    public struct CreateDatabase: Codable {
        public init(db: String) {
            self.db = db
        }

        // In order to use 1:1 mapping with the API, we have to make the property only 2 characters
        public let db: String
    }

    public struct AddDocument: Codable {
        public init(db: String, document: [String: String]) {
            self.db = db
            self.document = document
        }

        public let db: String
        public let document: [String: String]
    }

    public struct DeleteDatabase: Codable {
        public init(db: String) {
            self.db = db
        }

        public let db: String
    }
    
    public struct UploadFile: Codable {
        
        public init(userId: String, location: AttachmentLocation, uploadFile: Data) {
            self.userId = userId
            self.location = location
            self.uploadFile = uploadFile
        }
        
        public let userId: String
        public let location: AttachmentLocation
        public let uploadFile: Data
    }
    
    public struct DownloadFile: Codable {
        
        public init(attachmentID: String, meta: String) {
            self.attachmentID = attachmentID
            self.meta = meta
        }
        
        public let attachmentID: String
        public let meta: String
    }
    
    public struct UploadFiles: Codable {
        public init(data: Data, fileName: String, type: AttachmentLocation, meta: String, encryptedFileKey : String?,hashFileKey : String) {
            self.data = data
            self.fileName = fileName
            self.type = type
            self.meta = meta
            self.encryptedFileKey = encryptedFileKey ?? ""
            self.hashFileKey = hashFileKey
        }

        public let data: Data
        public let fileName: String
        public let type: AttachmentLocation
        public let meta: String
        public let encryptedFileKey : String?
        public let hashFileKey : String
    }
    
    public struct FileAttachmentId: Codable {
        public init(attachmentID: String) {
            self.attachmentID = attachmentID
        }

        public let attachmentID: String
    }
    
    public struct FileRename: Codable {
        public init(attachmentID: String, name: String) {
            self.attachmentID = attachmentID
            self.name = name
        }

        public let attachmentID: String
        public let name: String
    }
}
