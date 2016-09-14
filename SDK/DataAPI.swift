//
//  DataAPI.swift
//  MTDataAPI
//
//  Created by CHEEBOW on 2015/03/23.
//  Copyright (c) 2015年 Six Apart, Ltd. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

class DataAPI: NSObject {

    //MARK: - Properties
    private(set) var token = ""
    private(set) var sessionID = ""

    var endpointVersion = "v3"
    var APIBaseURL = "http://localhost/cgi-bin/MT-6.1/mt-data-api.cgi"
    
    private(set) var apiVersion = ""
    
    var clientID = "MTDataAPIClient"

    struct BasicAuth {
        var username = ""
        var password = ""
    }
    var basicAuth: BasicAuth = BasicAuth()

    static var sharedInstance = DataAPI()

    //MARK: - Methods
    private func APIURL()->String! {
        return APIBaseURL + "/\(endpointVersion)"
    }

    private func APIURL_V2()->String! {
        return APIBaseURL + "/v2"
    }
    
    func urlencoding(src: String)->String! {
        return src.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
    }

    func urldecoding(src: String)->String! {
        return src.stringByRemovingPercentEncoding
    }

    func parseParams(originalUrl: String)->[String:String] {
        let url = originalUrl.componentsSeparatedByString("?")
        let core = url[1]
        let params = core.componentsSeparatedByString("&")
        var dict : [String:String] = [String:String]()

        for param in params{
            let keyValue = param.componentsSeparatedByString("=")
            dict[keyValue[0]] = keyValue[1]
        }
        return dict
    }

    private func errorJSON()->JSON {
        return JSON(["code":"-1", "message":NSLocalizedString("The operation couldn’t be completed.", comment: "The operation couldn’t be completed.")])
    }

    func resetAuth() {
        token = ""
        sessionID = ""
    }

    private func makeRequest(method: Alamofire.Method, url: URLStringConvertible, parameters: [String: AnyObject]? = nil, encoding: ParameterEncoding = .URL, useSession: Bool = (false)) -> Request {
        var headers = Dictionary<String, String>()
        
        if token != "" {
            headers["X-MT-Authorization"] = "MTAuth accessToken=" + token
        }
        if useSession {
            if sessionID != "" {
                headers["X-MT-Authorization"] = "MTAuth sessionId=" + sessionID
            }
        }

        var request = Alamofire.request(method, url, parameters: parameters, encoding: encoding, headers: headers)
        
        if !self.basicAuth.username.isEmpty && !self.basicAuth.password.isEmpty {
            request = request.authenticate(user: self.basicAuth.username, password: self.basicAuth.password)
        }

        return request
    }

    func fetchList(url: String, params: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let request = makeRequest(.GET, url: url, parameters: params)
        request
            .responseJSON { response in
                switch response.result {
                    case .Success(let data):
                        let json = JSON(data)
                        if json["error"].dictionary != nil {
                            failure(json["error"])
                            return
                        }
                        let items = json["items"].array
                        let total = json["totalResults"].intValue
                        success(items:items, total:total)
                    
                    case .Failure(_):
                        failure(self.errorJSON())
                }
        }
    }

    private func actionCommon(action: Alamofire.Method, url: String, params: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let request = makeRequest(action, url: url, parameters: params)
        request
            .responseJSON { response in
                switch response.result {
                case .Success(let data):
                    let json = JSON(data)
                    if json["error"].dictionary != nil {
                        failure(json["error"])
                        return
                    }
                    success(json)
                    
                case .Failure(_):
                    failure(self.errorJSON())
                }

        }
    }

    func action(name: String, action: Alamofire.Method, url: String, object: [String: AnyObject]? = nil, options: [String: AnyObject]?, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var params: [String: AnyObject] = [:]
        if let options = options {
            params = options
        }
        if let object = object {
            let json = JSON(object).rawString()
            params[name] = json
        }
        actionCommon(action, url: url, params: params, success: success, failure: failure)
    }

    private func get(url: String, params: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        actionCommon(.GET, url: url, params: params, success: success, failure: failure)
    }

    private func post(url: String, params: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        actionCommon(.POST, url: url, params: params, success: success, failure: failure)
    }

    private func put(url: String, params: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        actionCommon(.PUT, url: url, params: params, success: success, failure: failure)
    }

    private func delete(url: String, params: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        actionCommon(.DELETE, url: url, params: params, success: success, failure: failure)
    }

