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

import XCTest
import OTFUtilities
import OTFCDTDatastore
@testable import OTFCloudClientAPI

class OTFCloudClientAPITests: XCTestCase {
    // Testing data
    // Let's not change the following data:
    var realNetworkService: NetworkingLayer!
    var blob: CDTBlobData!
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
        guard let url = Defaults.apiURL else {
            
            return
        }
        
        let configurations = NetworkingLayer.Configurations(APIBaseURL: url, apiKey: Defaults.APIKEY)
        TheraForgeNetwork.configureNetwork(configurations)
        
        realNetworkService = NetworkingLayer(session: NetworkingLayer.createSession(),
                                             keychainService: TheraForgeKeychainService.shared,
                                             currentAuth: nil)

        try testLogin()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try super.tearDownWithError()
    }
}

extension OTFCloudClientAPITests {
    // MARK: - Test with real data
    // MARK: - Test Login
    func testLogin() throws {
        let promise = expectation(description: "Login API should return the same user from ")
        realNetworkService.login(request: OTFCloudClientAPI.Request.Login(email: testEmail,
                                                                          password: testPassword)) { (result) in
            XCTAssertNotNil(result)
            switch result {
            case .success(let response):
                XCTAssertEqual(response.data.email, self.testEmail)
            case .failure(let error):
                XCTFail("🔥 \(error.error.message)")
            }
            promise.fulfill()
        }

        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }

    func testLoginWrongCredentials() {
        let promise = expectation(description: "There should be an error in case of wrong email/password. and error should not be nil.")
        realNetworkService.login(request: OTFCloudClientAPI.Request.Login(email: testEmail,
                                                                          password: "1234")) { (result) in
            XCTAssertNotNil(result)
            switch result {
            case .success:
                XCTFail("Login Should not get success with wrong credentials.")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            promise.fulfill()
        }

        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }
    
    func testSocialLogin() {
        let promise = expectation(description: "There should be an error in case of wrong email/password. and error should not be nil.")
        // swiftlint:disable line_length
        let appleIDToken = "<your-apple-id-token>"

        let idToken = appleIDToken
        let socialLogin = Request.SocialLogin(userType: .patient,
                                              socialType: .apple,
                                              authType: .login,
                                              identityToken: idToken)
        realNetworkService.socialLogin(request: socialLogin) { result in
            XCTAssertNotNil(result)
            switch result {
            case .success(_):
                promise.fulfill()
            case .failure(let error):
                XCTFail("🔥 \(error.error.message)")
            }
        }
        
        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }

    // MARK: - Test Signup
    func testSignUp() throws {
        let promise = expectation(description: "Response should get into success block and it should not be nil.")

        realNetworkService.signup(request:
                                    .init(email: "pico@gmail.com",
                                          password: testPassword,
                                          first_name: "FirstTestName",
                                          last_name: "LastTestName",
                                          type: .patient,
                                          dob: "08-07-1997",
                                          gender: "male",
                                          phoneNo: "(111) 111-1111",
                                          encryptedMasterKey: "testMasterKey",
                                          publicKey: "testPublicKey",
                                          encryptedDefaultStorageKey: "encryptedDefaultStorageKey",
                                          encryptedConfidentialStorageKey: "encryptedDefaultStorageKey"
                                         )
        ) { (result) in
            XCTAssertNotNil(result)
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
            case .failure(let error):
                XCTFail("🔥 \(error.error.message)")
            }
            promise.fulfill()
        }

        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }

    // MARK: - Test Change password
    func testChangePassword() throws {
        let promise = expectation(description: "Response should get into success block and it should not be nil.")
        realNetworkService.changePassword(request:
                                            .init(email: testEmail,
                                                  password: testPassword,
                                                  newPassword: testPassword)) { (result) in
            XCTAssertNotNil(result)
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
            case .failure(let error):
                XCTFail("🔥 \(error.error.message)")
            }
            promise.fulfill()
        }

        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }

    func testChangePasswordWrongCredentials() throws {
        let promise = expectation(description: "Should match the password changed message coming from the server.")
        realNetworkService.changePassword(request:
                                            .init(email: testEmail,
                                                  password: "123456",
                                                  newPassword: testPassword)) { (result) in
            XCTAssertNotNil(result)
            switch result {
            case .success:
                XCTFail("🔥 Change password should not get success with wrong credentials.")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            promise.fulfill()
        }

        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }

    // MARK: - Test forgot password
    func testForgotPassword() throws {
        let promise = expectation(description: "Should recieve message from server for forgot password.")
        realNetworkService.forgotPassword(request: .init(email: testEmail)) { (result) in
            XCTAssertNotNil(result)
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
            case .failure(let error):
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
                XCTFail("🔥 \(error.error.message)")
            }
            promise.fulfill()
        }

        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }

    // MARK: - Test RefreshToken
    func testRefreshToken() throws {
        let promise = expectation(description: "Got data")
        realNetworkService.login(request: OTFCloudClientAPI.Request.Login(email: testEmail,
                                                                          password: testPassword)) { (result) in
            XCTAssertNotNil(result)
            switch result {
            case .success(let response):
                XCTAssertEqual(response.data.email, self.testEmail)
                self.refreshToken {
                    promise.fulfill()
                }
            case .failure(let error):
                XCTFail("🔥 \(error.error.message)")
            }
        }

        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }

    func refreshToken(completion: @escaping () -> Void) {
        self.realNetworkService.refreshToken { (result) in
            XCTAssertNotNil(result)
            switch result {
            case .success(let response):
                completion()
                XCTAssertEqual(response.data.email, self.testEmail)
            case .failure(let error):
                completion()
                XCTFail("🔥 \(error.error.message)")
            }
        }
    }

    // MARK: - Test Reset password
    func testResetPassword() {
        let promise = expectation(description: "Should got failed for invalid code on reset password.")
        realNetworkService.resetPassword(request:
                                            .init(email: testEmail,
                                                  code: "code",
                                                  newPassword: testPassword)) { (result) in
            XCTAssertNotNil(result)
            switch result {
            case .success:
                XCTFail("🔥 Should not got succeded for wrong reset code.")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            promise.fulfill()
        }
        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }

    // MARK: - Test Logout
    func testLogout() {
        let promise = expectation(description: "User Should logged out and should get the message 'Logged out.' from the server." )
        realNetworkService.signOut { (result) in
            XCTAssertNotNil(result)
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
            case .failure(let error):
                XCTFail("🔥 \(error.error.message)")
            }
            promise.fulfill()
        }

        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }
    
    func testUpdateProfilePicture() {
        let promise = expectation(description: "User Should logged out and should get the message 'Logged out.' from the server." )
        
        guard let filePath = Bundle(for: type(of: self)).path(forResource: "user", ofType: "png"),
              let image = UIImage(contentsOfFile: filePath),
              let data = image.pngData() else {
            fatalError("Image not available")
        }
        let request = Request.UploadFile(userId: "88680df1d8eb2c334f379d45abcb08e6", location: .profile, uploadFile: data)
        realNetworkService.updateProfilePicture(request: request) { result in
            XCTAssertNotNil(result)
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
            case .failure(let error):
                XCTFail("🔥 \(error.error.message)")
            }
            promise.fulfill()
        }
        
        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }
    
    func testDownloadProfilePicture() {
        let promise = expectation(description: "User Should logged out and should get the message 'Logged out.' from the server." )
        
        let request = Request.DownloadFile(attachmentID: "c93dd5d5-1571-47e8-b7f6-fd8218fb9819", meta: "true")
        realNetworkService.downloadProfilePicture(request: request) { result in
            XCTAssertNotNil(result)
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
                promise.fulfill()
            case .failure(let error):
                XCTFail("🔥 \(error.error.message)")
            }
        }
        
        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }
    
    func testUploadFile() {
        
        let promise = expectation(description: "User Should logged out and should get the message 'Logged out.' from the server." )

        guard let filePath = Bundle(for: type(of: self)).url(forResource: "user", withExtension: "png"),
                let data = try? Data(contentsOf: filePath) else {
            fatalError("Image not available")
        }
        
        let request = Request.UploadFiles(data: data, fileName: "user.png", type: .profile, meta: "true", encryptedFileKey: "",
                                          hashFileKey: "")
        
        realNetworkService.uploadFile(request: request) { result in
            XCTAssertNotNil(result)
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
                promise.fulfill()
            case .failure(let error):
                XCTFail("🔥 \(error)")
            }
            promise.fulfill()
        }
        
        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }
    
    func testUploadConsentForm() {
            
            let promise = expectation(description: "User Should logged out and should get the message 'Logged out.' from the server." )

            guard let filePath = Bundle(for: type(of: self)).url(forResource: "cheatsheet", withExtension: "pdf"),
                    let data = try? Data(contentsOf: filePath) else {
                fatalError("Image not available")
            }
            
            let request = Request.UploadFiles(data: data, fileName: "cheatsheet.pdf", type: .consentForm, meta: "true", encryptedFileKey: "", hashFileKey: "")

            let startTime = Date()
            realNetworkService.uploadFile(request: request) { result in
                XCTAssertNotNil(result)
                switch result {
                case .success(let response):
                    let endTime = Date()
                    let diffInSecs = endTime.timeIntervalSince(startTime)
                    OTFLog("Time taken to upload the file: %{public}@", diffInSecs,
                           category: LoggerCategory.networking.rawValue)
                    XCTAssertNotNil(response)
                    promise.fulfill()
                case .failure(let error):
                    XCTFail("🔥 \(error)")
                }
                promise.fulfill()
            }
            
            waitForExpectations(timeout: requestTimeoutInterval) { error in
                if let error = error {
                    OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
                }
            }
        }
    
    func testUploadConsentFormWithEncrypted() {
            
            let promise = expectation(description: "User Should logged out and should get the message 'Logged out.' from the server." )

            guard let filePath = Bundle(for: type(of: self)).url(forResource: "cheatsheet", withExtension: "pdf"),
                    let data = try? Data(contentsOf: filePath) else {
                fatalError("Image not available")
            }
        
        let swiftSodium = SwiftSodium()
        let masterKey = swiftSodium.generateMasterKey(password: "123123123123", email: "azeem.invozone@gmail.com")
        let bytesImage = swiftSodium.getArrayOfBytesFromData(FileData: data as NSData)
        let defaultStorageKey = swiftSodium.generateDefaultStorageKey(masterKey: masterKey)
      
        let fileKeyPushStream = swiftSodium.getPushStream(secretKey: defaultStorageKey)!
        let fileKey = swiftSodium.generateDeriveKey(key: defaultStorageKey)
        let eFileKey = swiftSodium.encryptFile(pushStream: fileKeyPushStream, fileBytes: fileKey)
        let _ = [fileKeyPushStream.header(), eFileKey].flatMap({ (element: [UInt8]) -> [UInt8] in
            return element
        })
        
        // encrypt file
        let documentPushStream = swiftSodium.getPushStream(secretKey: fileKey)!
        let fileencryption = swiftSodium.encryptFile(pushStream: documentPushStream, fileBytes: bytesImage)
        let newFile = [documentPushStream.header(), fileencryption].flatMap({ (element: [UInt8]) -> [UInt8] in
            return element
        })
        
        let _ = swiftSodium.generateGenericHashWithKey(message: newFile, fileKey: fileKey)
        let encryptedFileData = Data(newFile)
        
        let uuid = UUID().uuidString + ".pdf"

            let request = Request.UploadFiles(data: encryptedFileData, fileName: uuid, type: .consentForm, meta: "true", encryptedFileKey: "encryptedFileKeyHex", hashFileKey: "hashKeyFileHex")

            let startTime = Date()
            realNetworkService.uploadFile(request: request) { result in
                XCTAssertNotNil(result)
                switch result {
                case .success(let response):
                    let endTime = Date()
                    let diffInSecs = endTime.timeIntervalSince(startTime)
                    OTFLog("Time taken to upload the file: %{public}@", diffInSecs,
                           category: LoggerCategory.networking.rawValue)
                    XCTAssertNotNil(response)
                    promise.fulfill()
                case .failure(let error):
                    XCTFail("🔥 \(error)")
                }
                promise.fulfill()
            }
            
            waitForExpectations(timeout: requestTimeoutInterval) { error in
                if let error = error {
                    OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
                }
            }
        }
    
    // MARK: - Delete File
    func testDeleteFile() {
        let promise = expectation(description: "Should got failed for invalid code on reset password.")
        let request = Request.FileAttachmentId(attachmentID: "6faac05a-5a2e-4a0a-8bce-6fcede643675")
        realNetworkService.deleteFile(request: request) { (result) in
            XCTAssertNotNil(result)
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            promise.fulfill()
        }
        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }
    
    // MARK: - Get FileInfo
    func testGetFileInfo() {
        let promise = expectation(description: "Should got failed for invalid code on reset password.")
        let request = Request.FileAttachmentId(attachmentID: "6faac05a-5a2e-4a0a-8bce-6fcede643675")
        realNetworkService.getFileInfo(request: request) { (result) in
            XCTAssertNotNil(result)
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            promise.fulfill()
        }
        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }
    
    // MARK: - File Rename
    func testFileRename() {
        let promise = expectation(description: "Should got failed for invalid code on reset password.")
        let request = Request.FileRename(attachmentID: "c93dd5d5-1571-47e8-b7f6-fd8218fb9819", name: "newName.png")
        realNetworkService.getFileInfo(request: request) { (result) in
            XCTAssertNotNil(result)
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            promise.fulfill()
        }
        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                OTFError("Test failed Error: : %{public}@,", error.localizedDescription, category: LoggerCategory.xcTest.rawValue)
            }
        }
    }
    
}
