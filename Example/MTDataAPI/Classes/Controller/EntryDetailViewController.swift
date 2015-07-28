//
//  EntryDetailViewController.swift
//  MTDataAPI
//
//  Created by CHEEBOW on 2015/04/14.
//  Copyright (c) 2015年 Six Apart, Ltd. All rights reserved.
//

import UIKit
import SwiftyJSON
import SVProgressHUD
import Alamofire

class EntryDetailViewController: UIViewController {
    @IBOutlet weak var titleField: UITextField!
    @IBOutlet weak var bodyTextView: UITextView!
    @IBOutlet weak var statusSwitch: UISwitch!
    
    var entry: JSON!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        println("entry:\(entry)")

        self.titleField.text = entry["title"].stringValue
        self.title = self.titleField.text
        
        self.bodyTextView.text = entry["body"].stringValue
        self.statusSwitch.on = (entry["status"].stringValue == "Publish")
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Save, target: self, action: "save:")
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
    
    func save(sender: UIBarButtonItem) {
        var newEntry = [String:String]()
        newEntry["title"] = self.titleField.text
        newEntry["body"] = self.bodyTextView.text
        newEntry["status"] = self.statusSwitch.on ? "Publish":"Draft"

        let blogID = entry["blog"]["id"].stringValue
        var id: String = entry["id"].stringValue
        
        SVProgressHUD.show()
        let api = MTDataAPI.sharedInstance
        let app = UIApplication.sharedApplication().delegate as! AppDelegate
        
        var success: (JSON!-> Void) = {
            (result: JSON!)-> Void in
            self.navigationController?.popViewControllerAnimated(true)
            SVProgressHUD.dismiss()
        }
        var failure: (JSON!-> Void) = {
            (error: JSON!)-> Void in
            SVProgressHUD.showErrorWithStatus(error["message"].stringValue)
        }
        
        api.authentication(app.username, password: app.password, remember: true,
            success:{_ in
                if id.isEmpty {
                    api.createEntry(siteID: blogID, entry: newEntry, success: success, failure: failure)
                } else {
                    api.updateEntry(siteID: blogID, entryID: id, entry: newEntry, success: success, failure: failure)
                }
            },
            failure: failure
        )
    
    }
}
