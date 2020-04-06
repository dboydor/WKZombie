//
// Functions.swift
//
// Copyright (c) 2016 Mathias Koehnke (http://www.mathiaskoehnke.de)
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


/**
 Convenience functions for accessing the WKZombie shared instance functionality.
 */

//========================================
// MARK: Get Page
//========================================

/**
 The returned WKZombie Action will load and return a HTML or JSON page for the specified URL 
 __using the shared WKZombie instance__.
 - seealso: _open()_ function in _WKZombie_ class for more info.
 */
public func open<T: Page>(_ url: URL) -> Action<T> {
    return WKZombie.sharedInstance.open(url)
}

/**
 The returned WKZombie Action will load and return a HTML or JSON page for the specified URL 
 __using the shared WKZombie instance__.
 - seealso: _open()_ function in _WKZombie_ class for more info.
 */
public func open<T: Page>(then postAction: PostAction) -> (_ url: URL) -> Action<T> {
    return WKZombie.sharedInstance.open(then: postAction)
}

/**
 The returned WKZombie Action will return the current page __using the shared WKZombie instance__.
 - seealso: _inspect()_ function in _WKZombie_ class for more info.
 */
public func inspect<T: Page>() -> Action<T> {
    return WKZombie.sharedInstance.inspect()
}

//========================================
// MARK: JavaScript Methods
//========================================


/**
 The returned WKZombie Action will execute a JavaScript string __using the shared WKZombie instance__.
 - seealso: _execute()_ function in _WKZombie_ class for more info.
 */
public func execute(_ script: JavaScript) -> Action<JavaScriptResult> {
    return WKZombie.sharedInstance.execute(script)
}

/**
 The returned WKZombie Action will execute a JavaScript string __using the shared WKZombie instance__.
 - seealso: _execute()_ function in _WKZombie_ class for more info.
 */
public func execute<T: HTMLPage>(_ script: JavaScript) -> (_ page: T) -> Action<JavaScriptResult> {
    return WKZombie.sharedInstance.execute(script)
}

#if os(iOS)
    
    //========================================
    // MARK: Snapshot Methods
    //========================================
    
    /**
     This is a convenience operator for the _snap()_ command. It is equal to the __>>>__ operator with the difference
     that a snapshot will be taken after the left Action has been finished.
     */
    infix operator >>*: AdditionPrecedence
    
    private func assertIfNotSharedInstance() {
        assert(WKZombie.Static.instance != nil, "The >>* operator can only be used with the WKZombie shared instance.")
    }
    
    public func >>*<T, U>(a: Action<T>, f: @escaping ((T) -> Action<U>)) -> Action<U> {
        assertIfNotSharedInstance()
        return a >>> snap >>> f
    }
    
    public func >>*<T, U>(a: Action<T>, b: Action<U>) -> Action<U> {
        assertIfNotSharedInstance()
        return a >>> snap >>> b
    }
    
    public func >>*<T, U: Page>(a: Action<T>, f: () -> Action<U>) -> Action<U> {
        assertIfNotSharedInstance()
        return a >>> snap >>> f
    }
    
    public func >>*<T:Page, U>(a: () -> Action<T>, f: @escaping ((T) -> Action<U>)) -> Action<U> {
        assertIfNotSharedInstance()
        return a >>> snap >>> f
    }
    
    /**
     The returned WKZombie Action will make a snapshot of the current page.
     Note: This method only works under iOS. Also, a snapshotHandler must be registered.
     __The shared WKZombie instance will be used__.
     - seealso: _snap()_ function in _WKZombie_ class for more info.
     */
    public func snap<T>(_ element: T) -> Action<T> {
        return WKZombie.sharedInstance.snap(element)
    }
    
#endif


//========================================
// MARK: Debug Methods
//========================================


/**
 Prints the current state of the WKZombie browser to the console.
 */
public func dump() {
    WKZombie.sharedInstance.dump()
}

/**
 Clears the cache/cookie data (such as login data, etc).
 */
@available(OSX 10.11, *)
public func clearCache() {
    WKZombie.sharedInstance.clearCache()
}

