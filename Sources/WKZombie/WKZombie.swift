//
// WKZombie.swift
//
// Copyright (c) 2015 Mathias Koehnke (http://www.mathiaskoehnke.de)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import WebKit

public typealias AuthenticationHandler = (URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?)
public typealias SnapshotHandler = (Snapshot) -> Void

public class WKZombie {
    
    /// A shared instance of `Manager`, used by top-level WKZombie methods,
    /// and suitable for multiple web sessions.
    public class var sharedInstance: WKZombie {
        return Static.instance!
    }
    
    internal struct Static {
        static var token : Int = 0
        static var instance : WKZombie?
    }
    
    fileprivate var _renderer : Renderer!
    fileprivate var _fetcher : ContentFetcher!
    
    /// Returns the name of this WKZombie session.
    open fileprivate(set) var name : String!
    
    /// If false, the loading progress will finish once the 'raw' HTML data
    /// has been transmitted. Media content such as videos or images won't
    /// be loaded.
    public var loadMediaContent : Bool = true {
        didSet {
            _renderer.loadMediaContent = loadMediaContent
        }
    }
    
    public var enableJavascript : Bool {
        get {
            return _renderer.enableJavascript
        }
        set {
            _renderer.enableJavascript = newValue
        }
    }

    public var debugWindow : Bool {
        get {
            return _renderer.debugWindow
        }
        set {
            _renderer.debugWindow = newValue
        }
    }

    /// The custom user agent string or nil if no custom user agent string has been set.
    @available(OSX 10.11, *)
    public var userAgent : String? {
        get {
            return self._renderer.userAgent
        }
        set {
            self._renderer.userAgent = newValue
        }
    }
    
    /// An operation is cancelled if the time it needs to complete exceeds the time 
    /// specified by this property. Default is 30 seconds.
    public var timeoutInSeconds : TimeInterval {
        get {
            return self._renderer.timeoutInSeconds
        }
        set {
            self._renderer.timeoutInSeconds = newValue
        }
    }
    
    /// Authentication Handler for dealing with e.g. Basic Authentication
    public var authenticationHandler : AuthenticationHandler? {
        get {
            return self._renderer.authenticationHandler
        }
        set {
            self._renderer.authenticationHandler = newValue
        }
    }
    
    #if os(iOS)
    /// Snapshot Handler
    public var snapshotHandler : SnapshotHandler?
    
    /// If 'true', shows the network activity indicator in the status bar. The default is 'true'.
    public var showNetworkActivity : Bool {
        get {
            return self._renderer.showNetworkActivity
        }
        set {
            self._renderer.showNetworkActivity = newValue
        }
    }
    #endif
    
    /**
     The designated initializer.
     
     - parameter name: The name of the WKZombie session.
     
     - returns: A WKZombie instance.
     */
    public init(name: String? = "WKZombie", processPool: WKProcessPool? = nil) {
        self.name = name
        self._renderer = Renderer(processPool: processPool)
        self._fetcher = ContentFetcher()
    }
    
    //========================================
    // MARK: Response Handling
    //========================================
    
    fileprivate func _handleResponse(_ data: Data?, response: URLResponse?, error: Error?) -> Result<Data> {
        var statusCode : Int = (error == nil) ? ActionError.Static.DefaultStatusCodeSuccess : ActionError.Static.DefaultStatusCodeError
        if let response = response as? HTTPURLResponse {
            statusCode = response.statusCode
        }
        let errorDomain : ActionError? = (error == nil) ? nil : .networkRequestFailure
        let responseResult: Result<Response> = Result(errorDomain, Response(data: data, statusCode: statusCode))
        return responseResult >>> parseResponse
    }
}


//========================================
// MARK: Get Page
//========================================

public extension WKZombie {
    /**
     The returned WKZombie Action will load and return a HTML or JSON page for the specified URL.
     
     - parameter url: An URL referencing a HTML or JSON page.
     
     - returns: The WKZombie Action.
     */
    func open<T: Page>(_ url: URL) -> Action<T> {
        return open(then: .none)(url)
    }
    
