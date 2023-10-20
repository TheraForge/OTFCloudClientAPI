# OTFCloudClientAPI
This is TheraForge's client REST API framework to connect to TheraForge's secure CloudBox Backend-as-a-Service (BaaS).

OTFCloudClientAPI implements the functions required to interact with the TheraForge cloud back-end.

## Change Log
<details open>
<summary>Release 1.0.3-beta</summary>
<ul>
        <li>Added REST API endpoints to upload document, delete documment, re-name document and download document</li>
        <li>Added new parameters in Sign Up API</li>
        <li>Added Watch OS support</li>
</ul>
</details>

<details>
<summary>Release 1.0.2-beta</summary>
<ul>
        <li>Added REST API endpoint to support user account deletion</li>
        <li>Improved SSE event listeners and keys</li>
</ul>
</details>

<details>
<summary>Release 1.0.0-beta</summary>
<ul>
        <li>First beta release of the framework</li>
</ul>
</details>




## Configuration
**Note:** Examples of usage of the following APIs can also be found in the `OTFMagicBox` app code as well as in the unit tests.

Before creating an instance of TheraForgeNetwork, you need to first set up `configurations` with the `API-KEY` assigned to you and with the server URL like so:

```
let configurations = NetworkingLayer.Configurations(APIBaseURL: URL(string:"Server URL"), apiKey: "Your API_KEY")
TheraForgeNetwork.configureNetwork(configurations)
let otfNetworkService = TheraForgeNetwork.shared
```

Now you can use this shared instance to call any of the authentication APIs.

Remember that if you try to access the shared instance of TheraForgeNetwork your application will crash with the exception of missing configurations.

## Login
You need to create a `Request` object for login credentials as shown in the example below. In it you need to pass an email address and a password. In the response block, it will return `Result` which will contain the response with user data if the credentials are correct or an error if something went wrong.

```
otfNetworkService.login(request: Request.Login(email: "Your email address", password: "Your password")) { (result) in
    switch result {
        case .success(let response): print(response)
        case .failure(let error): print(error)
    }
}
```

## Social Login
You need to create a `Request` object for social login credentials as shown in the example below. In it you need to pass `socialID` and specify the social platform (Apple ID in this example). Email here is optional (Apple does not provide the email address on the second attempt). In the response block, it will return `Result` which will contain the response with user data if the request completes successfully or an error if something went wrong:

```
let socialLogin = Request.SocialLogin(type: .patient, email: "example@email.com",
                                      loginType: .apple,
                                      socialId: "12384c4a36634ca82cf0a6032005a4e")
otfNetworkService.socialLogin(request: socialLogin) { result in
    switch result {
        case .success(let response): print(response)
        case .failure(let error): print(error)
    }
}
```

## Sign up
Create a `Sign Up` Request with the required fields and pass this signup request to TheraForgeNetwork. Like other requests you'll get the `success` case if everything goes well, otherwise `failure`.

```
// You can use an instance of `NetworkingLayer` class that was created earlier to sign up a new user to the secure cloud backend.
// The code to generate the keys required in this API can be found in OTFMagicBox code

otfNetworkService.signup(request: .init(email: "<your email address>",
                         password: "<your password>",
                         first_name: "<your first name>",
                         last_name: "<your last name>",
                         type: .patient,
                         dob: "08-07-1997",
                         gender: "male",
                         phoneNo: "(111) 111-1111",
                         encryptedMasterKey: "<system generated encrypted master key hex>",
                         publicKey: "<system generated public key hex>",
                         encryptedDefaultStorageKey: "<system generated encrypted DefaultStorage Key hex>", 
                         encryptedConfidentialStorageKey: "<system generated encrypted ConfidentialStorage Key hex>"))
```

## Change Password
Create a `ChangePassword` request and pass it to the TheraForgeNetwork. You need to provide your current password and the new password that you want to set:

```
otfNetworkService.changePassword(request: .init(email: "Your email address", password: "Your old password", newPassword: "Your new password")) { (result) in
    switch result {
    case .success(let response): print(response)
    case .failure(let error): print(error)
    }
}
```

