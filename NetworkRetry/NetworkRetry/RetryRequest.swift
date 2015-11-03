//
//  RetryQueue.swift
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
public typealias ServiceCompletionHandler = (response:Alamofire.Response<AnyObject,NSError>) -> Void

// Retry wrapper method around Alamofire
// In addition to the standard Alamofire request methods, this accepts:
//     retry:Bool to indicate whether or not to retry on CFURLErrorNotConnectedToInternet
//     waitInterval:Double indicates the time to wait on the network to reappear
//     completion:ServiceCompletionHandler to be called when we finally accept a result from Alamofire
//
// This is implemented as a top level function in the manner of Alamofire's own calls
// The request object is returned immediately and can be queried
func request(method: Alamofire.Method,
    URLString: URLStringConvertible,
    parameters: [String: AnyObject]? = nil,
    retry:Bool = true,
    waitInterval:Double = 30.0,
    completion:ServiceCompletionHandler) -> Request
{
    // The date/time at which we started this call.  In the event the network is unavailable
    // we will give up waiting for it to come back at this time + waitInterval
    let startDate = NSDate()
    
    // Make a standard Alamofire network request.  We expect to receive JSON back
    return Alamofire.request(method, URLString, parameters: parameters)
        .responseJSON { (response:Response) -> Void in
            // Handle the response from Alamofire
            switch response.result {
            case .Success:
                completion(response: response)
            case .Failure( let error ):
                // If we receive an error OTHER THAN CFURLErrorNotConnectedToInternet, then
                // complete with an error because this class does not deal with those errors
                if error.code != Int(CFNetworkErrors.CFURLErrorNotConnectedToInternet.rawValue) {
                    completion(response: response)
                }
                else {
                    // The network is down.  If retry is false, this is fatal
                    if !retry {
                        completion(response: response)
                    }
                    else {
                        // use reachability to test for the network to have come back
                        if let wifiReach = Reachability.reachabilityForLocalWiFi() {
                            // we will idle while a) the network is down and b) the waitInterval has not been exceeded
                            // We will do this test every 500 ms to see if we should proceed
                            while ( !wifiReach.isReachable()
                                && fabs(startDate.timeIntervalSinceNow) < waitInterval) {
                                    // Idle but do NOT hang the UI
                                    NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.5))
                            }
                            // either we have timed out or the network came back before the timeout
                            if wifiReach.isReachable() {
                                // the network came back - call ourself recursively
                                // if the network goes away during this call, DO NOT try again
                                // this call will invoke the completion handler for success
                                request(method, URLString: URLString,
                                    parameters: parameters, retry: false, completion:completion)
                            }
                            else {
                                // the network did not come back, forward the CFURLErrorNotConnectedToInternet
                                // to the person who invoked the request
                                completion(response: response)
                            }
                        }
                    }
                }
            }
    }
}
