//
//  ViewController.swift
//  NetworkRetry
//
//  Created by Van Simmons on 10/29/15.
//  Copyright © 2015 AboutObjects. All rights reserved.
//

import UIKit
import Alamofire

// A test endpoint that will respond with some JSON
let endpoint = "http://api.openweathermap.org/data/2.5/weather?q=portland,or&appid=77e555f36584bc0c3d55e1e584960580"

class ViewController: UIViewController {

    @IBOutlet weak var logTextView: UITextView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func fetch(sender: AnyObject) {
        self.logTextView.text = ""
        self.view.bringSubviewToFront(self.spinner)
        self.spinner.startAnimating()
        
        // Start the request
        let req = NetworkRetry.request(Method.GET, URLString: endpoint, waitInterval: 10.0) { (response) -> Void in
            
            // handle the response which is an Alamofire response object
            switch response.result {
            case .Success(let value):
                self.logTextView.text.appendContentsOf("JSON     = \(value)\n"  ) // result of response serialization
            case .Failure(let error):
                self.logTextView.text.appendContentsOf("error    = \(error)\n"  ) // result of response serialization
            }
            
            let range = NSRange(location: self.logTextView.text.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)-1,length: 1)
            self.logTextView.scrollRangeToVisible(range)
            self.spinner.stopAnimating()
            self.view.sendSubviewToBack(self.spinner)
        }
        print("Now waiting on: \(req)")
    }
}

