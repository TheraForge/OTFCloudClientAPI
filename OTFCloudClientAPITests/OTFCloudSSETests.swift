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
@testable import OTFCloudClientAPI

extension XCTestCase {
    var testEmail: String { Defaults.username }
    var testPassword: String { Defaults.password }
    var requestTimeoutInterval: TimeInterval { Defaults.requestTimeoutInterval }
}

class OTFCloudSSETests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
        guard let url = Defaults.apiURL else { return }
        
        let configurations = NetworkingLayer.Configurations(APIBaseURL: url, apiKey: Defaults.APIKEY)
        TheraForgeNetwork.configureNetwork(configurations)
    }

    func testSubscribeEventSource_Open() {
        let expect = expectation(description: "This should get an callback in handler in \(requestTimeoutInterval) seconds, otherwise we will consider this test case failed.")

        let shared = TheraForgeNetwork.shared

        shared.eventSourceOnOpen = {
            OTFLog("Event source open...")
        }

        login(shared) { result in
            switch result {
            case .success(let response):
                OTFLog("User logged in....")
                let auth = response.accessToken
                shared.observeOnServerSentEvents(auth: auth)
                shared.onReceivedMessage = { event in
                    OTFLog("Event %{public}@", event.type.rawValue)
                    expect.fulfill()
                }
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
        }

        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }
    }

    // MARK: - Test cases for subscribe event sources.
    func testSubscribeEventSource_Complete() {
        let expect = expectation(description: "This should get an callback in handler in \(requestTimeoutInterval) seconds, otherwise we will consider this case failed.")

        let shared = TheraForgeNetwork.shared

        shared.eventSourceOnComplete = { code, _, error in
            expect.fulfill()
            if let error = error { XCTFail(error.localizedDescription) }
            guard let statusCode = code else { XCTFail("Status code is nil"); return }

            XCTAssertFalse(400...499 ~= statusCode, "Failed: This status code was not expected. Status code is: \(statusCode)")
            XCTAssertTrue(200 ... 299 ~= statusCode, "Success: This is the expected status code from server. Status code is: \(statusCode)")
        }

        login(shared) { result in
            switch result {
            case .success(let response):
                let auth = response.accessToken
                shared.observeOnServerSentEvents(auth: auth)
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
        }

        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }
    }

    // MARK: - Test cases for Change event source
    func testChangeEventOn_Open() {
        let expect = expectation(description: "This should get an callback in handler in \(requestTimeoutInterval) seconds. Otherwise it will be failed.")

        let shared = TheraForgeNetwork.shared

        shared.eventSourceOnOpen = {
            expect.fulfill()
        }

        login(shared) { result in
            switch result {
            case .success(let response):
                let auth = response.accessToken
                shared.observeChangeEvent(auth: auth)
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
        }

        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }
    }

    func testChangeEventOn_Complete() {
        let expect = expectation(description: "This should get an callback in handler in \(requestTimeoutInterval) seconds, otherwise it will be failed.")

        let shared = TheraForgeNetwork.shared

        shared.eventSourceOnComplete = { code, _, error in
            expect.fulfill()
            if let error = error { XCTFail(error.localizedDescription) }
            guard let statusCode = code else { XCTFail("Status code is nil"); return }
            XCTAssertFalse(400...499 ~= statusCode, "Failed: This status code was not expected. Status code is: \(statusCode)")
            XCTAssertTrue(200...299 ~= statusCode, "Success: This is the expected status code. Status code is: \(statusCode)")
        }

        login(shared) { result in
            switch result {
            case .success(let response):
                let auth = response.accessToken
                shared.observeChangeEvent(auth: auth)
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
        }

        waitForExpectations(timeout: requestTimeoutInterval) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }
    }

    /// This function is used to login with default provided credentials
    /// - Parameters:
    ///   - shared: TheraForgeNetwork Shared instance
    ///   - completion: it will return back the Login response if succeded or will return ForgeError if it fails.
    private func login(_ shared: TheraForgeNetwork, completion: @escaping (Result<Response.Login, ForgeError>) -> Void) {
        shared.login(request: Request.Login(email: testEmail, password: testPassword),
                     completionHandler: completion)
    }
}
