//
//  LoginViewController.swift
//  MTDataAPI
//
//  Created by CHEEBOW on 2015/04/20.
//  Copyright (c) 2015年 CHEEBOW. All rights reserved.
//

import UIKit
import SwiftyJSON
import SVProgressHUD

class LoginViewController: UIViewController {

    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var endpointField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let app = UIApplication.sharedApplication().delegate as! AppDelegate
        self.usernameField.text = app.username
        self.passwordField.text = app.password
        self.endpointField.text = app.endpoint
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    private func login(username: String, password: String, endpoint: String) {
        SVProgressHUD.show()
        let api = DataAPI.sharedInstance
        api.APIBaseURL = endpoint
        api.authentication(username, password: password, remember: true,
            success:{_ in
                SVProgressHUD.dismiss()
                let app = UIApplication.sharedApplication().delegate as! AppDelegate
                app.username = username
                app.password = password
                app.endpoint = endpoint
                app.saveInfo()
                
                self.performSegueWithIdentifier("login",sender: nil)
            },
            failure: {(error: JSON!)-> Void in
                SVProgressHUD.showErrorWithStatus(error["message"].stringValue)
            }
        )
    }
    
    @IBAction func loginButtonPushed(sender: AnyObject) {
        let username = usernameField.text
        let password = passwordField.text
        let endpoint = endpointField.text
        
        if count(username) > 0 && count(password) > 0 && count(endpoint) > 0 {
            self.login(username, password: password, endpoint: endpoint)
        }
    }
}