    /**
     The returned WKZombie Action will load and return a page for the specified URL.
     
     - parameter postAction: An wait/validation action that will be performed after the page has finished loading.
     - parameter url: An URL referencing a HTML or JSON page.
     
     - returns: The WKZombie Action.
     */
    func open<T: Page>(then postAction: PostAction) -> (_ url: URL) -> Action<T> {
        return { (url: URL) -> Action<T> in
            return Action() { [unowned self] completion in
                let request = URLRequest(url: url)
                self._renderer.renderPageWithRequest(request, postAction: postAction, completionHandler: { data, response, error in
                    let data = self._handleResponse(data as? Data, response: response, error: error)
                    completion(data >>> decodeResult(response?.url))
                })
            }
        }
    }
    
    /**
     The returned WKZombie Action will return the current page.
     
     - returns: The WKZombie Action.
     */
    func inspect<T: Page>() -> Action<T> {
        return Action() { [unowned self] completion in
            self._renderer.currentContent({ (result, response, error) in
                let data = self._handleResponse(result as? Data, response: response, error: error)
                completion(data >>> decodeResult(response?.url))
            })
        }
    }
}

//========================================
// MARK: JavaScript Methods
//========================================

public typealias JavaScript = String
public typealias JavaScriptResult = String

public extension WKZombie {
    
    /**
     The returned WKZombie Action will execute a JavaScript string.
     
     - parameter script: A JavaScript string.
     
     - returns: The WKZombie Action.
     */
    func execute(_ script: JavaScript) -> Action<JavaScriptResult> {
        return Action() { [unowned self] completion in
            self._renderer.executeScript(script, completionHandler: { result, response, error in
                let data = self._handleResponse(result as? Data, response: response, error: error)
                let output = data >>> decodeString
                Logger.log("Script Result".uppercased() + "\n\(output)\n")
                completion(output)
            })
        }
    }
    
    /**
     The returned WKZombie Action will execute a JavaScript string.
     
     - parameter script: A JavaScript string.
     - parameter page: A HTML page.
     
     - returns: The WKZombie Action.
     */
    func execute<T: HTMLPage>(_ script: JavaScript) -> (_ page : T) -> Action<JavaScriptResult> {
        return { [unowned self] (page : T) -> Action<JavaScriptResult> in
            return self.execute(script)
        }
    }
}

#if os(iOS)
    
//========================================
// MARK: Snapshot Methods
//========================================
    
/// Default delay before taking snapshots
private let DefaultSnapshotDelay = 0.1
    
public extension WKZombie {
    
    /**
     The returned WKZombie Action will make a snapshot of the current page.
     Note: This method only works under iOS. Also, a snapshotHandler must be registered.
     
     - returns: A snapshot class.
     */
    func snap<T>(_ element: T) -> Action<T> {
        return Action<T>(operation: { [unowned self] completion in
            delay(DefaultSnapshotDelay, completion: {
                if let snapshotHandler = self.snapshotHandler, let snapshot = self._renderer.snapshot() {
                    snapshotHandler(snapshot)
                    completion(Result.success(element))
                } else {
                    completion(Result.error(.snapshotFailure))
                }
            })
        })
    }
}
    
#endif

//========================================
// MARK: Debug Methods
//========================================

public extension WKZombie {
    /**
     Prints the current state of the WKZombie browser to the console.
     */
    func dump() {
        _renderer.currentContent { (result, response, error) in
            if let output = (result as? Data)?.toString() {
                Logger.log(output)
            } else {
                Logger.log("No Output available.")
            }
        }
    }
    
    /**
     Clears the cache/cookie data (such as login data, etc).
     */
    @available(OSX 10.11, *)
    func clearCache() {
        _renderer.clearCache()
    }
}
