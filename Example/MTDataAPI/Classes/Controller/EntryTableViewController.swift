//
//  EntryTableViewController.swift
//  MTDataAPI
//
//  Created by CHEEBOW on 2015/04/14.
//  Copyright (c) 2015年 Six Apart, Ltd. All rights reserved.
//

import UIKit
import SwiftyJSON
import SVProgressHUD

class EntryTableViewController: UITableViewController {
    var items = [JSON]()
    var blogID = ""
    var fetching = false
    var total = 0

    func fetch(_ more:Bool) {
        if !more {
            SVProgressHUD.show()
        }
        self.fetching = true
        let api = DataAPI.sharedInstance
        let app = UIApplication.shared.delegate as! AppDelegate
        api.authentication(app.username, password: app.password, remember: true,
            success:{_ in
                var params = ["limit":"15"]
                if more {
                    params["offset"] = "\(self.items.count)"
                }
                
                api.listEntries(siteID: self.blogID, options: params,
                    success: {(result: [JSON]?, total: Int?)-> Void in
                        if let result = result, let total = total {
                            if more {
                                self.items += result
                            } else {
                                self.items = result
                            }
                            self.total = total
                            self.tableView.reloadData()
                        }
                        SVProgressHUD.dismiss()
                        self.fetching = false
                    },
                    failure: {(error: JSON?)-> Void in
                        SVProgressHUD.showError(withStatus: error?["message"].stringValue ?? "")
                        self.fetching = false
                    }
                )
            },
            failure: {(error: JSON?)-> Void in
                SVProgressHUD.showError(withStatus: error?["message"].stringValue ?? "")
                self.fetching = false
            }
        )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.add, target: self, action: #selector(EntryTableViewController.createEntry(_:)))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.fetch(false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: -

    func showDetailView(_ entry: JSON) {
        let storyboard = UIStoryboard(name: "EntryDetail", bundle: nil)
        let vc: EntryDetailViewController = storyboard.instantiateInitialViewController() as! EntryDetailViewController
        vc.entry = entry
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func createEntry(_ sender: UIBarButtonItem) {
        let entry = JSON(["blog":["id":blogID]])
        self.showDetailView(entry)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Potentially incomplete method implementation.
        // Return the number of sections.
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete method implementation.
        // Return the number of rows in the section.
        return self.items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) 

        // Configure the cell...
        let item = items[indexPath.row]
        cell.textLabel?.text = item["title"].stringValue
        cell.detailTextLabel?.text = item["excerpt"].stringValue

        return cell
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return NO if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return NO if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let entry = items[indexPath.row]
        self.showDetailView(entry)
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (self.tableView.contentOffset.y >= (self.tableView.contentSize.height - self.tableView.bounds.size.height)) {
            
            if self.fetching {return}
            if self.total <= self.items.count {return}
            
            self.fetch(true)
        }
    }
}
