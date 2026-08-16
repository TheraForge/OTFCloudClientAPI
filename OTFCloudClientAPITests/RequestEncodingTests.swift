/*
 Copyright (c) 2026, Hippocrates Technologies Sagl. All rights reserved.

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
@testable import OTFCloudClientAPI

final class RequestEncodingTests: XCTestCase {
    func testSignUpWithoutProfilePayloadOmitsTopLevelMetadata() throws {
        let request = makeSignUpRequest()
        let payload = try jsonPayload(for: request)

        XCTAssertNil(request.location)
        XCTAssertNil(request.conditions)
        XCTAssertNil(payload["userInfo"])
        XCTAssertNil(payload["location"])
        XCTAssertNil(payload["conditions"])
        XCTAssertEqual(payload["email"] as? String, "patient@example.com")
    }

    func testSignUpEncodesHealthProfileAsTopLevelJSONWhenSupplied() throws {
        let location = Request.SignUpLocation(
            displayName: "Portugal",
            addressLine1: "12 Fixture Way",
            addressLine2: "Apartment 3",
            city: "Lisbon",
            region: "Lisbon",
            postalCode: "1000-001",
            countryCode: "+351"
        )
        let conditions = [Request.SignUpCondition(code: "195967001", name: "Asthma")]
        let request = makeSignUpRequest(location: location, conditions: conditions)
        let payload = try jsonPayload(for: request)

        XCTAssertEqual(request.location, location)
        XCTAssertEqual(request.conditions, conditions)
        XCTAssertNil(payload["userInfo"])
        XCTAssertNil(payload["attachments"])
        XCTAssertEqual(payload["location"] as? [String: String], [
            "displayName": "Portugal",
            "addressLine1": "12 Fixture Way",
            "addressLine2": "Apartment 3",
            "city": "Lisbon",
            "region": "Lisbon",
            "postalCode": "1000-001",
            "countryCode": "+351"
        ])
        XCTAssertEqual(payload["conditions"] as? [[String: String]], [[
            "code": "195967001",
            "name": "Asthma"
        ]])
    }

    func testSignUpEncodesNoneReportedAsAnExplicitEmptyConditionsArray() throws {
        let request = makeSignUpRequest(conditions: [])
        let payload = try jsonPayload(for: request)

        XCTAssertNil(request.location)
        XCTAssertEqual(request.conditions?.count, 0)
        XCTAssertEqual((payload["conditions"] as? [Any])?.count, 0)
    }

    func testSocialLoginWithoutProfileMetadataOmitsOptionalKeys() throws {
        let request = makeSocialLoginRequest()
        let payload = try jsonPayload(for: request)

        XCTAssertNil(payload["userInfo"])
        XCTAssertNil(payload["location"])
        XCTAssertNil(payload["conditions"])
        XCTAssertEqual(payload["identityToken"] as? String, "identity-token")
    }

    func testSocialSignupEncodesHealthProfileAsTopLevelJSONWhenSupplied() throws {
        let location = Request.SignUpLocation(
            displayName: "Portugal",
            city: "Lisbon",
            countryCode: "+351"
        )
        let conditions = [Request.SignUpCondition(code: "195967001", name: "Asthma")]
        let request = makeSocialLoginRequest(location: location, conditions: conditions)
        let payload = try jsonPayload(for: request)

        XCTAssertEqual(request.location, location)
        XCTAssertEqual(request.conditions, conditions)
        XCTAssertNil(payload["userInfo"])
        XCTAssertNil(payload["attachments"])
        XCTAssertEqual(payload["location"] as? [String: String], [
            "displayName": "Portugal",
            "city": "Lisbon",
            "countryCode": "+351"
        ])
        XCTAssertEqual(payload["conditions"] as? [[String: String]], [[
            "code": "195967001",
            "name": "Asthma"
        ]])
    }

    func testSocialSignupPreservesNoneReportedAsAnExplicitEmptyConditionsArray() throws {
        let request = makeSocialLoginRequest(conditions: [])
        let payload = try jsonPayload(for: request)

        XCTAssertEqual(request.conditions?.count, 0)
        XCTAssertEqual((payload["conditions"] as? [Any])?.count, 0)
    }

    func testSocialLoginCannotSendSignupProfileMetadata() throws {
        let request = makeSocialLoginRequest(
            authType: .login,
            location: Request.SignUpLocation(displayName: "Portugal"),
            conditions: [Request.SignUpCondition(code: "195967001", name: "Asthma")]
        )
        let payload = try jsonPayload(for: request)

        XCTAssertNil(request.location)
        XCTAssertNil(request.conditions)
        XCTAssertNil(payload["location"])
        XCTAssertNil(payload["conditions"])
    }

    func testDecodedSocialLoginCannotReencodeSignupProfileMetadata() throws {
        let data = Data(
            """
            {
                "userType": "patient",
                "socialType": "apple",
                "requestType": "login",
                "identityToken": "identity-token",
                "location": { "displayName": "Portugal" },
                "conditions": [{ "code": "195967001", "name": "Asthma" }]
            }
            """.utf8
        )

        let request = try JSONDecoder().decode(Request.SocialLogin.self, from: data)
        let payload = try jsonPayload(for: request)

        XCTAssertNil(request.location)
        XCTAssertNil(request.conditions)
        XCTAssertNil(payload["location"])
        XCTAssertNil(payload["conditions"])
    }

    func testDecodedSocialSignupPreservesProfileMetadata() throws {
        let data = Data(
            """
            {
                "userType": "patient",
                "socialType": "apple",
                "requestType": "signup",
                "identityToken": "identity-token",
                "location": { "displayName": "Portugal" },
                "conditions": [{ "code": "195967001", "name": "Asthma" }]
            }
            """.utf8
        )

        let request = try JSONDecoder().decode(Request.SocialLogin.self, from: data)

        XCTAssertEqual(request.location, Request.SignUpLocation(displayName: "Portugal"))
        XCTAssertEqual(request.conditions, [Request.SignUpCondition(code: "195967001", name: "Asthma")])
    }

    func testResendVerificationEmailSendsClientWithoutAuthorizationOrRefresh() throws {
        NetworkingLayer.configureNetwork(.init(
            APIBaseURL: try XCTUnwrap(URL(string: "https://example.com/api/")),
            apiKey: "<your-api-key>"
        ))
        let expiredAuth = Auth(token: "expired-token", refreshToken: "refresh-token", iat: 0, exp: 0)
        let session = CapturingURLSession(responseData: Data(
            #"{"error":false,"message":"Verification email sent.","statusCode":200}"#.utf8
        ))
        let keychain = KeychainServiceFixture(auth: expiredAuth, vendorID: "fixture-client")
        let network = NetworkingLayer(session: session, keychainService: keychain, currentAuth: expiredAuth)
        var result: Result<Response.ResendVerifyEmail, ForgeError>?

        network.resendVerifyEmail(request: .init(email: "patient@example.com")) {
            result = $0
        }

        let urlRequest = try XCTUnwrap(session.requests.first)
        XCTAssertEqual(session.requests.count, 1)
        XCTAssertEqual(urlRequest.url?.path, "/api/v1/auth/send-verification-email")
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Client"), "fixture-client")
        XCTAssertNil(urlRequest.value(forHTTPHeaderField: "Authorization"))

        guard case .success? = result else {
            XCTFail("Expected the verification request fixture to complete successfully")
            return
        }
    }

    private func makeSignUpRequest(
        location: Request.SignUpLocation? = nil,
        conditions: [Request.SignUpCondition]? = nil
    ) -> Request.SignUp {
        Request.SignUp(
            email: "patient@example.com",
            password: "secret-password",
            first_name: "Ada",
            last_name: "Lovelace",
            type: .patient,
            dob: "1970-01-01T00:00:00Z",
            gender: "female",
            phoneNo: "",
            encryptedMasterKey: "encrypted-master-key",
            publicKey: "public-key",
            encryptedDefaultStorageKey: "encrypted-default-storage-key",
            encryptedConfidentialStorageKey: "encrypted-confidential-storage-key",
            location: location,
            conditions: conditions
        )
    }

    private func makeSocialLoginRequest(
        authType: Request.SocialLogin.AuthType = .signup,
        location: Request.SignUpLocation? = nil,
        conditions: [Request.SignUpCondition]? = nil
    ) -> Request.SocialLogin {
        Request.SocialLogin(
            userType: .patient,
            socialType: .apple,
            authType: authType,
            identityToken: "identity-token",
            location: location,
            conditions: conditions
        )
    }

    private func jsonPayload(for request: Request.SignUp) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func jsonPayload(for request: Request.SocialLogin) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class CapturingURLSession: URLSessionProtocol {
    private(set) var requests: [URLRequest] = []
    private let responseData: Data

    init(responseData: Data) {
        self.responseData = responseData
    }

    func dataTask(request: URLRequest, completionHandler: @escaping DataTaskResult) -> URLSessionDataTaskProtocol {
        requests.append(request)
        let response = request.url.flatMap {
            HTTPURLResponse(
                url: $0,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
        }
        return URLSessionDataTaskFixture {
            completionHandler(self.responseData, response, nil)
        }
    }
}

private final class URLSessionDataTaskFixture: URLSessionDataTaskProtocol {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func resume() {
        action()
    }
}

private final class KeychainServiceFixture: KeychainServiceProtocol {
    private var tokens: [KeyChainKey: String]
    private var auth: Auth?
    private var user: Response.User?

    init(auth: Auth?, vendorID: String) {
        self.auth = auth
        self.tokens = [.vendorID: vendorID]
    }

    func load(for key: KeyChainKey) -> String? {
        tokens[key]
    }

    func save(token: String, for key: KeyChainKey) {
        tokens[key] = token
    }

    func loadAuth() -> Auth? {
        auth
    }

    func save(auth: Auth?) {
        self.auth = auth
    }

    func loadUser() -> Response.User? {
        user
    }

    func save(user: Response.User?) {
        self.user = user
    }

    func remove(for key: KeyChainKey) {
        tokens[key] = nil
    }

    func reset() {
        tokens.removeAll()
        auth = nil
        user = nil
    }
}
