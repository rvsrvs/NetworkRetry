//
//  RetryRequest.swift
//  NetworkRetry
//
//  Created by Van Simmons on 11/2/15.
//  Copyright © 2015 AboutObjects. All rights reserved.
//

import Foundation
import Alamofire
import Reachability
import CFNetwork

// Handler for completion of a service call
typealias AlamofireResponseCompletionHandler = (response:Alamofire.Response<AnyObject,NSError>) -> Void

/*
 Retry wrapper function around Alamofire.  This function passes through to Alamofire and
 in the event of a network down error, waits for the network to become available and
 retries the request.  It will perform the retry one time only.

 In addition to the standard Alamofire request parameters which are passed through, this function accepts:
     retry:Bool to indicate whether or not to retry on CFURLErrorNotConnectedToInternet
     waitInterval:Double indicates the time to wait on the network to reappear
     completion:AlamofireResponseCompletionHandler to be called when we finally accept a result from Alamofire.

 This function is implemented as a top level function in the manner of Alamofire's own calls
 The request object created by Alamofire is returned immediately and can be queried
*/
func requestJSON(method: Alamofire.Method, URLString: URLStringConvertible, parameters: [String: AnyObject]? = nil,
    retry:Bool = true, waitInterval:Double = 30.0, completion:AlamofireResponseCompletionHandler) -> Request
{
    // Make a standard Alamofire network request.  We expect to receive JSON back in the response
    let retVal = Alamofire.request(method, URLString, parameters: parameters).responseJSON {
        (response:Response) -> Void in
        // Handle the response from Alamofire.  This callback is invoked
        // After Alamofire has gone to the server, received a response and constructed
        // JSON from the response.  Or received an error along the way
        switch response.result {
        case .Success:
            // Just fall through to the original invoker with the response
            completion(response: response)
        case .Failure( let error ):
            // If we receive an error OTHER THAN CFURLErrorNotConnectedToInternet, then
            // complete with that error because this function does not deal with other error types
            // other errors could be added if desired, however
            if error.code != Int(CFNetworkErrors.CFURLErrorNotConnectedToInternet.rawValue) {
                completion(response: response)
            }
            else {
                // The error encountered is due to Wifi being down.
                
                // If retry is false, this is fatal and we complete with
                // the error response.  This will happen if the network goes
                // down again during our single retry attempt
                if !retry {
                    completion(response: response)
                }
                else {
                    // Wifi is down and retry is true so we will idle
                    // while waiting for it to come back
                    
                    // We use Reachability to test for Wifi availability
                    // Since we want to pause all user interaction
                    // at this point we can check for Wifi availability
                    // inline rather than setting up all the notification
                    // mechanism and using callbacks
                    
                    // NB If we wanted the user to be able to do other tasks while
                    // waiting for this request to complete we would have to queue the request to
                    // background and deal with multiple potential simultaneous actions at once.
                    // This approach is much simpler but is applicable only for this
                    // sort of application.
                    
                    // Create a reachability object
                    if let wifiReach = Reachability.reachabilityForLocalWiFi() {
                        // we will idle until a) the network is up or b) the waitInterval has been exceeded
                        if idleFor(waitInterval, orUntil: { wifiReach.isReachable() }) {
                            // the network came back - call ourself recursively
                            // if the network goes away during this retry call, we will NOT try again
                            // this call will invoke the completion handler for success
                            // hence we set retry to false here
                            requestJSON(method, URLString: URLString,
                                parameters: parameters, retry: false, completion:completion)
                        }
                        else {
                            // the network did not come back, forward the CFURLErrorNotConnectedToInternet
                            // to the original completion handler
                            completion(response: response)
                        } // end if idleFor(waitInterval, orUntil: { wifiReach.isReachable() })
                    }
                    else {
                        print("Unable to create Reachability object.  This is not good")
                        completion(response: response)
                    } // end if let wifiReach = Reachability.reachabilityForLocalWiFi()
                } // end if !retry
            } // end if error.code != Int(CFNetworkErrors.CFURLErrorNotConnectedToInternet.rawValue)
        } // end switch response.result
    } // end let retVal = Alamofire.request(method, URLString, parameters: parameters).responseJSON
    
    return retVal
}

/* 
    idle the thread without hanging. 

    Accepts:
    
    waitInterval:Double - how long to wait in seconds
    orUntil:() -> Bool - a condition which, if met (i.e. true), immediately terminates the func
    and returns true

    orUntil defaults to: { return false } which ensures that the method
    will wait until the waitInterval is exceeded if orUntil is not passed in

    returns true if the orUntil condition was met, false if waitInterval was reached

    NB, as written now, this function only works on the main thread.
    To work on background threads would require creating and adding timers
    to the thread in order to keep runUntilDate from immediately returning
*/
func idleFor(waitInterval:Double, orUntil: () -> Bool = { return false }) -> Bool {
    // The date/time at which we started this call.  In the event the network is unavailable
    // we will give up waiting for it to come back at this time + waitInterval
    let startDate = NSDate()
    var retVal = false
    while (fabs(startDate.timeIntervalSinceNow) < waitInterval) {
        // if the until condition has been met, capture that and break
        retVal = orUntil()
        if retVal { break }
        // Idle but do NOT hang the UI
        // We will do this test every 500 ms to see if we should proceed
        // we might want to make the polling frequency a parameter but 500ms
        // seems reasonable
        NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.5))
    }
    
    return retVal
}