    private func repeatAction(action: Alamofire.Method, url: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let request = makeRequest(action, url: url, parameters: options)
        request
            .responseJSON { response in
                switch response.result {
                case .Success(let data):
                    let json = JSON(data)
                    if json["error"].dictionary != nil {
                        failure(json["error"])
                        return
                    }
                    if json["status"].string == "Complete" || json["restIds"].string == "" {
                        success(json)
                    } else {
                        let headers: NSDictionary = response.response!.allHeaderFields
                        if let nextURL = headers["X-MT-Next-Phase-URL"] as? String {
                            let url = self.APIURL() + "/" + nextURL
                            self.repeatAction(action, url: url, options: options, success: success, failure: failure)
                        } else {
                            failure(self.errorJSON())
                        }
                    }
                    
                case .Failure(_):
                    failure(self.errorJSON())
                }
        }
    }
    
    
    func upload(data: NSData, fileName: String, url: String, parameters: [String:String]? = nil, progress: ((Int64!, Int64!, Int64!) -> Void)? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var headers = Dictionary<String, String>()
        
        if token != "" {
            headers["X-MT-Authorization"] = "MTAuth accessToken=" + token
        }
        
        Alamofire.upload(
            .POST,
            url,
            headers: headers,
            multipartFormData: { multipartFormData in
                multipartFormData.appendBodyPart(data: data, name: "file", fileName: fileName, mimeType: "application/octet-stream")
                if let params = parameters {
                    for (key, value) in params {
                        multipartFormData.appendBodyPart(data: value.dataUsingEncoding(NSUTF8StringEncoding)!, name: key)
                    }
                }
            },
            encodingCompletion: { encodingResult in
                switch encodingResult {
                case .Success(let upload, _, _):
                    if !self.basicAuth.username.isEmpty && !self.basicAuth.password.isEmpty {
                        upload.authenticate(user: self.basicAuth.username, password: self.basicAuth.password)
                    }
                    upload.progress{ (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in
                        dispatch_async(dispatch_get_main_queue()) {
                            progress?(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
                        }
                    }.responseJSON { response in
                        switch response.result {
                        case .Success(let data):
                            let json = JSON(data)
                            if json["error"].dictionary != nil {
                                failure(json["error"])
                                return
                            }
                            success(json)
                            
                        case .Failure(_):
                            failure(self.errorJSON())
                        }
                    }
                case .Failure(_):
                    failure(self.errorJSON())
                }
            }
        )
    }

    //MARK: - APIs

    //MARK: - # V2
    //MARK: - System
    func endpoints(success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/endpoints"

        self.fetchList(url, params: nil, success: success, failure: failure)
    }

    //MARK: - Authentication
    func authenticationCommon(url: String, username: String, password: String, remember: Bool, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        resetAuth()

        let params = ["username":username,
                      "password":password,
                      "remember":remember ? "1":"0",
                      "clientId":self.clientID]
        let request = makeRequest(.POST, url: url, parameters: params)
        request
            .responseJSON { response in
                switch response.result {
                case .Success(let data):
                    let json = JSON(data)
                    if json["error"].dictionary != nil {
                        failure(json["error"])
                        return
                    }
                    if let accessToken = json["accessToken"].string {
                        self.token = accessToken
                    }
                    if let session = json["sessionId"].string {
                        self.sessionID = session
                    }
                    success(json)
                    
                case .Failure(_):
                    failure(self.errorJSON())
                }
        }
    }

    func authentication(username: String, password: String, remember: Bool, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/authentication"
        self.authenticationCommon(url, username: username, password: password, remember: remember, success: success, failure: failure)
    }

    func authenticationV2(username: String, password: String, remember: Bool, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL_V2() + "/authentication"
        self.authenticationCommon(url, username: username, password: password, remember: remember, success: success, failure: failure)
    }
    
    func getToken(success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/token"

        let request = makeRequest(.POST, url: url, useSession: true)

        if sessionID == "" {
            failure(self.errorJSON())
            return
        }
        request
            .responseJSON { response in
                switch response.result {
                case .Success(let data):
                    let json = JSON(data)
                    if json["error"].dictionary != nil {
                        failure(json["error"])
                        return
                    }
                    if let accessToken = json["accessToken"].string {
                        self.token = accessToken
                    }
                    success(json)
                    
                case .Failure(_):
                    failure(self.errorJSON())
                }
        }
    }

    func revokeAuthentication(success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/authentication"

        let request = makeRequest(.DELETE, url: url)

        if sessionID == "" {
            failure(self.errorJSON())
            return
        }
        request
            .responseJSON { response in
                switch response.result {
                case .Success(let data):
                    let json = JSON(data)
                    if json["error"].dictionary != nil {
                        failure(json["error"])
                        return
                    }
                    self.sessionID = ""
                    success(json)
                    
                case .Failure(_):
                    failure(self.errorJSON())
                }
        }
    }

    func revokeToken(success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/token"

        self.delete(url, success: {
            (result: JSON!)-> Void in
                self.token = ""
                success(result)
            },
            failure: failure)
    }

    //MARK: - Search
    func search(query: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/search"

        var params: [String: AnyObject] = [:]
        if let options = options {
            params = options
        }
        params["search"] = query

        self.fetchList(url, params: params, success: success, failure: failure)
    }

    //MARK: - Site
    func listSites(options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    func listSitesByParent(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/children"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func siteAction(action: Alamofire.Method, siteID: String?, site: [String: AnyObject]?, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites"
        if action != .POST {
            if let id = siteID {
                url += "/" + id
            }
        }

        self.action("website", action: action, url: url, object: site, options: options, success: success, failure: failure)
    }

    func createSite(site: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.siteAction(.POST, siteID: nil, site: site, options: options, success: success, failure: failure)
    }

    func getSite(siteID siteID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.siteAction(.GET, siteID: siteID, site: nil, options: options, success: success, failure: failure)
    }

    func updateSite(siteID siteID: String, site: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.siteAction(.PUT, siteID: siteID, site: site, options: options, success: success, failure: failure)
    }

    func deleteSite(siteID siteID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.siteAction(.DELETE, siteID: siteID, site: nil, options: options, success: success, failure: failure)
    }

    func backupSite(siteID siteID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/backup"

        self.get(url, params: options, success: success, failure: failure)
    }

    //MARK: - Blog
    func listBlogsForUser(userID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/users/\(userID)/sites"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func blogAction(action: Alamofire.Method, blogID: String?, blog: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites"
        if let id = blogID {
            url += "/" + id
        }

        self.action("blog", action: action, url: url, object: blog, options: options, success: success, failure: failure)
    }

    func createBlog(blog: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.blogAction(.POST, blogID: nil, blog: blog, options: options, success: success, failure: failure)
    }

    func getBlog(blogID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.blogAction(.GET, blogID: blogID, blog: nil, options: options, success: success, failure: failure)
    }

    func updateBlog(blogID: String, blog: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.blogAction(.PUT, blogID: blogID, blog: blog, options: options, success: success, failure: failure)
    }

    func deleteBlog(blogID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.blogAction(.DELETE, blogID: blogID, blog: nil, options: options, success: success, failure: failure)
    }

    //MARK: - Entry
    func listEntries(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/entries"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func entryAction(action: Alamofire.Method, siteID: String, entryID: String? = nil, entry: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/entries"
        if action != .POST {
            if let id = entryID {
                url += "/" + id
            }
        }

        self.action("entry", action: action, url: url, object: entry, options: options, success: success, failure: failure)
    }

    func createEntry(siteID siteID: String, entry: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.entryAction(.POST, siteID: siteID, entryID: nil, entry: entry, options: options, success: success, failure: failure)
    }

    func getEntry(siteID siteID: String, entryID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.entryAction(.GET, siteID: siteID, entryID: entryID, entry: nil, options: options, success: success, failure: failure)
    }

    func updateEntry(siteID siteID: String, entryID: String, entry: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.entryAction(.PUT, siteID: siteID, entryID: entryID, entry: entry, options: options, success: success, failure: failure)
    }

    func deleteEntry(siteID siteID: String, entryID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.entryAction(.DELETE, siteID: siteID, entryID: entryID, entry: nil, options: options, success: success, failure: failure)
    }

    private func listEntriesForObject(objectName: String, siteID: String, objectID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        //objectName:categories,assets,tags
        let url = APIURL() + "/sites/\(siteID)/\(objectName)/\(objectID)/entries"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    func listEntriesForCategory(siteID siteID: String, categoryID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listEntriesForObject("categories", siteID: siteID, objectID: categoryID, options: options, success: success, failure: failure)
    }

    func listEntriesForAsset(siteID siteID: String, assetID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listEntriesForObject("assets", siteID: siteID, objectID: assetID, options: options, success: success, failure: failure)
    }

    func listEntriesForSiteAndTag(siteID siteID: String, tagID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listEntriesForObject("tags", siteID: siteID, objectID: tagID, options: options, success: success, failure: failure)
    }

    func exportEntries(siteID siteID: String, options: [String: AnyObject]? = nil, success: (String! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/entries/export"

        let request = makeRequest(.GET, url: url, parameters: options)
        request
            .response{(request, response, data, error) -> Void in
                if let _ = error {
                    failure(self.errorJSON())
                } else {
                    if let data: NSData = data {
                        let result: String = NSString(data: data, encoding: NSUTF8StringEncoding)! as String
                        if (result.hasPrefix("{\"error\":")) {
                            let json = JSON(data:data)
                            failure(json["error"])
                            return
                        }
                        success(result)
                    } else {
                        failure(self.errorJSON())
                    }
                }
        }
    }

    func publishEntries(entryIDs: [String], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/publish/entries"

        var params: [String: AnyObject] = [:]
        if let options = options {
            params = options
        }
        params["ids"] = entryIDs.joinWithSeparator(",")

        self.repeatAction(.GET, url: url, options: params, success: success, failure: failure)
    }


    private func importEntriesWithFile(siteID siteID: String, importData: NSData, options: [String: String]? = nil, progress: ((Int64!, Int64!, Int64!) -> Void)? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/entries/import"

        self.upload(importData, fileName: "import.dat", url: url, parameters: options, progress: progress, success: success, failure: failure)
    }

    func importEntries(siteID siteID: String, importData: NSData? = nil, options: [String: String]? = nil, progress: ((Int64!, Int64!, Int64!) -> Void)? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {

        if importData != nil {
            self.importEntriesWithFile(siteID: siteID, importData: importData!, options: options, progress: progress, success: success, failure: failure)
            return
        }

        let url = APIURL() + "/sites/\(siteID)/entries/import"

        self.post(url, params: options, success: success, failure: failure)
    }
    
    func previewEntry(siteID siteID: String, entryID: String? = nil, entry: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/entries"
        if let id = entryID {
            url += "/\(id)/preview"
        } else {
            url += "/preview"
        }
        
        self.action("entry", action: .POST, url: url, object: entry, options: options, success: success, failure: failure)
    }

    //MARK: - Page
    func listPages(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/pages"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func pageAction(action: Alamofire.Method, siteID: String, pageID: String? = nil, page: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/pages"
        if action != .POST {
            if let id = pageID {
                url += "/" + id
            }
        }

        self.action("page", action: action, url: url, object: page, options: options, success: success, failure: failure)
    }

    func createPage(siteID siteID: String, page: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.pageAction(.POST, siteID: siteID, pageID: nil, page: page, options: options, success: success, failure: failure)
    }

    func getPage(siteID siteID: String, pageID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.pageAction(.GET, siteID: siteID, pageID: pageID, page: nil, options: options, success: success, failure: failure)
    }

    func updatePage(siteID siteID: String, pageID: String, page: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.pageAction(.PUT, siteID: siteID, pageID: pageID, page: page, options: options, success: success, failure: failure)
    }

    func deletePage(siteID siteID: String, pageID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.pageAction(.DELETE, siteID: siteID, pageID: pageID, page: nil, options: options, success: success, failure: failure)
    }

    private func listPagesForObject(objectName: String, siteID: String, objectID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        //objectName:assets,tags,folders
        let url = APIURL() + "/sites/\(siteID)/\(objectName)/\(objectID)/pages"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    func listPagesForFolder(siteID siteID: String, folderID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listPagesForObject("folders", siteID: siteID, objectID: folderID, options: options, success: success, failure: failure)
    }

    func listPagesForAsset(siteID siteID: String, assetID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listPagesForObject("assets", siteID: siteID, objectID: assetID, options: options, success: success, failure: failure)
    }

    func listPagesForSiteAndTag(siteID siteID: String, tagID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listPagesForObject("tags", siteID: siteID, objectID: tagID, options: options, success: success, failure: failure)
    }

    func previewPage(siteID siteID: String, pageID: String? = nil, entry: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/pages"
        if let id = pageID {
            url += "/\(id)/preview"
        } else {
            url += "/preview"
        }
        
        self.action("page", action: .POST, url: url, object: entry, options: options, success: success, failure: failure)
    }

    //MARK: - Category
    func listCategories(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/categories"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func categoryAction(action: Alamofire.Method, siteID: String, categoryID: String? = nil, category: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/categories"
        if action != .POST {
            if let id = categoryID {
                url += "/" + id
            }
        }

        self.action("category", action: action, url: url, object: category, options: options, success: success, failure: failure)
    }

    func createCategory(siteID siteID: String, category: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.categoryAction(.POST, siteID: siteID, categoryID: nil, category: category, options: options, success: success, failure: failure)
    }

    func getCategory(siteID siteID: String, categoryID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.categoryAction(.GET, siteID: siteID, categoryID: categoryID, category: nil, options: options, success: success, failure: failure)
    }

    func updateCategory(siteID siteID: String, categoryID: String, category: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.categoryAction(.PUT, siteID: siteID, categoryID: categoryID, category: category, options: options, success: success, failure: failure)
    }

    func deleteCategory(siteID siteID: String, categoryID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.categoryAction(.DELETE, siteID: siteID, categoryID: categoryID, category: nil, options: options, success: success, failure: failure)
    }

    func listCategoriesForEntry(siteID siteID: String, entryID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/entries/\(entryID)/categories"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func listCategoriesForRelation(relation: String, siteID: String, categoryID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        //relation:parents,siblings,children
        let url = APIURL() + "/sites/\(siteID)/categories/\(categoryID)/\(relation)"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    func listParentCategories(siteID siteID: String, categoryID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listCategoriesForRelation("parents", siteID: siteID, categoryID: categoryID, options: options, success: success, failure: failure)
    }

    func listSiblingCategories(siteID siteID: String, categoryID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listCategoriesForRelation("siblings", siteID: siteID, categoryID: categoryID, options: options, success: success, failure: failure)
    }

    func listChildCategories(siteID siteID: String, categoryID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listCategoriesForRelation("children", siteID: siteID, categoryID: categoryID, options: options, success: success, failure: failure)
    }

    func permutateCategories(siteID siteID: String, categories: [[String: AnyObject]]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/categories/permutate"

        var params: [String: AnyObject] = [:]
        if let options = options {
            params = options
        }
        if let categories = categories {
            let json = JSON(categories).rawString()
            params["categories"] = json
        }

        self.post(url, params: params, success: success, failure: failure)
    }

    //MARK: - Folder
    func listFolders(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/folders"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func folderAction(action: Alamofire.Method, siteID: String, folderID: String? = nil, folder: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/folders"
        if let id = folderID {
            url += "/" + id
        }

        self.action("folder", action: action, url: url, object: folder, options: options, success: success, failure: failure)
    }

    func createFolder(siteID siteID: String, folder: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.folderAction(.POST, siteID: siteID, folderID: nil, folder: folder, options: options, success: success, failure: failure)
    }

    func getFolder(siteID siteID: String, folderID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.folderAction(.GET, siteID: siteID, folderID: folderID, folder: nil, options: options, success: success, failure: failure)
    }

    func updateFolder(siteID siteID: String, folderID: String, folder: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.folderAction(.PUT, siteID: siteID, folderID: folderID, folder: folder, options: options, success: success, failure: failure)
    }

    func deleteFolder(siteID siteID: String, folderID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.folderAction(.DELETE, siteID: siteID, folderID: folderID, folder: nil, options: options, success: success, failure: failure)
    }

    private func listFoldersForRelation(relation: String, siteID: String, folderID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        //relation:parents,siblings,children
        let url = APIURL() + "/sites/\(siteID)/folders/\(folderID)/\(relation)"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    func listParentFolders(siteID siteID: String, folderID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listFoldersForRelation("parents", siteID: siteID, folderID: folderID, options: options, success: success, failure: failure)
    }

    func listSiblingFolders(siteID siteID: String, folderID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listFoldersForRelation("siblings", siteID: siteID, folderID: folderID, options: options, success: success, failure: failure)
    }

    func listChildFolders(siteID siteID: String, folderID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listFoldersForRelation("children", siteID: siteID, folderID: folderID, options: options, success: success, failure: failure)
    }

    func permutateFolders(siteID siteID: String, folders: [[String: AnyObject]]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/folders/permutate"

        var params: [String: AnyObject] = [:]
        if let options = options {
            params = options
        }
        if let folders = folders {
            let json = JSON(folders).rawString()
            params["folders"] = json
        }

        self.post(url, params: params, success: success, failure: failure)
    }

    //MARK: - Tag
    func listTags(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/tags"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func tagAction(action: Alamofire.Method, siteID: String, tagID: String, tag: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        if action == .POST {
            failure(self.errorJSON())
            return
        }
        let url = APIURL() + "/sites/\(siteID)/tags/\(tagID)"

        self.action("tag", action: action, url: url, object: tag, options: options, success: success, failure: failure)
    }

    func getTag(siteID siteID: String, tagID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.tagAction(.GET, siteID: siteID, tagID: tagID, tag: nil, options: options, success: success, failure: failure)
    }

    func updateTag(siteID siteID: String, tagID: String, tag: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.tagAction(.PUT, siteID: siteID, tagID: tagID, tag: tag, options: options, success: success, failure: failure)
    }

    func deleteTag(siteID siteID: String, tagID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.tagAction(.DELETE, siteID: siteID, tagID: tagID, tag: nil, options: options, success: success, failure: failure)
    }

    //MARK: - User
    func listUsers(options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/users"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func userAction(action: Alamofire.Method, userID: String? = nil, user: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/users"
        if action != .POST {
            if let id = userID {
                url += "/" + id
            }
        }

        self.action("user", action: action, url: url, object: user, options: options, success: success, failure: failure)
    }

    func createUser(user: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.userAction(.POST, userID: nil, user: user, options: options, success: success, failure: failure)
    }

    func getUser(userID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.userAction(.GET, userID: userID, user: nil, options: options, success: success, failure: failure)
    }

    func updateUser(userID: String, user: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.userAction(.PUT, userID: userID, user: user, options: options, success: success, failure: failure)
    }

    func deleteUser(userID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.userAction(.DELETE, userID: userID, user: nil, options: options, success: success, failure: failure)
    }

    func unlockUser(userID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/users/\(userID)/unlock"

        self.post(url, params: options, success: success, failure: failure)
    }

    func recoverPasswordForUser(userID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/users/\(userID)/recover_password"

        self.post(url, params: options, success: success, failure: failure)
    }

    func recoverPassword(name: String, email: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/recover_password"

        var params: [String: AnyObject] = [:]
        if let options = options {
            params = options
        }

        params["name"] = name
        params["email"] = email

        self.post(url, params: params, success: success, failure: failure)
    }

    //MARK: - Asset
    func listAssets(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/assets"

        self.fetchList(url, params: options, success: success, failure: failure)
    }
    
    func uploadAsset(assetData: NSData, fileName: String, options: [String: String]? = nil, progress: ((Int64!, Int64!, Int64!) -> Void)? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.uploadAssetForSite(nil, assetData: assetData, fileName: fileName, options: options, progress: progress, success: success, failure: failure)
    }

    func uploadAssetForSite(siteID: String? = nil, assetData: NSData, fileName: String, options: [String: String]? = nil, progress: ((Int64!, Int64!, Int64!) -> Void)? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/"
        if let siteID = siteID {
            url += "sites/\(siteID)/assets/upload"
        } else {
            url += "assets/upload"
        }

        self.upload(assetData, fileName: fileName, url: url, parameters: options, progress: progress, success: success, failure: failure)
    }

    private func assetAction(action: Alamofire.Method, siteID: String, assetID: String, asset: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/assets"
        if action != .POST {
            url += "/" + assetID
        } else {
            failure(self.errorJSON())
            return
        }

        self.action("asset", action: action, url: url, object: asset, options: options, success: success, failure: failure)
    }

    func getAsset(siteID siteID: String, assetID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.assetAction(.GET, siteID: siteID, assetID: assetID, asset: nil, options: options, success: success, failure: failure)
    }

    func updateAsset(siteID siteID: String, assetID: String, asset: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.assetAction(.PUT, siteID: siteID, assetID: assetID, asset: asset, options: options, success: success, failure: failure)
    }

    func deleteAsset(siteID siteID: String, assetID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.assetAction(.DELETE, siteID: siteID, assetID: assetID, asset: nil, options: options, success: success, failure: failure)
    }

    private func listAssetsForObject(objectName: String, siteID: String, objectID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        //objectName:entries,pages,tags
        let url = APIURL() + "/sites/\(siteID)/\(objectName)/\(objectID)/assets"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    func listAssetsForEntry(siteID siteID: String, entryID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listAssetsForObject("entries", siteID: siteID, objectID: entryID, options: options, success: success, failure: failure)
    }

    func listAssetsForPage(siteID siteID: String, pageID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listAssetsForObject("pages", siteID: siteID, objectID: pageID, options: options, success: success, failure: failure)
    }

    func listAssetsForSiteAndTag(siteID siteID: String, tagID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.listAssetsForObject("tags", siteID: siteID, objectID: tagID, options: options, success: success, failure: failure)
    }

    func getThumbnail(siteID siteID: String, assetID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/assets/\(assetID)/thumbnail"

        self.get(url, params: options, success: success, failure: failure)
    }

    //MARK: - Comment
    func listComments(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/comments"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func commentAction(action: Alamofire.Method, siteID: String, commentID: String, comment: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/comments"
        if action != .POST {
            url += "/" + commentID
        } else {
            //use createCommentForEntry or createCommentForPage
            failure(self.errorJSON())
            return
        }

        self.action("comment", action: action, url: url, object: comment, options: options, success: success, failure: failure)
    }

    func getComment(siteID siteID: String, commentID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.commentAction(.GET, siteID: siteID, commentID: commentID, comment: nil, options: options, success: success, failure: failure)
    }

    func updateComment(siteID siteID: String, commentID: String, comment: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.commentAction(.PUT, siteID: siteID, commentID: commentID, comment: comment, options: options, success: success, failure: failure)
    }

    func deleteComment(siteID siteID: String, commentID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.commentAction(.DELETE, siteID: siteID, commentID: commentID, comment: nil, options: options, success: success, failure: failure)
    }

    private func listCommentsForObject(objectName: String, siteID: String, objectID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        //objectName:entries,pages
        let url = APIURL() + "/sites/\(siteID)/\(objectName)/\(objectID)/comments"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    func listCommentsForEntry(siteID siteID: String, entryID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.listCommentsForObject("entries", siteID: siteID, objectID: entryID, options: options, success: success, failure: failure)
    }

    func listCommentsForPage(siteID siteID: String, pageID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.listCommentsForObject("pages", siteID: siteID, objectID: pageID, options: options, success: success, failure: failure)
    }

    private func createCommentForObject(objectName: String, siteID: String, objectID: String, comment: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        //objectName:entries,pages
        let url = APIURL() + "/sites/\(siteID)/\(objectName)/\(objectID)/comments"

        self.action("comment", action: .POST, url: url, object: comment, options: options, success: success, failure: failure)
    }

    func createCommentForEntry(siteID siteID: String, entryID: String, comment: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.createCommentForObject("entries", siteID: siteID, objectID: entryID, comment: comment, options: options, success: success, failure: failure)
    }

    func createCommentForPage(siteID siteID: String, pageID: String, comment: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.createCommentForObject("pages", siteID: siteID, objectID: pageID, comment: comment, options: options, success: success, failure: failure)
    }

    private func createReplyCommentForObject(objectName: String, siteID: String, objectID: String, commentID: String, reply: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        //objectName:entries,pages
        let url = APIURL() + "/sites/\(siteID)/\(objectName)/\(objectID)/comments/\(commentID)/replies"

        self.action("comment", action: .POST, url: url, object: reply, options: options, success: success, failure: failure)
    }

    func createReplyCommentForEntry(siteID siteID: String, entryID: String, commentID: String, reply: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.createReplyCommentForObject("entries", siteID: siteID, objectID: entryID, commentID: commentID, reply: reply, options: options, success: success, failure: failure)
    }

    func createReplyCommentForPage(siteID siteID: String, pageID: String, commentID: String, reply: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.createReplyCommentForObject("pages", siteID: siteID, objectID: pageID, commentID: commentID, reply: reply, options: options, success: success, failure: failure)
    }

    //MARK: - Trackback
    func listTrackbacks(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/trackbacks"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func trackbackAction(action: Alamofire.Method, siteID: String, trackbackID: String, trackback: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/trackbacks"
        if action != .POST {
            url += "/" + trackbackID
        } else {
            failure(self.errorJSON())
            return
        }

        self.action("comment", action: action, url: url, object: trackback, options: options, success: success, failure: failure)
    }

    func getTrackback(siteID siteID: String, trackbackID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.trackbackAction(.GET, siteID: siteID, trackbackID: trackbackID, trackback: nil, options: options, success: success, failure: failure)
    }

    func updateTrackback(siteID siteID: String, trackbackID: String, trackback: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.trackbackAction(.PUT, siteID: siteID, trackbackID: trackbackID, trackback: trackback, options: options, success: success, failure: failure)
    }

    func deleteTrackback(siteID siteID: String, trackbackID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.trackbackAction(.DELETE, siteID: siteID, trackbackID: trackbackID, trackback: nil, options: options, success: success, failure: failure)
    }

    private func listTrackbackForObject(objectName: String, siteID: String, objectID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        //objectName:entries,pages
        let url = APIURL() + "/sites/\(siteID)/\(objectName)/\(objectID)/trackbacks"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    func listTrackbackForEntry(siteID siteID: String, entryID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.listTrackbackForObject("entries", siteID: siteID, objectID: entryID, options: options, success: success, failure: failure)
    }

    func listTrackbackForPage(siteID siteID: String, pageID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.listTrackbackForObject("pages", siteID: siteID, objectID: pageID, options: options, success: success, failure: failure)
    }

    //MARK: - Field
    func listFields(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/fields"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func fieldAction(action: Alamofire.Method, siteID: String, fieldID: String? = nil, field: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/fields"
        if action != .POST {
            if let fieldID = fieldID {
                url += "/" + fieldID
            }
        }

        self.action("field", action: action, url: url, object: field, options: options, success: success, failure: failure)
    }

    func createField(siteID siteID: String, field: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.fieldAction(.POST, siteID: siteID, fieldID: nil, field: field, options: options, success: success, failure: failure)
    }

    func getField(siteID siteID: String, fieldID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.fieldAction(.GET, siteID: siteID, fieldID: fieldID, field: nil, options: options, success: success, failure: failure)
    }

    func updateField(siteID siteID: String, fieldID: String, field: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.fieldAction(.PUT, siteID: siteID, fieldID: fieldID, field: field, options: options, success: success, failure: failure)
    }

    func deleteField(siteID siteID: String, fieldID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.fieldAction(.DELETE, siteID: siteID, fieldID: fieldID, field: nil, options: options, success: success, failure: failure)
    }

    //MARK: - Template
    func listTemplates(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/templates"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func templateAction(action: Alamofire.Method, siteID: String, templateID: String? = nil, template: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/templates"
        if action != .POST {
            if let id = templateID {
                url += "/" + id
            }
        }

        self.action("template", action: action, url: url, object: template, options: options, success: success, failure: failure)
    }

    func createTemplate(siteID siteID: String, template: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.templateAction(.POST, siteID: siteID, templateID: nil, template: template, options: options, success: success, failure: failure)
    }

    func getTemplate(siteID siteID: String, templateID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.templateAction(.GET, siteID: siteID, templateID: templateID, template: nil, options: options, success: success, failure: failure)
    }

    func updateTemplate(siteID siteID: String, templateID: String, template: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.templateAction(.PUT, siteID: siteID, templateID: templateID, template: template, options: options, success: success, failure: failure)
    }

    func deleteTemplate(siteID siteID: String, templateID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.templateAction(.DELETE, siteID: siteID, templateID: templateID, template: nil, options: options, success: success, failure: failure)
    }

    func publishTemplate(siteID siteID: String, templateID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/templates/\(templateID)/publish"

        self.post(url, params: options, success: success, failure: failure)
    }

    func refreshTemplate(siteID siteID: String, templateID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/templates/\(templateID)/refresh"

        self.post(url, params: options, success: success, failure: failure)
    }

    func refreshTemplateForSite(siteID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/refresh_templates"

        self.post(url, params: options, success: success, failure: failure)
    }

    func cloneTemplate(siteID siteID: String, templateID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/templates/\(templateID)/clone"

        self.post(url, params: options, success: success, failure: failure)
    }

    //MARK: - TemplateMap
    func listTemplateMaps(siteID siteID: String, templateID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/templates/\(templateID)/templatemaps"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func templateMapAction(action: Alamofire.Method, siteID: String, templateID: String, templateMapID: String? = nil, templateMap: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/templates/\(templateID)/templatemaps"
        if action != .POST {
            if let id = templateMapID {
                url += "/" + id
            }
        }

        self.action("templatemap", action: action, url: url, object: templateMap, options: options, success: success, failure: failure)
    }

    func createTemplateMap(siteID siteID: String, templateID: String, templateMap: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.templateMapAction(.POST, siteID: siteID, templateID: templateID, templateMapID: nil, templateMap: templateMap, options: options, success: success, failure: failure)
    }

    func getTemplateMap(siteID siteID: String, templateID: String, templateMapID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.templateMapAction(.GET, siteID: siteID, templateID: templateID, templateMapID: templateMapID, templateMap: nil, options: options, success: success, failure: failure)
    }

    func updateTemplateMap(siteID siteID: String, templateID: String, templateMapID: String, templateMap: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.templateMapAction(.PUT, siteID: siteID, templateID: templateID, templateMapID: templateMapID, templateMap: templateMap, options: options, success: success, failure: failure)
    }

    func deleteTemplateMap(siteID siteID: String, templateID: String, templateMapID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.templateMapAction(.DELETE, siteID: siteID, templateID: templateID, templateMapID: templateMapID, templateMap: nil, options: options, success: success, failure: failure)
    }

    //MARK: - Widget
    func listWidgets(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/widgets"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    func listWidgetsForWidgetset(siteID siteID: String, widgetsetID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/widgetsets/\(widgetsetID)/widgets"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    func getWidgetForWidgetset(siteID siteID: String, widgetSetID: String, widgetID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/widgetsets/\(widgetSetID)/widgets/\(widgetID)"

        self.action("widget", action: .GET, url: url, options: options, success: success, failure: failure)
    }

    private func widgetAction(action: Alamofire.Method, siteID: String, widgetID: String? = nil, widget: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/widgets"
        if action != .POST {
            if let id = widgetID {
                url += "/" + id
            }
        }

        self.action("widget", action: action, url: url, object: widget, options: options, success: success, failure: failure)
    }

    func createWidget(siteID siteID: String, widget: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.widgetAction(.POST, siteID: siteID, widgetID: nil, widget: widget, options: options, success: success, failure: failure)
    }

    func getWidget(siteID siteID: String, widgetID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.widgetAction(.GET, siteID: siteID, widgetID: widgetID, widget: nil, options: options, success: success, failure: failure)
    }

    func updateWidget(siteID siteID: String, widgetID: String, widget: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.widgetAction(.PUT, siteID: siteID, widgetID: widgetID, widget: widget, options: options, success: success, failure: failure)
    }

    func deleteWidget(siteID siteID: String, widgetID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.widgetAction(.DELETE, siteID: siteID, widgetID: widgetID, widget: nil, options: options, success: success, failure: failure)
    }

    func refreshWidget(siteID siteID: String, widgetID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/widgets/\(widgetID)/refresh"

        self.post(url, params: options, success: success, failure: failure)
    }

    func cloneWidget(siteID siteID: String, widgetID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/widgets/\(widgetID)/clone"

        self.post(url, params: options, success: success, failure: failure)
    }

    //MARK: - WidgetSet
    func listWidgetSets(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/widgetsets"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func widgetSetAction(action: Alamofire.Method, siteID: String, widgetSetID: String? = nil, widgetSet: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/widgetsets"
        if action != .POST {
            if let id = widgetSetID {
                url += "/" + id
            }
        }

        self.action("widgetset", action: action, url: url, object: widgetSet, options: options, success: success, failure: failure)
    }

    func createWidgetSet(siteID siteID: String, widgetSet: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.widgetSetAction(.POST, siteID: siteID, widgetSetID: nil, widgetSet: widgetSet, options: options, success: success, failure: failure)
    }

    func getWidgetSet(siteID siteID: String, widgetSetID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.widgetSetAction(.GET, siteID: siteID, widgetSetID: widgetSetID, widgetSet: nil, options: options, success: success, failure: failure)
    }

    func updateWidgetSet(siteID siteID: String, widgetSetID: String, widgetSet: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.widgetSetAction(.PUT, siteID: siteID, widgetSetID: widgetSetID, widgetSet: widgetSet, options: options, success: success, failure: failure)
    }

    func deleteWidgetSet(siteID siteID: String, widgetSetID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.widgetSetAction(.DELETE, siteID: siteID, widgetSetID: widgetSetID, widgetSet: nil, options: options, success: success, failure: failure)
    }

    //MARK: - Theme
    func listThemes(options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/themes"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    func getTheme(themeID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/themes/\(themeID)"

        self.get(url, params: options, success: success, failure: failure)
    }

    func applyThemeToSite(siteID siteID: String, themeID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/themes/\(themeID)/apply"

        self.post(url, params: options, success: success, failure: failure)
    }

    func uninstallTheme(themeID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/themes/\(themeID)"

        self.delete(url, params: options, success: success, failure: failure)
    }

    func exportSiteTheme(siteID siteID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/export_theme"

        self.post(url, params: options, success: success, failure: failure)
    }

    //MARK: - Role
    func listRoles(options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/roles"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func roleAction(action: Alamofire.Method, roleID: String? = nil, role: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/roles"
        if action != .POST {
            if let id = roleID {
                url += "/" + id
            }
        }

        self.action("role", action: action, url: url, object: role, options: options, success: success, failure: failure)
    }

    func createRole(role: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.roleAction(.POST, roleID: nil, role: role, options: options, success: success, failure: failure)
    }

    func getRole(roleID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.roleAction(.GET, roleID: roleID, role: nil, options: options, success: success, failure: failure)
    }

    func updateRole(roleID: String, role: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.roleAction(.PUT, roleID: roleID, role: role, options: options, success: success, failure: failure)
    }

    func deleteRole(roleID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.roleAction(.DELETE, roleID: roleID, role: nil, options: options, success: success, failure: failure)
    }

    //MARK: - Permission
    func listPermissions(options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/permissions"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func listPermissionsForObject(objectName: String, objectID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        //objectName:users,sites,roles
        let url = APIURL() + "/\(objectName)/\(objectID)/permissions"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    func listPermissionsForUser(userID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.listPermissionsForObject("users", objectID: userID, options: options, success: success, failure: failure)
    }

    func listPermissionsForSite(siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.listPermissionsForObject("sites", objectID: siteID, options: options, success: success, failure: failure)
    }

    func listPermissionsForRole(roleID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.listPermissionsForObject("roles", objectID: roleID, options: options, success: success, failure: failure)
    }

    func grantPermissionToSite(siteID: String, userID: String, roleID: String, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/permissions/grant"

        var params: [String:String] = [:]
        params["user_id"] = userID
        params["role_id"] = roleID

        self.post(url, params: params, success: success, failure: failure)
    }

    func grantPermissionToUser(userID: String, siteID: String, roleID: String, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "//users/\(userID)/permissions/grant"

        var params: [String:String] = [:]
        params["site_id"] = siteID
        params["role_id"] = roleID

        self.post(url, params: params, success: success, failure: failure)
    }

    func revokePermissionToSite(siteID: String, userID: String, roleID: String, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/permissions/revoke"

        var params: [String:String] = [:]
        params["user_id"] = userID
        params["role_id"] = roleID

        self.post(url, params: params, success: success, failure: failure)
    }

    func revokePermissionToUser(userID: String, siteID: String, roleID: String, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/users/\(userID)/permissions/revoke"

        var params: [String:String] = [:]
        params["site_id"] = siteID
        params["role_id"] = roleID

        self.post(url, params: params, success: success, failure: failure)
    }

    //MARK: - Log
    func listLogs(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/logs"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func logAction(action: Alamofire.Method, siteID: String, logID: String? = nil, log: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/logs"
        if action != .POST {
            if let id = logID {
                url += "/" + id
            }
        }

        self.action("log", action: action, url: url, object: log, options: options, success: success, failure: failure)
    }

    func createLog(siteID siteID: String, log: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.logAction(.POST, siteID: siteID, logID: nil, log: log, options: options, success: success, failure: failure)
    }

    func getLog(siteID siteID: String, logID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.logAction(.GET, siteID: siteID, logID: logID, log: nil, options: options, success: success, failure: failure)
    }

    func updateLog(siteID siteID: String, logID: String, log: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.logAction(.PUT, siteID: siteID, logID: logID, log: log, options: options, success: success, failure: failure)
    }

    func deleteLog(siteID siteID: String, logID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.logAction(.DELETE, siteID: siteID, logID: logID, log: nil, options: options, success: success, failure: failure)
    }

    func resetLogs(siteID siteID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/logs"

        self.delete(url, params: options, success: success, failure: failure)
    }

    func exportLogs(siteID siteID: String, options: [String: AnyObject]? = nil, success: (String! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/logs/export"

        let request = makeRequest(.GET, url: url, parameters: options)
        request
            .response{(request, response, data, error) -> Void in
                if let _ = error {
                    failure(self.errorJSON())
                } else {
                    if let data: NSData = data {
                        //FIXME:ShiftJIS以外の場合もある？
                        let result: String = NSString(data: data, encoding: NSShiftJISStringEncoding)! as String
                        if (result.hasPrefix("{\"error\":")) {
                            let json = JSON(data:data)
                            failure(json["error"])
                            return
                        }
                        success(result)
                    } else {
                        failure(self.errorJSON())
                    }
                }
        }
    }

    //MARK: - FormattedText
    func listFormattedTexts(siteID siteID: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/formatted_texts"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    private func formattedTextAction(action: Alamofire.Method, siteID: String, formattedTextID: String? = nil, formattedText: [String: AnyObject]? = nil, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/formatted_texts"
        if action != .POST {
            if let id = formattedTextID {
                url += "/" + id
            }
        }

        self.action("formatted_text", action: action, url: url, object: formattedText, options: options, success: success, failure: failure)
    }

    func createFormattedText(siteID siteID: String, formattedText: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.formattedTextAction(.POST, siteID: siteID, formattedTextID: nil, formattedText: formattedText, options: options, success: success, failure: failure)
    }

    func getFormattedText(siteID siteID: String, formattedTextID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.formattedTextAction(.GET, siteID: siteID, formattedTextID: formattedTextID, formattedText: nil, options: options, success: success, failure: failure)
    }

    func updateFormattedText(siteID siteID: String, formattedTextID: String, formattedText: [String: AnyObject], options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.formattedTextAction(.PUT, siteID: siteID, formattedTextID: formattedTextID, formattedText: formattedText, options: options, success: success, failure: failure)
    }

    func deleteFormattedText(siteID siteID: String, formattedTextID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.formattedTextAction(.DELETE, siteID: siteID, formattedTextID: formattedTextID, formattedText: nil, options: options, success: success, failure: failure)
    }

    //MARK: - Stats
    func getStatsProvider(siteID siteID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/stats/provider"

        self.get(url, params: options, success: success, failure: failure)
    }

    private func listStatsForTarget(siteID siteID: String, targetName: String, objectName: String, startDate: String, endDate: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/stats/\(targetName)/\(objectName)"

        var params: [String: AnyObject] = [:]
        if let options = options {
            params = options
        }
        params["startDate"] = startDate
        params["endDate"] = endDate

        self.fetchList(url, params: params, success: success, failure: failure)
    }

    private func listStatsForPath(siteID siteID: String, objectName: String, startDate: String, endDate: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {

        //objectName:pageviews, visits
        self.listStatsForTarget(siteID: siteID, targetName: "path", objectName: objectName, startDate: startDate, endDate: endDate, options: options, success: success, failure: failure)
    }

    func pageviewsForPath(siteID siteID: String, startDate: String, endDate: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.listStatsForPath(siteID: siteID, objectName: "pageviews", startDate: startDate, endDate: endDate, options: options, success: success, failure: failure)
    }

    func visitsForPath(siteID siteID: String, startDate: String, endDate: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.listStatsForPath(siteID: siteID, objectName: "visits", startDate: startDate, endDate: endDate, options: options, success: success, failure: failure)
    }

    private func listStatsForDate(siteID siteID: String, objectName: String, startDate: String, endDate: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {

        //objectName:pageviews, visits
        self.listStatsForTarget(siteID: siteID, targetName: "date", objectName: objectName, startDate: startDate, endDate: endDate, options: options, success: success, failure: failure)
    }

    func pageviewsForDate(siteID siteID: String, startDate: String, endDate: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.listStatsForDate(siteID: siteID, objectName: "pageviews", startDate: startDate, endDate: endDate, options: options, success: success, failure: failure)
    }

    func visitsForDate(siteID siteID: String, startDate: String, endDate: String, options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {

        self.listStatsForDate(siteID: siteID, objectName: "visits", startDate: startDate, endDate: endDate, options: options, success: success, failure: failure)
    }

    //MARK: - Plugin
    func listPlugins(options: [String: AnyObject]? = nil, success: ((items:[JSON]!, total:Int!) -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/plugins"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    func getPlugin(pluginID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIURL() + "/plugins/\(pluginID)"

        self.get(url, params: options, success: success, failure: failure)
    }

    private func togglePlugin(pluginID: String, enable: Bool, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        var url = APIURL() + "/plugins"

        if pluginID != "*" {
            url += "/" + pluginID
        }

        if enable {
            url += "/enable"
        } else {
            url += "/disable"
        }

        self.post(url, params: options, success: success, failure: failure)
    }

    func enablePlugin(pluginID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.togglePlugin(pluginID, enable: true, options: options, success: success, failure: failure)
    }

    func disablePlugin(pluginID: String, options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.togglePlugin(pluginID, enable: false, options: options, success: success, failure: failure)
    }

    func enableAllPlugin(options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.togglePlugin("*", enable: true, options: options, success: success, failure: failure)
    }

    func disableAllPlugin(options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        self.togglePlugin("*", enable: false, options: options, success: success, failure: failure)
    }

    //MARK: - # V3
    //MARK: - Version
    func version(options: [String: AnyObject]? = nil, success: (JSON! -> Void)!, failure: (JSON! -> Void)!)->Void {
        let url = APIBaseURL + "/version"
        
        self.get(url,
            success: {(result: JSON!)-> Void in
                self.endpointVersion = result["endpointVersion"].stringValue
                self.apiVersion = result["apiVersion"].stringValue

                success(result)
            },
            failure: failure
        )
    }

}
