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
import OTFUtilities

public enum EventSourceState {
    case connecting
    case open
    case closed
}

public protocol EventSourceProtocol {
    var headers: [String: String] { get }

    /// RetryTime: This can be changed remotly if the server sends an event `retry:`
    var retryTime: Int { get }

    /// URL where EventSource will listen for events.
    var url: URLRequest { get }

    /// The last event id received from server. This id is neccesary to keep track of the last event-id received to avoid
    /// receiving duplicate events after a reconnection.
    var lastEventId: String? { get }

    /// Current state of EventSource
    var readyState: EventSourceState { get }

    /// Method used to connect to server. It can receive an optional lastEventId indicating the Last-Event-ID
    ///
    /// - Parameter lastEventId: optional value that is going to be added on the request header to server.
    func connect(lastEventId: String?)

    /// Method used to disconnect from server.
    func disconnect()

    /// Returns the list of event names that we are currently listening for.
    ///
    /// - Returns: List of event names.
    func events() -> [String]

    /// Callback called when EventSource has successfully connected to the server.
    ///
    /// - Parameter onOpenCallback: callback
    func onOpen(_ onOpenCallback: @escaping (() -> Void))

    /// Callback called once EventSource has disconnected from server. This can happen for multiple reasons.
    /// The server could have requested the disconnection or maybe a network layer error, wrong URL or any other
    /// error. The callback receives as parameters the status code of the disconnection, if we should reconnect or not
    /// following event source rules and finally the network layer error if any. All this information is more than
    /// enought for you to take a decition if you should reconnect or not.
    /// - Parameter onOpenCallback: callback
    func onComplete(_ onComplete: @escaping ((Int?, Bool?, NSError?) -> Void))

    /// This callback is called everytime an event with name "message" or no name is received.
    func onMessage(_ onMessageCallback: @escaping ((Event) -> Void))

    /// Add an event handler for an specific event name.
    ///
    /// - Parameters:
    ///   - event: name of the event to receive
    ///   - handler: this handler will be called everytime an event is received with this event-name
    func addEventListener(_ event: String,
                          handler: @escaping ((Event) -> Void))

    /// Remove an event handler for the event-name
    ///
    /// - Parameter event: name of the listener to be remove from event source.
    func removeEventListener(_ event: String)
}

public class EventSource: NSObject, EventSourceProtocol, URLSessionDataDelegate {
    static let DefaultRetryTime = 3000

    public let url: URLRequest
    private(set) public var lastEventId: String?
    private(set) public var retryTime = EventSource.DefaultRetryTime
    private(set) public var headers: [String: String]
    private(set) public var readyState: EventSourceState

    private var onOpenCallback: (() -> Void)?
    private var onComplete: ((Int?, Bool?, NSError?) -> Void)?
    private var onMessageCallback: ((Event) -> Void)?
    private var eventListeners: [String: (Event) -> Void] = [:]
    private var operationQueue: OperationQueue
    private var mainQueue = DispatchQueue.main
    private var urlSession: URLSession?

    public init(
        url: URLRequest,
        headers: [String: String] = [:]
    ) {
        self.url = url
        self.headers = headers

        readyState = EventSourceState.closed
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        super.init()
    }

    public func connect(lastEventId: String? = nil) {
        readyState = .connecting

        let configuration = sessionConfiguration(lastEventId: lastEventId)
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: operationQueue)
        urlSession?.dataTask(with: url).resume()
        OTFLog("SSE Connecting.....")
    }

    public func disconnect() {
        readyState = .closed
        urlSession?.invalidateAndCancel()
        OTFLog("SSE disconnecting.....")
    }

    public func onOpen(_ onOpenCallback: @escaping (() -> Void)) {
        self.onOpenCallback = onOpenCallback
    }

    public func onComplete(_ onComplete: @escaping ((Int?, Bool?, NSError?) -> Void)) {
        self.onComplete = onComplete
    }

    public func onMessage(_ onMessageCallback: @escaping ((Event) -> Void)) {
        self.onMessageCallback = onMessageCallback
    }

    public func addEventListener(_ event: String,
                                 handler: @escaping ((Event) -> Void)) {
        eventListeners[event] = handler
    }

    public func removeEventListener(_ event: String) {
        eventListeners.removeValue(forKey: event)
    }

    public func events() -> [String] {
        return Array(eventListeners.keys)
    }

    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if readyState != .open {
            return
        }

        do {
            var newString = String(data: data, encoding: .utf8) ?? ""
            if let firstIndex = newString.firstIndex(of: "{") {
                newString.removeSubrange(newString.startIndex..<firstIndex)
                if let newData = newString.data(using: .utf8) {
                    let event = try JSONDecoder().decode(Event.self, from: newData)
                    processReceivedEvent(event)
                }
            }
            
        } catch {
            OTFError("Parsing error: %{public}@,", error.localizedDescription)
        }
    }

    open func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         didReceive response: URLResponse,
                         completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(URLSession.ResponseDisposition.allow)

        readyState = .open
        mainQueue.async { [weak self] in self?.onOpenCallback?() }
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         didCompleteWithError error: Error?) {
        guard let responseStatusCode = (task.response as? HTTPURLResponse)?.statusCode else {
            mainQueue.async { [weak self] in self?.onComplete?(nil, nil, error as NSError?) }
            return
        }

        let reconnect = shouldReconnect(statusCode: responseStatusCode)
        mainQueue.async { [weak self] in self?.onComplete?(responseStatusCode, reconnect, nil) }
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         willPerformHTTPRedirection response: HTTPURLResponse,
                         newRequest request: URLRequest,
                         completionHandler: @escaping (URLRequest?) -> Void) {
        var newRequest = request
        self.headers.forEach { newRequest.setValue($1, forHTTPHeaderField: $0) }
        completionHandler(newRequest)
    }
}

internal extension EventSource {
    func sessionConfiguration(lastEventId: String?) -> URLSessionConfiguration {

        var additionalHeaders = headers
        if let eventID = lastEventId {
            additionalHeaders["Last-Event-Id"] = eventID
        }

        additionalHeaders["Accept"] = "text/event-stream"
        additionalHeaders["Cache-Control"] = "no-cache"

        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = TimeInterval(INT_MAX)
        sessionConfiguration.timeoutIntervalForResource = TimeInterval(INT_MAX)
        sessionConfiguration.httpAdditionalHeaders = additionalHeaders
        return sessionConfiguration
    }

    func readyStateOpen() {
        readyState = .open
    }
}

private extension EventSource {
    func processReceivedEvent(_ event: Event) {
        mainQueue.async { [weak self] in self?.onMessageCallback?(event) }
    }

    // Following "5 Processing model" from:
    // https://www.w3.org/TR/eventsource/#handler-eventsource-onerror
    func shouldReconnect(statusCode: Int) -> Bool {
        switch statusCode {
        case 200:
            return false
        case _ where statusCode > 200 && statusCode < 300:
            return true
        default:
            return false
        }
    }
}