## Forgot Password
Create a `ForgotPassword` request and send it to TheraForgeNetwork as shown in the example below:

```
otfNetworkService.forgotPassword(request: .init(email: "Your email address.")) { (result) in
    switch result {
    case .success(let response): print(response )
    case .failure(let error): print(error)
    }
}
```
This function will send an OTP on the given email ID, that you need to use with the Reset password API mentioned below.

## Reset Password API's OTP Code
Once you use forgot password API, an OTP code will be sent to your email address that you need to use with this API in order to create a new password:

```
otfNetworkService.resetPassword(request: .init(email: "Your email address", code: "code", newPassword: "Your new password")) { (result) in
    switch result {
    case .success: print("success")
    case .failure(let error): print(error)
    }
}
```

## Refresh Token
The auth token that you get upon authentication is valid for 30 minutes only. In the auth object, you get the refresh token as well. Use this refresh token to refresh your auth token. Once you authorise the auth and user objects are stored in the keychain. You need to make sure that you have a refresh token before calling this API, else the application will crash:

```
guard TheraForgeKeychainService.shared.loadAuth().refreshToken != nil else {
    return
}
otfNetworkService.refreshToken(completionHandler: completionHandler)
```

## Logout
When you need to invalidate a user's auth you may call the logout API like so:

```
otfNetworkService.signOut { (result) in
    switch result {
    case .success(let response): print(response)
    case .failure(let error): print(error.localizedDescription)
    }
}
```

## Upload Document
When you need to upload document you may call the uploadFile API like so:

```
otfNetworkService.uploadFile(request: .init(data: "Document", fileName: "your file name", type: "Profile|Documents|ConsentForm", meta: "true", encryptedFileKey: "your encrypted file key", hashFileKey: "system generated hashFileKey Hex"))
{ [weak self] result in
    self?.handleResponse(result, promise: promise)
}
            
```

## Download Document
When you need to download document you may call the getUploadFile API like so:

```
otfNetworkService.downloadProfilePicture(request: .init(attachmentID: "file attachment ID", meta: "Boolean")) 
{ [weak self] result in
    self?.handleResponse(result, promise: promise)
}
            
```

## Delete Document
When you need to delete document you may call the deleteFile API like so:

```
otfNetworkService.deleteFile(request: .init(attachmentID: "file attachment ID")) 
{ [weak self] result in
    self?.handleResponse(result, promise: promise)
}
            
```

## Server Sent Events (SSE)
The server sends an event to the user when a change occurs in that user's database. There's a subscribe endpoint to listen to those events. There are three parts to this subscription:

1. Connection established:
When the connection with the server is established you get a callback.

```
otfNetworkService.eventSourceOnOpen = {
    print("Server sent event connection opened")
}
```

2. Event received:
Once subscribed for the events the application keep getting the events.

```
otfNetworkService.onReceivedMessage = { event in
    print(event)
    guard event.message.count > 0 else {
        print("This is just a keep alive event.")
        return
    }

    print("This is a db change event. You may take a decision here if you want to do something.")
}
```
There are two types of events: i. keep-alive, ii. db-updated. In case there is a db change then the event will have some message e.g. "Database updated." and for keep alive events it'll be an empty string. You can make a decision based on this message as shown in the example above.

3. Event source completed:
You get this callback upon disconnection with the server. In the callback you get a flag `reconnect` that indicates if you should resubscribe for the events or not.

```
otfNetworkService.eventSourceOnComplete = { code, reconnect, error in
    if let error = error {
        print(error.localizedDescription)
    }
    else if reconnect {
        // resubscribe to events if you want
    }
}
```

Once the above setup is done, you may call the subscribe API:

```
otfNetworkService.observeOnServerSentEvents(auth: auth)
```

# License <a name="License"></a>

This project is made available under the terms of a modified BSD license. See the [LICENSE](LICENSE.md) file.
