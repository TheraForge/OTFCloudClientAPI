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

public enum UserType: String, Codable, CaseIterable {
    case doctor, patient
}

public enum GenderType: String, Codable, CaseIterable {
    case male, female, other
}

public enum Response {
    public struct Login: Codable {
        public init(error: Bool, message: String?, data: Response.User, accessToken: Auth) {
            self.error = error
            self.message = message
            self.data = data
            self.accessToken = accessToken
        }
        
        public let error: Bool
        public let message: String?
        
        public let data: User
        public let accessToken: Auth
    }
    
    public struct LogOut: Codable {
        public init(message: String) {
            self.message = message
        }
        
        public let message: String
    }
    
    public struct ChangePassword: Codable {
        public init(message: String) {
            self.message = message
        }
        
        public let message: String
    }
    
    public struct DeleteAccount: Codable {
        public init(message: String) {
            self.message = message
        }
        
        public let message: String
    }
    
    public struct ForgotPassword: Codable {
        public init(message: String) {
            self.message = message
        }
        
        public let message: String
    }
    
    public struct ChangeSeq: Codable {
        public init(seq: String?, id: String?, deleted: Bool?, changes: [Response.Change]?) {
            self.seq = seq
            self.id = id
            self.deleted = deleted
            self.changes = changes
        }
        
        public let seq: String?
        public let id: String?
        public let deleted: Bool?
        public let changes: [Change]?
    }
    
    public struct Change: Codable {
        public init(rev: String) {
            self.rev = rev
        }
        
        public let rev: String
    }
    
    public struct Changes: Codable {
        public init(results: [Response.ChangeSeq], lastSeq: String?, pending: Int) {
            self.results = results
            self.lastSeq = lastSeq
            self.pending = pending
        }
        
        public let results: [ChangeSeq]
        public let lastSeq: String?
        public let pending: Int
    }
    
    public struct User: Codable {
        public init(id: String, email: String, firstName: String, lastName: String, type: UserType, gender: GenderType, dob: String, encryptedMasterKey: String, encryptedConfidentialStorageKey: String, encryptedDefaultStorageKey: String) {
            self.id = id
            self.email = email
            self.firstName = firstName
            self.lastName = lastName
            self.type = type
            self.gender = gender
            self.dob = dob
            self.encryptedMasterKey = encryptedMasterKey
            self.encryptedDefaultStorageKey = encryptedDefaultStorageKey
            self.encryptedConfidentialStorageKey = encryptedConfidentialStorageKey
//            self.publicKey = publicKey
        }
        
        public let id: String
        public let email: String
        public let firstName: String?
        public let lastName: String?
        public let gender: GenderType?
        public let dob: String?
        public let type: UserType
        public let encryptedMasterKey: String
        public let encryptedConfidentialStorageKey: String
        public let encryptedDefaultStorageKey: String
//        public let publicKey: String
        
        public var dateOfBirth: Date? {
            guard let dob = dob else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "dd-mm-yyyy"
            return formatter.date(from: dob)
        }
    }
    
    public struct UploadFile: Codable {
        public init(error: Bool, message: String, data: Response.UploadFile.AttachmentDetails) {
            self.error = error
            self.message = message
            self.data = data
        }
        
        public let error: Bool
        public let message: String
        public let data: AttachmentDetails
        
        public struct AttachmentDetails: Codable {
            public init(attachmentType: Request.AttachmentLocation, attachmentUrl: String) {
                self.attachmentType = attachmentType
                self.attachmentUrl = attachmentUrl
            }
            
            public let attachmentType: Request.AttachmentLocation
            public let attachmentUrl: String
        }
    }
    
    public struct DownloadFile: Codable {
        public init(error: Bool, message: String, data: Response.DownloadFile.AttachmentDetails) {
            self.error = error
            self.message = message
            self.data = data
        }
        
        public let error: Bool
        public let message: String
        public let data: AttachmentDetails
        
        public struct AttachmentDetails: Codable {
            public init(attachmentUrl: String) {
                self.attachmentUrl = attachmentUrl
            }
            
            public let attachmentUrl: String
        }
    }
    
    public struct FileResponse: Codable {
        public let metadata: Metadata
        public let data: Data
        
        public init(metadata: Response.Metadata, data: Data) {
            self.metadata = metadata
            self.data = data
        }
    }

    public struct Metadata: Codable {
        public let contentType, revpos, hashFileKey, encryptedFileKey, location, attachmentID, fileName, owner: String
        public let attrev, length: Double
        public let stub: Bool
        
        public init(contentType: String,
                    revpos: String,
                    hashFileKey: String,
                    encryptedFileKey: String,
                    location: String,
                    fileName: String,
                    owner: String,
                    attrev: Double,
                    length: Double,
                    stub: Bool,
                    attachmentID: String) {
            self.contentType = contentType
            self.revpos = revpos
            self.hashFileKey = hashFileKey
            self.encryptedFileKey = encryptedFileKey
            self.location = location
            self.fileName = fileName
            self.owner = owner
            self.attrev = attrev
            self.length = length
            self.stub = stub
            self.attachmentID = attachmentID
        }
    }
    
    public struct DeleteFile: Codable {
        public init(error: Bool, message: String, statusCode: Int) {
            self.error = error
            self.message = message
            self.statusCode = statusCode
        }
        
        public let error: Bool
        public let message: String
        public let statusCode: Int
    }
    
    public struct FileInfo: Codable {
        public init(error: Bool, message: String, statusCode: Int, data: Response.Metadata) {
            self.error = error
            self.message = message
            self.statusCode = statusCode
            self.data = data
        }
        
        public let error: Bool
        public let message: String
        public let statusCode: Int
        public let data: Metadata
    }
    
    public struct GetRevision: Codable {
        public init(error: Bool, message: String, statusCode: Int, data: Response.RevisionData) {
            self.error = error
            self.message = message
            self.statusCode = statusCode
            self.data = data
        }
        
        public let error: Bool
        public let message: String
        public let statusCode: Int
        public let data: RevisionData
    }
    
    public struct RevisionData: Codable {
        public init(revpos: String, attrev: Int) {
            self.revpos = revpos
            self.attrev = attrev
        }
        
        public let revpos: String
        public let attrev: Int
    }
}
